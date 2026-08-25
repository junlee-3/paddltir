// CrewRepository.swift
// Async, GRDB-backed, offline-first repository over `crews` (+
// `crew_members`, joined through to `paddlers`/`erg_tests`) — what the Crew
// feature screens (crew list, roster editor) consume. See
// SquadRepository.swift's header for the read/write split this repository
// (and its siblings) all follow.

import Foundation
import GRDB
import PaddltirCore

struct CrewRepository: Sendable {
    let db: AppDatabase

    init(db: AppDatabase) {
        self.db = db
    }

    /// Shared fetch behind `crews()`, `fetchSummaries`, and
    /// `ScheduleRepository.observeRaceDay`.
    static func fetchCrews(_ db: Database) throws -> [Crew] {
        try Crew.order(Column("name")).fetchAll(db)
    }

    /// Every crew, alphabetical by name.
    func crews() async throws -> [Crew] {
        try db.read(Self.fetchCrews)
    }

    /// Shared fetch behind `crew(id:)` and `fetchCrewDetail`: a crew and its
    /// members, each joined to their latest erg test, or `nil` if `id`
    /// doesn't exist.
    static func fetchCrewWithMembers(_ db: Database, id: String) throws -> (crew: Crew, members: [PaddlerWithErg])? {
        guard let crew = try Crew.fetchOne(db, key: id) else { return nil }
        let memberIds = try CrewMember
            .filter(Column("crew_id") == id)
            .fetchAll(db)
            .map(\.paddlerId)
        let rows = try PaddlerRow
            .filter(memberIds.contains(Column("id")))
            .order(Column("name"))
            .fetchAll(db)
        let ergs = try ErgTest
            .filter(memberIds.contains(Column("paddler_id")))
            .fetchAll(db)
        return (crew, PaddlerWithErg.join(rows: rows, ergs: ergs))
    }

    /// A crew and its members, each joined to their latest erg test, or
    /// `nil` if `id` doesn't exist.
    func crew(id: String) async throws -> (crew: Crew, members: [PaddlerWithErg])? {
        try db.read { db in try Self.fetchCrewWithMembers(db, id: id) }
    }

    /// Replaces `crewId`'s membership with exactly `paddlerIds`, in one
    /// transaction: rows are diffed against the current membership so only
    /// the actual adds/removes touch GRDB and the outbox — a paddler already
    /// on the crew who stays on it generates no churn.
    func setMembers(crewId: String, paddlerIds: [String]) async throws {
        try db.write { db in
            let existing = try CrewMember
                .filter(Column("crew_id") == crewId)
                .fetchAll(db)
            let existingIds = Set(existing.map(\.paddlerId))
            let keptOrNewIds = Set(paddlerIds)

            for member in existing where !keptOrNewIds.contains(member.paddlerId) {
                try member.delete(db)
                try Outbox.enqueue(
                    db: db,
                    table: CrewMember.databaseTableName,
                    pk: member.syncPrimaryKey,
                    op: "delete",
                    payload: try PostgREST.encoder.encode(member)
                )
            }

            let now = Date()
            for paddlerId in paddlerIds where !existingIds.contains(paddlerId) {
                let member = CrewMember(crewId: crewId, paddlerId: paddlerId, createdAt: now)
                try member.insert(db)
                try Outbox.enqueue(
                    db: db,
                    table: CrewMember.databaseTableName,
                    pk: member.syncPrimaryKey,
                    op: "insert",
                    payload: try PostgREST.encoder.encode(member)
                )
            }
        }
    }

    struct CrewSummary: Identifiable, Hashable, Sendable {
        let crew: Crew
        let memberCount: Int
        let nextRaceName: String?
        var id: String { crew.id }
    }

    /// Creates a crew for `clubId`.
    func createCrew(clubId: String, name: String, ageDivision: String, category: CrewCategory) async throws -> Crew {
        let row = Crew(id: UUID().uuidString, clubId: clubId, name: name, ageDivision: ageDivision,
                       category: category, createdAt: Date(), updatedAt: nil)
        try db.write { db in
            try row.insert(db)
            try Outbox.enqueue(db: db, table: Crew.databaseTableName, pk: row.syncPrimaryKey,
                               op: "insert", payload: try PostgREST.encoder.encode(row))
        }
        return row
    }

    /// Shared fetch behind `racesForCrew(crewId:)` and `fetchCrewDetail`.
    static func fetchRacesForCrew(_ db: Database, crewId: String) throws -> [Race] {
        try Race.filter(Column("crew_id") == crewId).order(Column("sort_order")).fetchAll(db)
    }

    /// A crew's races, in configured order.
    func racesForCrew(crewId: String) async throws -> [Race] {
        try db.read { db in try Self.fetchRacesForCrew(db, crewId: crewId) }
    }

    /// Shared fetch behind `summaries(now:)` and `observeSummaries(now:)`:
    /// every crew (alphabetical) with its member count and the name of its
    /// race in the soonest future session (or nil).
    static func fetchSummaries(_ db: Database, now: Date) throws -> [CrewSummary] {
        let crews = try Self.fetchCrews(db)
        return try crews.map { crew in
            let count = try CrewMember.filter(Column("crew_id") == crew.id).fetchCount(db)
            let races = try Race.filter(Column("crew_id") == crew.id).fetchAll(db)
            // soonest future session among this crew's races
            var best: (Date, String)?
            for race in races {
                guard let s = try SessionRow.fetchOne(db, key: race.sessionId), s.startsAt >= now else { continue }
                if best == nil || s.startsAt < best!.0 { best = (s.startsAt, race.name) }
            }
            return CrewSummary(crew: crew, memberCount: count, nextRaceName: best?.1)
        }
    }

    /// Every crew (alphabetical) with its member count and the name of its
    /// race in the soonest future session (or nil).
    func summaries(now: Date) async throws -> [CrewSummary] {
        try db.read { db in try Self.fetchSummaries(db, now: now) }
    }

    /// Emits the current crew summaries, then again whenever crews/members/
    /// races/sessions change.
    func observeSummaries(now: Date) -> ValueObservation<ValueReducers.Fetch<[CrewSummary]>> {
        ValueObservation.tracking { db in try Self.fetchSummaries(db, now: now) }
    }

    struct CrewDetail: Equatable, Sendable {
        var crew: Crew?
        var members: [PaddlerWithErg]
        var races: [Race]
        var squad: [PaddlerWithErg]
        var rule: GenderRule?
    }

    /// Shared fetch behind `observeCrewDetail(id:)`: the crew + members (via
    /// `fetchCrewWithMembers`), its races, the full squad (candidates for
    /// adding), and its IDBF gender rule (standard boat), or an all-empty
    /// `CrewDetail` if `id` doesn't exist.
    static func fetchCrewDetail(_ db: Database, id: String) throws -> CrewDetail {
        guard let (crew, members) = try Self.fetchCrewWithMembers(db, id: id) else {
            return CrewDetail(crew: nil, members: [], races: [], squad: [], rule: nil)
        }
        let races = try Self.fetchRacesForCrew(db, crewId: id)
        let squad = try SquadRepository.fetchPaddlers(db)
        let key: [String: (any DatabaseValueConvertible)?] = [
            "club_id": crew.clubId,
            "category": crew.category.rawValue,
            "boat_size": BoatSize.standard.rawValue,
        ]
        let rule = DomainMapping.genderRule(try CategoryRule.fetchOne(db, key: key))
        return CrewDetail(crew: crew, members: members, races: races, squad: squad, rule: rule)
    }

    /// Emits the current crew detail, then again on any change to the crew,
    /// its members, races, the squad, or its category rule.
    func observeCrewDetail(id: String) -> ValueObservation<ValueReducers.Fetch<CrewDetail>> {
        ValueObservation.tracking { db in try Self.fetchCrewDetail(db, id: id) }
    }
}

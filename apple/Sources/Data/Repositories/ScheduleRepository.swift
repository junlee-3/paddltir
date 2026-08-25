// ScheduleRepository.swift
// Async, GRDB-backed, offline-first repository over `sessions`
// (+ `availability`, `races`) — what the Schedule feature screens (session
// list, session detail) consume. Includes read and write operations; see
// SquadRepository.swift's header for the read/write split the other three
// repositories follow.

import Foundation
import GRDB

struct ScheduleRepository: Sendable {
    let db: AppDatabase

    init(db: AppDatabase) {
        self.db = db
    }

    /// Shared fetch behind `sessions()` and `fetchSchedule`.
    static func fetchSessions(_ db: Database) throws -> [SessionRow] {
        try SessionRow.order(Column("starts_at")).fetchAll(db)
    }

    /// Every session, soonest first. Not filtered to the future — the
    /// schedule screen owns any "upcoming vs. past" split; this always
    /// returns the full local set in chronological order.
    func sessions() async throws -> [SessionRow] {
        try db.read(Self.fetchSessions)
    }

    /// Shared fetch behind `session(id:)`, `observeTrainingDetail`, and
    /// `observeRaceDay`: everyone's availability for a session.
    static func fetchAvailability(_ db: Database, sessionId: String) throws -> [Availability] {
        try Availability.filter(Column("session_id") == sessionId).fetchAll(db)
    }

    /// A session and everyone's availability for it, or `nil` if `id`
    /// doesn't exist.
    func session(id: String) async throws -> (session: SessionRow, availability: [Availability])? {
        try db.read { db in
            guard let session = try SessionRow.fetchOne(db, key: id) else { return nil }
            return (session, try Self.fetchAvailability(db, sessionId: id))
        }
    }

    /// Shared fetch behind `races(sessionId:)` and `observeRaceDay`.
    static func fetchRaces(_ db: Database, sessionId: String) throws -> [Race] {
        try Race
            .filter(Column("session_id") == sessionId)
            .order(Column("sort_order"))
            .fetchAll(db)
    }

    /// A session's races, in their configured display order.
    func races(sessionId: String) async throws -> [Race] {
        try db.read { db in try Self.fetchRaces(db, sessionId: sessionId) }
    }

    /// Shared fetch behind `fetchSchedule` and `observeRaceDay`: the
    /// non-archived squad size.
    static func fetchSquadSize(_ db: Database) throws -> Int {
        try PaddlerRow.filter(Column("archived_at") == nil).fetchCount(db)
    }

    struct ScheduleSnapshot: Equatable, Sendable {
        var sessions: [SessionRow]
        var squadSize: Int
        var availabilityBySession: [String: [Availability]]
    }

    /// Shared fetch behind `scheduleSnapshot()` and `observeSchedule()`.
    static func fetchSchedule(_ db: Database) throws -> ScheduleSnapshot {
        let sessions = try Self.fetchSessions(db)
        let squadSize = try Self.fetchSquadSize(db)
        let availability = Dictionary(grouping: try Availability.fetchAll(db), by: \.sessionId)
        return ScheduleSnapshot(sessions: sessions, squadSize: squadSize, availabilityBySession: availability)
    }

    /// One-shot read of the full schedule snapshot.
    func scheduleSnapshot() async throws -> ScheduleSnapshot {
        try db.read(Self.fetchSchedule)
    }

    /// Emits the current schedule snapshot, then again whenever sessions,
    /// the squad, or availability change.
    func observeSchedule() -> ValueObservation<ValueReducers.Fetch<ScheduleSnapshot>> {
        ValueObservation.tracking(Self.fetchSchedule)
    }

    struct TrainingDetail: Equatable, Sendable {
        var paddlers: [PaddlerWithErg]
        var availability: [Availability]
    }

    /// Emits the squad + this session's availability, then again on any
    /// change.
    func observeTrainingDetail(sessionId: String) -> ValueObservation<ValueReducers.Fetch<TrainingDetail>> {
        ValueObservation.tracking { db in
            TrainingDetail(
                paddlers: try SquadRepository.fetchPaddlers(db),
                availability: try Self.fetchAvailability(db, sessionId: sessionId)
            )
        }
    }

    struct RaceDaySnapshot: Equatable, Sendable {
        var races: [Race]
        var crews: [Crew]
        var availability: [Availability]
        var squadSize: Int
    }

    /// Emits this session's races/availability, every crew, and the squad
    /// size, then again on any change.
    func observeRaceDay(sessionId: String) -> ValueObservation<ValueReducers.Fetch<RaceDaySnapshot>> {
        ValueObservation.tracking { db in
            RaceDaySnapshot(
                races: try Self.fetchRaces(db, sessionId: sessionId),
                crews: try CrewRepository.fetchCrews(db),
                availability: try Self.fetchAvailability(db, sessionId: sessionId),
                squadSize: try Self.fetchSquadSize(db)
            )
        }
    }

    // MARK: - Writes (each mutation + its outbox entry in one transaction)

    /// Creates a training or race-day session for `clubId`.
    func createSession(clubId: String, kind: SessionKind, title: String,
                       startsAt: Date, venue: String?, notes: String?) async throws -> SessionRow {
        let row = SessionRow(id: UUID().uuidString, clubId: clubId, kind: kind, title: title,
                             startsAt: startsAt, venue: venue, notes: notes,
                             createdAt: Date(), updatedAt: nil)
        try db.write { db in
            try row.insert(db)
            try Outbox.enqueue(db: db, table: SessionRow.databaseTableName, pk: row.syncPrimaryKey,
                               op: "insert", payload: try PostgREST.encoder.encode(row))
        }
        return row
    }

    /// Coach override (or first capture) of a paddler's availability for a
    /// session — upserts on (session_id, paddler_id).
    func setAvailability(sessionId: String, paddlerId: String,
                         status: AvailabilityStatus, note: String?) async throws {
        let row = Availability(sessionId: sessionId, paddlerId: paddlerId,
                               status: status, note: note, updatedAt: Date())
        try db.write { db in
            try row.upsert(db)
            try Outbox.enqueue(db: db, table: Availability.databaseTableName, pk: row.syncPrimaryKey,
                               op: "update", payload: try PostgREST.encoder.encode(row))
        }
    }

    /// Adds a race to a race-day session; `sort_order` is the next free slot.
    /// Also creates the race's first heat ("Heat 1", `sort_order == 1`) in the
    /// same transaction — a race is never without a heat, so the lineup editor's
    /// live observation never has to (and no longer does) create one itself; see
    /// `LineupRepository.insertHeat` for the shared write+outbox shape.
    func createRace(sessionId: String, crewId: String, name: String,
                    boatSize: BoatSize, distanceM: Int?) async throws -> Race {
        try db.write { db in
            let order = try Race.filter(Column("session_id") == sessionId).fetchCount(db)
            let row = Race(id: UUID().uuidString, sessionId: sessionId, crewId: crewId, name: name,
                           boatSize: boatSize, distanceM: distanceM, sortOrder: order,
                           createdAt: Date(), updatedAt: nil)
            try row.insert(db)
            try Outbox.enqueue(db: db, table: Race.databaseTableName, pk: row.syncPrimaryKey,
                               op: "insert", payload: try PostgREST.encoder.encode(row))
            _ = try LineupRepository.insertHeat(db, raceId: row.id, name: "Heat 1", sortOrder: 1)
            return row
        }
    }
}

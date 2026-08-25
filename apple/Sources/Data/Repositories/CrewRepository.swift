// CrewRepository.swift
// Async, GRDB-backed, offline-first repository over `crews` (+
// `crew_members`, joined through to `paddlers`/`erg_tests`) — what the Crew
// feature screens (crew list, roster editor) consume. See
// SquadRepository.swift's header for the read/write split this repository
// (and its siblings) all follow.

import Foundation
import GRDB

struct CrewRepository: Sendable {
    let db: AppDatabase

    init(db: AppDatabase) {
        self.db = db
    }

    /// Every crew, alphabetical by name.
    func crews() async throws -> [Crew] {
        try db.read { db in
            try Crew.order(Column("name")).fetchAll(db)
        }
    }

    /// A crew and its members, each joined to their latest erg test, or
    /// `nil` if `id` doesn't exist.
    func crew(id: String) async throws -> (crew: Crew, members: [PaddlerWithErg])? {
        try db.read { db in
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
}

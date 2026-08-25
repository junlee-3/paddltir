// ScheduleRepository.swift
// Async, GRDB-backed, offline-first, read-only repository over `sessions`
// (+ `availability`, `races`) — what the Schedule feature screens (session
// list, session detail) consume. No writes yet: availability capture and
// session editing land with the screens that need them in a later plan; see
// SquadRepository.swift's header for the read/write split the other three
// repositories follow.

import Foundation
import GRDB

struct ScheduleRepository: Sendable {
    let db: AppDatabase

    init(db: AppDatabase) {
        self.db = db
    }

    /// Every session, soonest first. Not filtered to the future — the
    /// schedule screen owns any "upcoming vs. past" split; this always
    /// returns the full local set in chronological order.
    func upcomingSessions() async throws -> [SessionRow] {
        try db.read { db in
            try SessionRow.order(Column("starts_at")).fetchAll(db)
        }
    }

    /// A session and everyone's availability for it, or `nil` if `id`
    /// doesn't exist.
    func session(id: String) async throws -> (session: SessionRow, availability: [Availability])? {
        try db.read { db in
            guard let session = try SessionRow.fetchOne(db, key: id) else { return nil }
            let availability = try Availability
                .filter(Column("session_id") == id)
                .fetchAll(db)
            return (session, availability)
        }
    }

    /// A session's races, in their configured display order.
    func races(sessionId: String) async throws -> [Race] {
        try db.read { db in
            try Race
                .filter(Column("session_id") == sessionId)
                .order(Column("sort_order"))
                .fetchAll(db)
        }
    }
}

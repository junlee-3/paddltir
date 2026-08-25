// apple/Tests/PaddltirAppTests/ScheduleRepositoryWriteTests.swift
import Foundation
import GRDB
import Testing
@testable import Paddltir

@Suite struct ScheduleRepositoryWriteTests {
    private let t0 = Date(timeIntervalSince1970: 1_700_000_000)

    private func makeClubRow(_ db: Database, id: String) throws {
        try Club(id: id, name: "C", inviteCode: "ABCD2345", createdBy: nil, createdAt: Date(), updatedAt: nil).insert(db)
    }

    @Test func createSessionWritesRowAndOutbox() async throws {
        let appDB = try AppDatabase.inMemory()
        let repo = ScheduleRepository(db: appDB)
        let session = try await repo.createSession(
            clubId: "club-1", kind: .training, title: "Tuesday paddle",
            startsAt: t0, venue: "Iron Cove", notes: nil)

        #expect(session.title == "Tuesday paddle")
        #expect(session.kind == .training)
        let stored = try appDB.read { db in try SessionRow.fetchOne(db, key: session.id) }
        #expect(stored?.title == "Tuesday paddle")
        // one insert queued for the sessions table
        let entries = try appDB.read { db in try OutboxEntry.filter(Column("table_name") == "sessions").fetchAll(db) }
        #expect(entries.count == 1)
        #expect(entries.first?.op == "insert")
        #expect(entries.first?.pk == session.id)
    }

    @Test func setAvailabilityUpsertsAndEnqueues() async throws {
        let appDB = try AppDatabase.inMemory()
        let repo = ScheduleRepository(db: appDB)
        try await repo.setAvailability(sessionId: "s-1", paddlerId: "p-1", status: .in, note: "driving")
        try await repo.setAvailability(sessionId: "s-1", paddlerId: "p-1", status: .out, note: nil) // override

        let rows = try appDB.read { db in try Availability.filter(Column("session_id") == "s-1").fetchAll(db) }
        #expect(rows.count == 1)                 // upsert, not duplicate
        #expect(rows.first?.status == .out)
        let entries = try appDB.read { db in try OutboxEntry.filter(Column("table_name") == "availability").fetchAll(db) }
        #expect(entries.count == 2)              // both writes queued
        #expect(entries.allSatisfy { $0.pk == "s-1|p-1" })
    }

    @Test func createRaceWritesRowAndOutbox() async throws {
        let appDB = try AppDatabase.inMemory()
        let repo = ScheduleRepository(db: appDB)
        let race = try await repo.createRace(sessionId: "s-1", crewId: "c-1", name: "Heat A", boatSize: .standard, distanceM: 500)
        #expect(race.name == "Heat A")
        #expect(race.sortOrder == 0)             // first race → order 0
        let race2 = try await repo.createRace(sessionId: "s-1", crewId: "c-1", name: "Heat B", boatSize: .standard, distanceM: 200)
        #expect(race2.sortOrder == 1)            // next → order 1
        let entries = try appDB.read { db in try OutboxEntry.filter(Column("table_name") == "races").fetchAll(db) }
        #expect(entries.count == 2)
    }
}

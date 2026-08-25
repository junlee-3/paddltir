// apple/Tests/PaddltirAppTests/HeatCreationTests.swift
// F1: a race is born with its first heat, written in the same transaction as
// the race — so the lineup editor's live observation of an empty heat list
// never has to (and no longer does) auto-create one itself.
import Foundation
import GRDB
import Testing
@testable import Paddltir

@MainActor @Suite struct HeatCreationTests {
    private let t0 = Date(timeIntervalSince1970: 1_700_000_000)

    @Test func createRaceCreatesItsFirstHeat() async throws {
        let appDB = try AppDatabase.inMemory()
        let repo = ScheduleRepository(db: appDB)

        let race = try await repo.createRace(sessionId: "s-1", crewId: "c-1", name: "Race 1", boatSize: .standard, distanceM: nil)

        let heats = try appDB.read { db in try LineupRepository.fetchHeats(db, raceId: race.id) }
        #expect(heats.count == 1)
        #expect(heats.first?.name == "Heat 1")
        #expect(heats.first?.sortOrder == 1)

        let entries = try appDB.read { db in try OutboxEntry.filter(Column("table_name") == "heats").fetchAll(db) }
        #expect(entries.count == 1)
        #expect(entries.first?.op == "insert")
        #expect(entries.first?.pk == heats.first?.id)
    }

    /// A race with zero heats (its only heat since deleted, or seeded directly for
    /// the test) is a legitimate state: `observeHeats` loads and stops there — it
    /// never writes a heat back, even across a second, unrelated re-emission.
    @Test func observeHeatsWithNoHeatsCreatesNoneAndLoads() async throws {
        let appDB = try AppDatabase.inMemory()
        try appDB.write { db in
            try Crew(id: "c-1", clubId: "club-1", name: "Crew", ageDivision: "Premier", category: .mixed, createdAt: t0, updatedAt: nil).insert(db)
            try Race(id: "r-1", sessionId: "s-1", crewId: "c-1", name: "Race 1", boatSize: .standard, distanceM: nil, sortOrder: 0, createdAt: t0, updatedAt: nil).insert(db)
        }
        let model = LineupViewModel(db: appDB)
        let task = Task { await model.observeHeats(raceId: "r-1") }
        defer { task.cancel() }

        for _ in 0..<50 where !model.isLoaded { try await Task.sleep(for: .milliseconds(40)) }
        #expect(model.isLoaded)
        #expect(model.heats.isEmpty)

        // Force a second emission on the `heats` table (a different race's row,
        // inserted then deleted) — still no heat gets created for "r-1".
        try appDB.write { db in
            try Heat(id: "other", raceId: "other-race", name: "Other", sortOrder: 0, drummerId: nil, sweepId: nil, createdAt: t0, updatedAt: nil).insert(db)
        }
        try appDB.write { db in
            _ = try Heat.deleteOne(db, key: "other")
        }
        try await Task.sleep(for: .milliseconds(150))   // give the observation a beat to (not) react

        #expect(model.heats.isEmpty)
        let heats = try appDB.read { db in try LineupRepository.fetchHeats(db, raceId: "r-1") }
        #expect(heats.isEmpty)   // never auto-created, in the VM or the DB
    }
}

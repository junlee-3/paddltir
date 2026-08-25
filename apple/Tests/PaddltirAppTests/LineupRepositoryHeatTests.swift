import Foundation
import GRDB
import Testing
@testable import Paddltir

@Suite struct LineupRepositoryHeatTests {
    private let t0 = Date(timeIntervalSince1970: 1_700_000_000)

    @Test func createHeatWritesRowAndOutbox() async throws {
        let appDB = try AppDatabase.inMemory()
        let repo = LineupRepository(db: appDB)
        let h1 = try await repo.createHeat(raceId: "r-1", name: "Heat 1")
        let h2 = try await repo.createHeat(raceId: "r-1", name: "Heat 2")
        #expect(h1.sortOrder == 1)   // max+1 of none → 1, matching the race-birth heat's convention
        #expect(h2.sortOrder == 2)
        let stored = try appDB.read { db in try Heat.fetchOne(db, key: h1.id) }
        #expect(stored?.name == "Heat 1")
        let entries = try appDB.read { db in try OutboxEntry.filter(Column("table_name") == "heats").fetchAll(db) }
        #expect(entries.count == 2)
        #expect(entries.allSatisfy { $0.op == "insert" })
    }

    @Test func saveHeatUpdatesDrummerSweepAndEnqueues() async throws {
        let appDB = try AppDatabase.inMemory()
        try appDB.write { db in
            try Heat(id: "h-1", raceId: "r-1", name: "Heat 1", sortOrder: 0, drummerId: nil, sweepId: nil, createdAt: t0, updatedAt: nil).insert(db)
        }
        let repo = LineupRepository(db: appDB)
        try await repo.saveHeat(heatId: "h-1", name: "Final", drummerId: "p-drum", sweepId: "p-sweep")
        let stored = try appDB.read { db in try Heat.fetchOne(db, key: "h-1") }
        #expect(stored?.name == "Final")
        #expect(stored?.drummerId == "p-drum")
        #expect(stored?.sweepId == "p-sweep")
        let entries = try appDB.read { db in try OutboxEntry.filter(Column("table_name") == "heats").fetchAll(db) }
        #expect(entries.count == 1)
        #expect(entries.first?.op == "update")
        #expect(entries.first?.pk == "h-1")
    }
}

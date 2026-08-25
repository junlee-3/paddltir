// apple/Tests/PaddltirAppTests/HeatSwitchingTests.swift
// F5: `selectedHeatIndex` is a small state machine that survives an `addHeat`,
// a reorder, and the selected heat's own deletion — exercised end-to-end
// against a live `observeHeats` observation and a bounded poll, the same
// shape as ReactiveViewModelTests.
import Foundation
import GRDB
import Testing
@testable import Paddltir

@MainActor @Suite struct HeatSwitchingTests {
    private let t0 = Date(timeIntervalSince1970: 1_700_000_000)

    private func seed(_ appDB: AppDatabase, heats: [(id: String, name: String, sortOrder: Int)]) throws {
        try appDB.write { db in
            try Crew(id: "c-1", clubId: "club-1", name: "Crew", ageDivision: "Premier", category: .mixed, createdAt: t0, updatedAt: nil).insert(db)
            try Race(id: "r-1", sessionId: "s-1", crewId: "c-1", name: "Race 1", boatSize: .standard, distanceM: nil, sortOrder: 0, createdAt: t0, updatedAt: nil).insert(db)
            for h in heats {
                try Heat(id: h.id, raceId: "r-1", name: h.name, sortOrder: h.sortOrder, drummerId: nil, sweepId: nil, createdAt: t0, updatedAt: nil).insert(db)
            }
        }
    }

    @Test func addHeatSelectsTheNewHeat() async throws {
        let appDB = try AppDatabase.inMemory()
        try seed(appDB, heats: [(id: "h1", name: "Heat 1", sortOrder: 1)])
        let model = LineupViewModel(db: appDB)
        let task = Task { await model.observeHeats(raceId: "r-1") }
        defer { task.cancel() }
        for _ in 0..<50 where model.heats.isEmpty { try await Task.sleep(for: .milliseconds(40)) }

        await model.addHeat(raceId: "r-1")

        for _ in 0..<50 where model.heats.count < 2 { try await Task.sleep(for: .milliseconds(40)) }
        #expect(model.heats.count == 2)
        for _ in 0..<50 where model.selectedHeatIndex != 1 { try await Task.sleep(for: .milliseconds(40)) }
        #expect(model.selectedHeatIndex == 1)
        for _ in 0..<50 where model.heat?.id != model.heats[safe: 1]?.id { try await Task.sleep(for: .milliseconds(40)) }
        #expect(model.heat?.id == model.heats[1].id)
        #expect(model.heats[1].name == "Heat 2")
    }

    @Test func reorderKeepsTheEditedHeatSelected() async throws {
        let appDB = try AppDatabase.inMemory()
        try seed(appDB, heats: [(id: "h1", name: "Heat 1", sortOrder: 1), (id: "h2", name: "Heat 2", sortOrder: 2)])
        let model = LineupViewModel(db: appDB)
        let task = Task { await model.observeHeats(raceId: "r-1") }
        defer { task.cancel() }
        for _ in 0..<50 where model.heats.count < 2 { try await Task.sleep(for: .milliseconds(40)) }

        model.selectedHeatIndex = 1
        for _ in 0..<50 where model.heat?.id != "h2" { try await Task.sleep(for: .milliseconds(40)) }
        #expect(model.heat?.id == "h2")

        // h2 becomes first in display order.
        try appDB.write { db in
            guard var h2 = try Heat.fetchOne(db, key: "h2") else { return }
            h2.sortOrder = 0
            try h2.update(db)
        }

        for _ in 0..<50 where model.selectedHeatIndex != 0 { try await Task.sleep(for: .milliseconds(40)) }
        #expect(model.selectedHeatIndex == 0)
        #expect(model.heat?.id == "h2")   // reconciled by id, not reloaded
    }

    @Test func deletedSelectedHeatFallsBackToFirst() async throws {
        let appDB = try AppDatabase.inMemory()
        try seed(appDB, heats: [(id: "h1", name: "Heat 1", sortOrder: 1), (id: "h2", name: "Heat 2", sortOrder: 2)])
        let model = LineupViewModel(db: appDB)
        let task = Task { await model.observeHeats(raceId: "r-1") }
        defer { task.cancel() }
        for _ in 0..<50 where model.heats.count < 2 { try await Task.sleep(for: .milliseconds(40)) }

        model.selectedHeatIndex = 1
        for _ in 0..<50 where model.heat?.id != "h2" { try await Task.sleep(for: .milliseconds(40)) }

        try appDB.write { db in _ = try Heat.deleteOne(db, key: "h2") }

        for _ in 0..<50 where model.heats.count != 1 { try await Task.sleep(for: .milliseconds(40)) }
        #expect(model.selectedHeatIndex == 0)
        for _ in 0..<50 where model.heat?.id != "h1" { try await Task.sleep(for: .milliseconds(40)) }
        #expect(model.heat?.id == "h1")
    }
}

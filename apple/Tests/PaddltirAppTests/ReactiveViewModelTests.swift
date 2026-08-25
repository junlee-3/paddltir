// apple/Tests/PaddltirAppTests/ReactiveViewModelTests.swift
import Foundation
import GRDB
import Testing
@testable import Paddltir

@MainActor @Suite struct ReactiveViewModelTests {
    private let now = Date(timeIntervalSince1970: 1_700_000_000)

    @Test func squadViewModelObservesInserts() async throws {
        let db = try AppDatabase.inMemory()
        let vm = SquadViewModel(db: db)
        let task = Task { await vm.observe() }
        defer { task.cancel() }
        for _ in 0..<50 where !vm.isLoaded { try await Task.sleep(for: .milliseconds(40)) }
        #expect(vm.isLoaded && vm.all.isEmpty)
        try db.write { d in
            try PaddlerRow(id: "p1", clubId: "c", profileId: nil, name: "Ava", email: nil, weightKg: 60, preferredSide: .left,
                           gender: .female, seatPreference: .none, boatRole: .paddler, archivedAt: nil, createdAt: now, updatedAt: nil).insert(d)
        }
        for _ in 0..<50 where vm.all.isEmpty { try await Task.sleep(for: .milliseconds(40)) }
        #expect(vm.all.map(\.row.name) == ["Ava"])       // no load() call — the observation delivered it
    }

    @Test func scheduleCreateFlowsBackThroughObservation() async throws {
        let db = try AppDatabase.inMemory()
        let vm = ScheduleViewModel(db: db, now: { self.now })
        let task = Task { await vm.observe() }
        defer { task.cancel() }
        for _ in 0..<50 where !vm.isLoaded { try await Task.sleep(for: .milliseconds(40)) }
        await vm.createTraining(clubId: "c1", title: "New paddle", startsAt: now.addingTimeInterval(3600), venue: nil, notes: nil)
        for _ in 0..<50 where vm.upNext == nil { try await Task.sleep(for: .milliseconds(40)) }
        #expect(vm.upNext?.title == "New paddle")
    }

    /// F2: a failed first emission must still stop the spinner — `isLoaded` and
    /// `lastError` both flip, so the view leaves `ProgressView()` for its loaded
    /// (empty-with-banner) branch instead of spinning forever. Forced here by
    /// closing the underlying `DatabaseQueue` before `observe()` ever runs, so its
    /// very first read throws.
    @Test func squadViewModelSurfacesAFailedFirstEmission() async throws {
        let db = try AppDatabase.inMemory()
        try db.dbQueue.close()
        let vm = SquadViewModel(db: db)
        let task = Task { await vm.observe() }
        defer { task.cancel() }
        for _ in 0..<50 where !(vm.isLoaded && vm.lastError != nil) { try await Task.sleep(for: .milliseconds(40)) }
        #expect(vm.isLoaded)
        #expect(vm.lastError != nil)
    }
}

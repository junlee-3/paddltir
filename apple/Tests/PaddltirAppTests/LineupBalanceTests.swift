import Foundation
import GRDB
import PaddltirCore
import Testing
@testable import Paddltir

@MainActor @Suite struct LineupBalanceTests {
    private func vm() -> LineupViewModel {
        let db = try! AppDatabase.inMemory()
        let m = LineupViewModel(db: db)
        let paddlers = (1...10).map { i in
            Paddler(id: PaddlerID("p\(i)"), name: "P\(i)", weightKg: Double(60 + i), ergM: Double(600 + i),
                    side: .either, gender: i % 2 == 0 ? .male : .female, seatPref: .none, role: .paddler)
        }
        let roster = Roster(paddlers)
        let req = PlacementRequest(boat: .small, roster: roster, candidates: paddlers.map(\.id), current: Lineup(boat: .small))
        m._injectForTest(request: req, heat: Heat(id: "h", raceId: "r", name: "Heat 1", sortOrder: 0, drummerId: nil, sweepId: nil, createdAt: Date(), updatedAt: nil))
        return m
    }

    @Test func metricsReflectSeatedCount() {
        let m = vm()
        #expect(m.metrics?.seated == 0)
        m.tapReserve(PaddlerID("p1")); m.tapSeat(Seat(bench: 1, side: .left))
        #expect(m.metrics?.seated == 1)
    }

    @Test func autoFillSeatsTheBoat() {
        let m = vm()
        m.autoFill()
        // small boat = 10 seats, 10 candidates → full
        #expect(m.metrics?.seated == 10)
        #expect(m.canUndo)   // auto-fill is undoable
    }
}

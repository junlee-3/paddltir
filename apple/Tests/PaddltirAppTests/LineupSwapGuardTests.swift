// apple/Tests/PaddltirAppTests/LineupSwapGuardTests.swift
import Foundation
import PaddltirCore
import Testing
@testable import Paddltir

@MainActor @Suite struct LineupSwapGuardTests {
    private func vm() -> LineupViewModel {
        let db = try! AppDatabase.inMemory()
        let m = LineupViewModel(db: db)
        let paddlers = (1...4).map { i in
            Paddler(id: PaddlerID("p\(i)"), name: "P\(i)", weightKg: 70, ergM: 600,
                    side: .either, gender: .female, seatPref: .none, role: .paddler)
        }
        m._injectForTest(request: PlacementRequest(boat: .small, roster: Roster(paddlers),
                                                   candidates: paddlers.map(\.id), current: Lineup(boat: .small)),
                         heat: Heat(id: "h", raceId: "r", name: "H", sortOrder: 0, drummerId: nil, sweepId: nil, createdAt: Date(), updatedAt: nil))
        return m
    }
    @Test func swappingTwoEmptySeatsIsANoOpAndDoesNotEnableUndo() {
        let m = vm()
        m.tapSeat(Seat(bench: 1, side: .left))    // select empty seat
        m.tapSeat(Seat(bench: 2, side: .left))    // "swap" with another empty seat
        #expect(m.canUndo == false)               // nothing changed → no undo snapshot
    }
}

import Foundation
import GRDB
import PaddltirCore
import Testing
@testable import Paddltir

@MainActor @Suite struct LineupViewModelTests {
    // Builds an in-memory VM around a hand-made lineup context (no GRDB needed for the
    // pure tap/undo/reserve logic — we inject the request directly via a test hook).
    private func vm(seatsFilled: Bool = false) -> LineupViewModel {
        let db = try! AppDatabase.inMemory()
        let m = LineupViewModel(db: db)
        // roster of 4 paddlers p1..p4, small boat (5 benches → 10 seats)
        let paddlers = (1...4).map { i in
            Paddler(id: PaddlerID("p\(i)"), name: "P\(i)", weightKg: 70, ergM: Double(600 + i),
                    side: .either, gender: i % 2 == 0 ? .male : .female, seatPref: .none, role: .paddler)
        }
        let roster = Roster(paddlers)
        let req = PlacementRequest(boat: .small, roster: roster, candidates: paddlers.map(\.id),
                                   current: Lineup(boat: .small))
        m._injectForTest(request: req, heat: Heat(id: "h", raceId: "r", name: "Heat 1", sortOrder: 0, drummerId: nil, sweepId: nil, createdAt: Date(), updatedAt: nil))
        return m
    }

    @Test func tapReserveThenSeatPlaces() {
        let m = vm()
        m.tapReserve(PaddlerID("p1"))
        #expect(m.selection == .reserve(PaddlerID("p1")))
        m.tapSeat(Seat(bench: 1, side: .left))
        #expect(m.lineup?.paddler(at: Seat(bench: 1, side: .left)) == PaddlerID("p1"))
        #expect(m.selection == nil)
        #expect(m.reserves.contains(PaddlerID("p1")) == false)   // now seated
    }

    @Test func tapTwoSeatsSwaps() {
        let m = vm()
        m.tapReserve(PaddlerID("p1")); m.tapSeat(Seat(bench: 1, side: .left))
        m.tapReserve(PaddlerID("p2")); m.tapSeat(Seat(bench: 1, side: .right))
        m.tapSeat(Seat(bench: 1, side: .left)); m.tapSeat(Seat(bench: 1, side: .right)) // swap
        #expect(m.lineup?.paddler(at: Seat(bench: 1, side: .left)) == PaddlerID("p2"))
        #expect(m.lineup?.paddler(at: Seat(bench: 1, side: .right)) == PaddlerID("p1"))
    }

    @Test func unseatAndUndo() {
        let m = vm()
        m.tapReserve(PaddlerID("p1")); m.tapSeat(Seat(bench: 1, side: .left))
        #expect(m.canUndo)
        m.unseat(Seat(bench: 1, side: .left))
        #expect(m.lineup?.paddler(at: Seat(bench: 1, side: .left)) == nil)
        m.undo() // undo the unseat
        #expect(m.lineup?.paddler(at: Seat(bench: 1, side: .left)) == PaddlerID("p1"))
    }

    @Test func reservesSortedByErgDescending() {
        let m = vm()
        #expect(m.reserves == [PaddlerID("p4"), PaddlerID("p3"), PaddlerID("p2"), PaddlerID("p1")]) // erg 604>603>602>601
    }
}

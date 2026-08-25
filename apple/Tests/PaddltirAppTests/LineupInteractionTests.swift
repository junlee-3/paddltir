import Foundation
import PaddltirCore
import Testing
@testable import Paddltir

@MainActor @Suite struct LineupInteractionTests {
    private func vm() -> LineupViewModel {
        let db = try! AppDatabase.inMemory()
        let m = LineupViewModel(db: db)
        let paddlers = (1...4).map { i in
            Paddler(id: PaddlerID("p\(i)"), name: "P\(i)", weightKg: 70, ergM: 600, side: .either,
                    gender: i % 2 == 0 ? .male : .female, seatPref: .none, role: .paddler)
        }
        m._injectForTest(request: PlacementRequest(boat: .small, roster: Roster(paddlers), candidates: paddlers.map(\.id), current: Lineup(boat: .small)),
                         heat: Heat(id: "h", raceId: "r", name: "H", sortOrder: 0, drummerId: nil, sweepId: nil, createdAt: Date(), updatedAt: nil))
        return m
    }
    private let a = Seat(bench: 1, side: .left), b = Seat(bench: 1, side: .right), c = Seat(bench: 2, side: .left)

    @Test func dragReserveOntoEmptySeatPlaces() {
        let m = vm(); m.dragDrop(PaddlerID("p1"), onto: a)
        #expect(m.lineup?.paddler(at: a) == PaddlerID("p1"))
    }
    @Test func dragSeatedOntoOccupiedSwaps() {
        let m = vm(); m.dragDrop(PaddlerID("p1"), onto: a); m.dragDrop(PaddlerID("p2"), onto: b)
        m.dragDrop(PaddlerID("p1"), onto: b)
        #expect(m.lineup?.paddler(at: b) == PaddlerID("p1")); #expect(m.lineup?.paddler(at: a) == PaddlerID("p2"))
    }
    @Test func dragSeatedOntoEmptyMoves() {
        let m = vm(); m.dragDrop(PaddlerID("p1"), onto: a); m.dragDrop(PaddlerID("p1"), onto: c)
        #expect(m.lineup?.paddler(at: a) == nil); #expect(m.lineup?.paddler(at: c) == PaddlerID("p1"))
    }
    @Test func dropOnTrayUnseats() {
        let m = vm(); m.dragDrop(PaddlerID("p1"), onto: a); m.dropOnTray(PaddlerID("p1"))
        #expect(m.lineup?.seatedIDs.isEmpty == true); #expect(m.reserves.contains(PaddlerID("p1")))
    }
    @Test func lockTogglesAndDrummerLeavesTheSeats() {
        let m = vm(); m.dragDrop(PaddlerID("p1"), onto: a)
        m.toggleLock(a); #expect(m.lineup?.isLocked(a) == true)
        m.setDrummer(PaddlerID("p1"))
        #expect(m.lineup?.drummerId == PaddlerID("p1")); #expect(m.lineup?.paddler(at: a) == nil)
        #expect(m.reserves.contains(PaddlerID("p1")) == false)   // drummer isn't a reserve
    }
    /// H12: a drop payload that doesn't resolve in the roster (e.g. text dragged in
    /// from another app) is a no-op — no mutate, no undo entry, no save.
    @Test func dragUnknownIDOntoEmptySeatIsANoOp() {
        let m = vm()
        let before = m.lineup
        m.dragDrop(PaddlerID("nope"), onto: a)
        #expect(m.lineup == before)
        #expect(m.canUndo == false)
    }

    @Test func undoThenRedoRoundTrips() {
        let m = vm(); m.dragDrop(PaddlerID("p1"), onto: a)
        m.undo(); #expect(m.lineup?.paddler(at: a) == nil); #expect(m.canRedo)
        m.redo(); #expect(m.lineup?.paddler(at: a) == PaddlerID("p1")); #expect(m.canRedo == false)
        m.dragDrop(PaddlerID("p2"), onto: b)   // a new mutation clears redo
        m.undo(); m.undo(); #expect(m.canRedo)
        m.dragDrop(PaddlerID("p3"), onto: c); #expect(m.canRedo == false)
    }
}

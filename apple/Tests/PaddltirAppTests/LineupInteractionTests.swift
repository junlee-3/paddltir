import Foundation
import PaddltirCore
import Testing
@testable import Paddltir

@MainActor @Suite struct LineupInteractionTests {
    /// `current` lets a test start from a pre-populated (e.g. already-locked) lineup
    /// instead of the empty default — set directly on the injected `PlacementRequest`,
    /// so it costs no `mutate` calls (`canUndo` starts false either way).
    private func vm(current: Lineup? = nil) -> LineupViewModel {
        let db = try! AppDatabase.inMemory()
        let m = LineupViewModel(db: db)
        let paddlers = (1...4).map { i in
            Paddler(id: PaddlerID("p\(i)"), name: "P\(i)", weightKg: 70, ergM: 600, side: .either,
                    gender: i % 2 == 0 ? .male : .female, seatPref: .none, role: .paddler)
        }
        m._injectForTest(request: PlacementRequest(boat: .small, roster: Roster(paddlers), candidates: paddlers.map(\.id), current: current ?? Lineup(boat: .small)),
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
        m.toggleLock(a)   // unlock — F6: a locked occupant can't become drummer either (below)
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

    // MARK: - F4: drummer/sweep can be cleared; a paddler is never both seated and a cap

    @Test func setDrummerNilClearsAndPushesUndo() {
        let m = vm()
        m.setDrummer(PaddlerID("p1"))
        #expect(m.lineup?.drummerId == PaddlerID("p1"))
        m.setDrummer(nil)
        #expect(m.lineup?.drummerId == nil)
        #expect(m.canUndo == true)
        m.undo()
        #expect(m.lineup?.drummerId == PaddlerID("p1"))   // undo restores the pre-clear state
    }

    @Test func dragDropOfCurrentDrummerSeatsThemAndClearsDrummerId() {
        let m = vm()
        m.setDrummer(PaddlerID("p1"))
        m.dragDrop(PaddlerID("p1"), onto: a)
        #expect(m.lineup?.paddler(at: a) == PaddlerID("p1"))
        #expect(m.lineup?.drummerId == nil)   // never both seated and a cap
    }

    @Test func setSweepOfCurrentDrummerClearsDrummerId() {
        let m = vm()
        m.setDrummer(PaddlerID("p1"))
        m.setSweep(PaddlerID("p1"))
        #expect(m.lineup?.sweepId == PaddlerID("p1"))
        #expect(m.lineup?.drummerId == nil)   // never both caps at once
    }

    // MARK: - F6: locked seats resist manual moves

    @Test func dropOntoLockedSeatIsANoOp() {
        let locked = Lineup(boat: .small, assignments: [SeatAssignment(seat: a, paddlerId: PaddlerID("p1"), locked: true)])
        let m = vm(current: locked)
        let before = m.lineup
        m.dragDrop(PaddlerID("p2"), onto: a)
        #expect(m.lineup == before)
        #expect(m.canUndo == false)
    }

    @Test func dropOnTrayOfLockedOccupantIsANoOp() {
        let locked = Lineup(boat: .small, assignments: [SeatAssignment(seat: a, paddlerId: PaddlerID("p1"), locked: true)])
        let m = vm(current: locked)
        let before = m.lineup
        m.dropOnTray(PaddlerID("p1"))
        #expect(m.lineup == before)
        #expect(m.canUndo == false)
    }

    @Test func toggleLockThenDropSucceeds() {
        let locked = Lineup(boat: .small, assignments: [SeatAssignment(seat: a, paddlerId: PaddlerID("p1"), locked: true)])
        let m = vm(current: locked)
        m.toggleLock(a)   // unlock
        #expect(m.lineup?.isLocked(a) == false)
        m.dragDrop(PaddlerID("p2"), onto: a)
        #expect(m.lineup?.paddler(at: a) == PaddlerID("p2"))
        #expect(m.canUndo == true)
    }

    /// F6 follow-up: `setDrummer`/`setSweep` are manual moves too — a locked occupant
    /// resists them exactly like every other choke point (unlock first).
    @Test func setDrummerOfLockedOccupantIsANoOp() {
        let m = vm(); m.dragDrop(PaddlerID("p1"), onto: a)
        m.toggleLock(a)
        let before = m.lineup
        let canUndoBefore = m.canUndo
        m.setDrummer(PaddlerID("p1"))
        #expect(m.lineup == before)
        #expect(m.canUndo == canUndoBefore)
    }

    // MARK: - F3: the editor surfaces every error

    @Test func saveClearsLastErrorOnSuccess() async throws {
        let appDB = try AppDatabase.inMemory()
        try appDB.write { db in
            try Crew(id: "c-1", clubId: "club-1", name: "Crew", ageDivision: "Premier", category: .mixed, createdAt: Date(), updatedAt: nil).insert(db)
            try Race(id: "r-1", sessionId: "s-1", crewId: "c-1", name: "Race 1", boatSize: .standard, distanceM: nil, sortOrder: 0, createdAt: Date(), updatedAt: nil).insert(db)
            try Heat(id: "h-1", raceId: "r-1", name: "Heat 1", sortOrder: 1, drummerId: nil, sweepId: nil, createdAt: Date(), updatedAt: nil).insert(db)
        }
        let model = LineupViewModel(db: appDB)
        await model.load(heatId: "h-1")
        #expect(model.lineup != nil)
        await model.save()
        #expect(model.lastError == nil)
    }

    /// `load(heatId:)` against a heat id with no resolvable crew (no such heat,
    /// here) is a legitimate empty state — `request` (the placement request) stays
    /// nil, and `lastError` stays nil too: "no crew" is not an error.
    @Test func loadMissingHeatIsNoCrewNotError() async throws {
        let appDB = try AppDatabase.inMemory()
        let model = LineupViewModel(db: appDB)
        await model.load(heatId: "does-not-exist")
        #expect(model.isLoaded == true)
        #expect(model.request == nil)
        #expect(model.lastError == nil)
    }

    /// Unlike a genuinely-missing heat (above), a *thrown* read is an error, not
    /// "no crew" — forced here by a `paddlers` row with a `gender` value that
    /// doesn't decode, inserted via raw SQL (the typed `PaddlerRow` API can't
    /// construct an invalid one), so `placementRequest`'s fetch throws.
    @Test func loadSurfacesAThrownReadAsAnError() async throws {
        let appDB = try AppDatabase.inMemory()
        try appDB.write { db in
            try Crew(id: "c-1", clubId: "club-1", name: "Crew", ageDivision: "Premier", category: .mixed, createdAt: Date(), updatedAt: nil).insert(db)
            try Race(id: "r-1", sessionId: "s-1", crewId: "c-1", name: "Race 1", boatSize: .standard, distanceM: nil, sortOrder: 0, createdAt: Date(), updatedAt: nil).insert(db)
            try Heat(id: "h-1", raceId: "r-1", name: "Heat 1", sortOrder: 1, drummerId: nil, sweepId: nil, createdAt: Date(), updatedAt: nil).insert(db)
            try CrewMember(crewId: "c-1", paddlerId: "p-bad", createdAt: Date()).insert(db)
            try db.execute(sql: """
                INSERT INTO paddlers
                    (id, club_id, profile_id, name, email, weight_kg, preferred_side, gender, seat_preference, boat_role, archived_at, created_at, updated_at)
                VALUES (?, ?, NULL, ?, NULL, ?, ?, ?, ?, ?, NULL, ?, NULL)
                """, arguments: ["p-bad", "club-1", "Bad Paddler", 70.0, "either", "not-a-gender", "none", "paddler", Date()])
        }
        let model = LineupViewModel(db: appDB)
        await model.load(heatId: "h-1")
        #expect(model.isLoaded == true)
        #expect(model.lastError != nil)
    }
}

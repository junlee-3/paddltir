import Foundation
import Testing
@testable import PaddltirCore

@Suite struct LineupTests {
    let a = PaddlerID("a"), b = PaddlerID("b"), c = PaddlerID("c")
    var s1L: Seat { Seat(bench: 1, side: .left) }
    var s1R: Seat { Seat(bench: 1, side: .right) }
    var s2L: Seat { Seat(bench: 2, side: .left) }

    @Test func seatOrdering() {
        #expect(Seat(bench: 1, side: .left) < Seat(bench: 1, side: .right))
        #expect(Seat(bench: 1, side: .right) < Seat(bench: 2, side: .left))
        #expect(Boat.small.allSeats.count == 10 && Boat.small.allSeats.first == Seat(bench: 1, side: .left))
    }
    @Test func placeRemoveLookup() {
        var l = Lineup(boat: .small)
        l.place(a, at: s1L)
        #expect(l.paddler(at: s1L) == a && l.seat(of: a) == s1L)
        #expect(l.seatedIDs == [a])
        l.place(a, at: s2L)                      // moving a paddler vacates the old seat
        #expect(l.paddler(at: s1L) == nil && l.seat(of: a) == s2L)
        l.place(b, at: s2L)                      // placing on occupied seat evicts occupant
        #expect(l.seat(of: a) == nil && l.paddler(at: s2L) == b)
        l.remove(at: s2L)
        #expect(l.assignments.isEmpty)
    }
    @Test func swapHandlesEmptyAndLocks() {
        var l = Lineup(boat: .small)
        l.place(a, at: s1L); l.place(b, at: s1R)
        l.swap(s1L, s1R)
        #expect(l.paddler(at: s1L) == b && l.paddler(at: s1R) == a)
        l.swap(s1L, s2L)                          // swap with empty seat = move
        #expect(l.paddler(at: s1L) == nil && l.paddler(at: s2L) == b)
        l.setLocked(true, at: s2L)
        #expect(l.isLocked(s2L) && l.lockedSeats == [s2L])
        l.swap(s2L, s1L)                          // locks travel with the seat, not the paddler
        #expect(l.isLocked(s2L) && !l.isLocked(s1L))
    }
    @Test func canonicalOrderAndEmptySeats() {
        let l = Lineup(boat: .small, assignments: [
            SeatAssignment(bench: 3, side: .right, paddlerId: c),
            SeatAssignment(bench: 1, side: .left, paddlerId: a),
        ])
        #expect(l.assignments.map(\.seat) == [Seat(bench: 1, side: .left), Seat(bench: 3, side: .right)])
        #expect(l.emptySeats.count == 8)
    }
    @Test func codableRoundTrip() throws {
        var l = Lineup(boat: .standard, drummerId: PaddlerID("d"), sweepId: PaddlerID("s"))
        l.place(a, at: s1L); l.setLocked(true, at: s1L)
        let data = try JSONEncoder().encode(l)
        let back = try JSONDecoder().decode(Lineup.self, from: data)
        #expect(back == l)
        let minimal = #"{"bench":2,"side":"right","paddlerId":"q"}"#   // locked defaults to false
        #expect(try JSONDecoder().decode(SeatAssignment.self, from: Data(minimal.utf8)).locked == false)
    }
}

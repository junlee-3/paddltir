import Testing
@testable import PaddltirCore

@Suite struct SuggestionsTests {
    let roster = standardMixedRoster()
    func optimised() -> Lineup {
        Greedy.autoFill(PlacementRequest(boat: .standard, roster: roster, candidates: roster.ids,
                                         drummerId: PaddlerID("drum"), sweepId: PaddlerID("sweep"), rule: .mixed(for: .standard))).lineup
    }
    @Test func noSuggestionsWhenLocallyOptimal() {
        #expect(Suggestions.swaps(in: optimised(), roster: roster).isEmpty)
    }
    @Test func findsImprovingSwapsSortedBest() {
        var l = optimised()
        l.swap(Seat(bench: 1, side: .left), Seat(bench: 10, side: .right))   // wreck it
        let s = Suggestions.swaps(in: l, roster: roster, limit: 3)
        #expect(!s.isEmpty && s.count <= 3)
        for x in s { #expect(x.after.lexKey < x.before.lexKey) }
        #expect(zip(s, s.dropFirst()).allSatisfy { $0.after.lexKey <= $1.after.lexKey })
        #expect(s.first!.improves != .seated && s.first!.improves != .power)   // swaps never change who is seated
    }
    @Test func swapsNeverTouchLockedSeats() {
        var l = optimised()
        l.swap(Seat(bench: 1, side: .left), Seat(bench: 10, side: .right))
        l.setLocked(true, at: Seat(bench: 1, side: .left))
        for s in Suggestions.swaps(in: l, roster: roster, limit: 10) {
            #expect(s.a != Seat(bench: 1, side: .left) && s.b != Seat(bench: 1, side: .left))
        }
    }
    @Test func replacementsFillAVacatedSeat() {
        var l = optimised()
        let vacated = Seat(bench: 5, side: .left)
        let gone = l.paddler(at: vacated)!
        l.remove(at: vacated)
        let reserves = roster.ids.filter { !l.seatedIDs.contains($0) && $0 != gone && $0 != PaddlerID("drum") && $0 != PaddlerID("sweep") }
        let plans = Suggestions.replacements(for: vacated, in: l, candidates: reserves, roster: roster, rule: .mixed(for: .standard), limit: 2)
        #expect(plans.count == 2 && plans[0].incoming != plans[1].incoming)
        for p in plans {
            let applied = l.applying(p.moves)
            #expect(applied.paddler(at: vacated) != nil && applied.seatedIDs.contains(p.incoming))
            #expect(p.moves.count <= 2)
            #expect(Scoring.evaluate(applied, roster: roster).approximatelyEqual(p.after))
        }
    }
}

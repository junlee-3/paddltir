import Testing
@testable import PaddltirCore

@Suite struct ScoringTests {
    /// Hand-computed example (also stored as fixtures/evaluate/eval-small-hand.json).
    func handExample() -> (Roster, Lineup) {
        let roster = Roster([
            makePaddler("p1", w: 60, erg: 500, side: .left, gender: .female, pref: .stroke),
            makePaddler("p2", w: 80, erg: 600, side: .right, gender: .male, pref: .engine),
            makePaddler("p3", w: 70, erg: 550, side: .either, gender: .female, pref: .none),
            makePaddler("p4", w: 90, erg: 450, side: .left, gender: .male, pref: .sprint),
            makePaddler("d1", w: 50, erg: 0, gender: .female, role: .drummer),
            makePaddler("s1", w: 75, erg: 0, gender: .male, role: .sweep),
        ])
        let lineup = Lineup(boat: .small, drummerId: PaddlerID("d1"), sweepId: PaddlerID("s1"), assignments: [
            SeatAssignment(bench: 1, side: .left, paddlerId: PaddlerID("p1")),
            SeatAssignment(bench: 1, side: .right, paddlerId: PaddlerID("p2")),
            SeatAssignment(bench: 4, side: .right, paddlerId: PaddlerID("p3")),
            SeatAssignment(bench: 5, side: .right, paddlerId: PaddlerID("p4")),
        ])
        return (roster, lineup)
    }
    @Test func handComputedMetrics() {
        let (roster, lineup) = handExample()
        let x = Scoring.evaluate(lineup, roster: roster)
        #expect(x.seated == 4 && x.totalPower == 2100)
        #expect(x.weightLeft == 60 && x.weightRight == 240)
        #expect(x.powerLeft == 500 && x.powerRight == 1600)
        #expect(x.sideMismatches == 1)      // p4 prefers left, sits right
        #expect(x.seatMismatches == 1)      // p2 prefers engine (bench 3), sits bench 1
        #expect(abs(x.trimMoment - 45) < 1e-9)  // -120 -160 +70 +180 -150 +225
        #expect(x.women == 2 && x.men == 2 && x.moves == nil)
    }
    @Test func movesCountsChangedAssignments() {
        let (roster, lineup) = handExample()
        var changed = lineup
        changed.swap(Seat(bench: 1, side: .left), Seat(bench: 1, side: .right))
        #expect(Scoring.evaluate(changed, roster: roster, reference: lineup).moves == 2)
        #expect(Scoring.evaluate(lineup, roster: roster, reference: lineup).moves == 0)
    }
    @Test func unknownPaddlersAreIgnored() {
        let (roster, _) = handExample()
        let l = Lineup(boat: .small, assignments: [SeatAssignment(bench: 2, side: .left, paddlerId: PaddlerID("ghost"))])
        #expect(Scoring.evaluate(l, roster: roster).seated == 0)
    }
    @Test func missingDrummerSweepContributeNoTrim() {
        let (roster, _) = handExample()
        var l = Lineup(boat: .small)
        l.place(PaddlerID("p1"), at: Seat(bench: 3, side: .left))     // arm 0
        #expect(Scoring.evaluate(l, roster: roster).trimMoment == 0)
    }
}

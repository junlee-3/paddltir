import Testing
@testable import PaddltirCore

@Suite struct ValidatorTests {
    let roster = Roster([
        makePaddler("p", w: 70, erg: 500), makePaddler("q", w: 70, erg: 500, gender: .female),
        makePaddler("sw", w: 80, erg: 0, role: .sweep), makePaddler("dr", w: 50, erg: 0, role: .drummer),
    ])
    @Test func cleanLineupHasNoViolations() {
        var l = Lineup(boat: .small, drummerId: PaddlerID("dr"), sweepId: PaddlerID("sw"))
        l.place(PaddlerID("p"), at: Seat(bench: 1, side: .left))
        #expect(Validator.violations(in: l, roster: roster, rule: nil).isEmpty)
    }
    @Test func detectsEachViolation() {
        var l = Lineup(boat: .small, drummerId: PaddlerID("dr"), sweepId: PaddlerID("dr"))
        l.place(PaddlerID("ghost"), at: Seat(bench: 1, side: .left))
        l.place(PaddlerID("sw"), at: Seat(bench: 2, side: .left))      // sweep role benched
        l.place(PaddlerID("dr"), at: Seat(bench: 3, side: .left))      // the heat's drummer also benched
        l.place(PaddlerID("p"), at: Seat(bench: 4, side: .left))
        let v = Set(Validator.violations(in: l, roster: roster, rule: GenderRule.womenOnly))
        #expect(v.contains(.unknownPaddler(PaddlerID("ghost"))))
        #expect(v.contains(.sweepOnBench(PaddlerID("sw"))))
        #expect(v.contains(.drummerOnBench(PaddlerID("dr"))))
        #expect(v.contains(.drummerIsSweep(PaddlerID("dr"))))
        #expect(v.contains { if case .genderRule = $0 { return true } else { return false } })
    }
}

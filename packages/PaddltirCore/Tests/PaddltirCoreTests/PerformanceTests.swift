// Tests/PaddltirCoreTests/PerformanceTests.swift
import Testing
@testable import PaddltirCore

@Suite struct PerformanceTests {
    @Test func autoFillIsFastEvenInDebug() {
        let roster = standardMixedRoster()
        let req = PlacementRequest(boat: .standard, roster: roster, candidates: roster.ids,
                                   drummerId: PaddlerID("drum"), sweepId: PaddlerID("sweep"), rule: .mixed(for: .standard))
        _ = Greedy.autoFill(req)   // warm
        let d = ContinuousClock().measure { for _ in 0..<5 { _ = Greedy.autoFill(req) } }
        #expect(d < .milliseconds(2500), "5 runs took \(d) in debug; release must be < 1 ms each (check with FixtureTool bench)")
    }
    @Test func evaluateIsMicroseconds() {
        let roster = standardMixedRoster()
        let l = Greedy.autoFill(PlacementRequest(boat: .standard, roster: roster, candidates: roster.ids)).lineup
        let d = ContinuousClock().measure { for _ in 0..<1000 { _ = Scoring.evaluate(l, roster: roster) } }
        #expect(d < .milliseconds(500))
    }
}

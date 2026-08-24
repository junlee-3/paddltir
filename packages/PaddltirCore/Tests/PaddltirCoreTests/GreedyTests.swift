import Testing
@testable import PaddltirCore

@Suite struct GreedyTests {
    let roster = standardMixedRoster()
    func request(rule: GenderRule? = .mixed(for: .standard), boat: Boat = .standard, candidates: [PaddlerID]? = nil,
                 locked: [SeatAssignment] = [], current: Lineup? = nil) -> PlacementRequest {
        PlacementRequest(boat: boat, roster: roster, candidates: candidates ?? roster.ids,
                         drummerId: PaddlerID("drum"), sweepId: PaddlerID("sweep"), locked: locked, rule: rule, current: current)
    }
    @Test func fillsTheBoatAndRespectsHardConstraints() {
        let r = Greedy.autoFill(request())
        #expect(r.lineup.isFull && r.metrics.seated == 20 && r.ruleSatisfied)
        #expect(Validator.violations(in: r.lineup, roster: roster, rule: .mixed(for: .standard)).isEmpty)
        #expect(r.metrics.women == 8 && r.metrics.men == 12)
        #expect(r.unseated.count == 2)
        #expect(!r.lineup.seatedIDs.contains(PaddlerID("drum")) && !r.lineup.seatedIDs.contains(PaddlerID("sweep")))
    }
    @Test func balancesWeightTightly() {
        let r = Greedy.autoFill(request())
        #expect(r.metrics.weightDelta <= 2.0, "weight delta was \(r.metrics.weightDelta)")
        // 2-opt local optimum for this roster: single swaps that fix remaining side prefs cost
        // weight balance, which the lexicographic order (weight first) correctly refuses.
        // The MIP golden fixtures assert the true optimum; 3 is this algorithm's honest result here.
        #expect(r.metrics.sideMismatches <= 3)
    }
    @Test func isDeterministic() {
        let a = Greedy.autoFill(request()), b = Greedy.autoFill(request())
        #expect(a == b)
    }
    @Test func honoursLocks() {
        let lock = SeatAssignment(bench: 7, side: .right, paddlerId: PaddlerID("w10"), locked: true)  // weakest woman, locked in
        let r = Greedy.autoFill(request(locked: [lock]))
        #expect(r.lineup.paddler(at: Seat(bench: 7, side: .right)) == PaddlerID("w10"))
        #expect(r.lineup.isLocked(Seat(bench: 7, side: .right)))
        #expect(r.ruleSatisfied && r.metrics.women == 8)
    }
    @Test func smallBoatOpen() {
        let r = Greedy.autoFill(request(rule: nil, boat: .small))
        #expect(r.metrics.seated == 10 && r.metrics.totalPower == 6490)   // top-10 ergs: 680+670+660+655+650+645+640+635+630+625
        #expect(r.metrics.weightDelta <= 3.0)
    }
    @Test func underfullBoat() {
        let few = (1...14).map { PaddlerID(String(format: "m%02d", min($0, 12))) } // m01..m12 (+ dupes ignored)
        let r = Greedy.autoFill(request(rule: nil, candidates: few))
        #expect(r.metrics.seated == 12 && r.unseated.isEmpty)
    }
    @Test func relaxesInfeasibleRule() {
        let cands = (1...10).map { PaddlerID(String(format: "w%02d", $0)) } + [PaddlerID("m01"), PaddlerID("m02")]
        let r = Greedy.autoFill(request(candidates: cands))
        #expect(!r.ruleSatisfied && r.metrics.seated == 12)
    }
    @Test func prefersFewerMovesFromCurrent() {
        let base = Greedy.autoFill(request()).lineup
        var current = base
        current.swap(Seat(bench: 2, side: .left), Seat(bench: 3, side: .left))
        let r = Greedy.autoFill(request(current: current))
        #expect(r.metrics.moves != nil && r.metrics.seated == 20)
        #expect(Greedy.autoFill(request(current: current)) == r)   // deterministic with a reference too
        // The reference must never cost quality on the first 7 components vs. the reference-free result.
        let free = Greedy.autoFill(request()).metrics.lexKey.values.prefix(7)
        #expect(!(LexKey(values: Array(free)) < LexKey(values: Array(r.metrics.lexKey.values.prefix(7)))))
    }
    @Test func neverWorseThanNaiveOrder() {
        // Naive: seat strongest 20 alternately L/R from bench 1.
        var naive = Lineup(boat: .standard, drummerId: PaddlerID("drum"), sweepId: PaddlerID("sweep"))
        let ids = Selection.select(capacity: 20, locked: [], candidates: roster.ids, roster: roster, rule: .mixed(for: .standard)).chosen
        for (i, id) in ids.enumerated() { naive.place(id, at: Seat(bench: i / 2 + 1, side: i % 2 == 0 ? .left : .right)) }
        let r = Greedy.autoFill(request())
        #expect(r.metrics.lexKey <= Scoring.evaluate(naive, roster: roster).lexKey)
    }
}

// Tests/PaddltirCoreTests/PropertyTests.swift
import Testing
@testable import PaddltirCore

@Suite struct PropertyTests {
    func randomRoster(seed: UInt64, count: Int) -> Roster {
        var rng = SeededRNG(seed: seed)
        var ps: [Paddler] = []
        for i in 0..<count {
            ps.append(Paddler(id: PaddlerID(String(format: "r%03d", i)), name: "R\(i)",
                              weightKg: Double(Int.random(in: 50...100, using: &rng)), ergM: Double(Int.random(in: 400...700, using: &rng)),
                              side: SidePreference.allCases.randomElement(using: &rng)!, gender: Gender.allCases.randomElement(using: &rng)!,
                              seatPref: SeatPreference.allCases.randomElement(using: &rng)!, role: .paddler))
        }
        return Roster(ps)
    }
    @Test(arguments: 0..<60) func invariantsHold(seed: Int) {
        var rng = SeededRNG(seed: UInt64(seed) &* 7919)
        let boat = Bool.random(using: &rng) ? Boat.standard : Boat.small
        let roster = randomRoster(seed: UInt64(seed), count: Int.random(in: 4...26, using: &rng))
        let rules: [GenderRule?] = [nil, .mixed(for: boat), .womenOnly]
        let rule = rules[Int.random(in: 0..<3, using: &rng)]
        let req = PlacementRequest(boat: boat, roster: roster, candidates: roster.ids, rule: rule)
        let r = Greedy.autoFill(req)
        #expect(r.metrics.seated <= boat.capacity)
        #expect(Set(r.lineup.assignments.map(\.paddlerId)).count == r.lineup.assignments.count)
        #expect(Set(r.lineup.assignments.map(\.seat)).count == r.lineup.assignments.count)
        if r.ruleSatisfied, let rule { #expect(rule.isSatisfied(women: r.metrics.women, men: r.metrics.men), "seed \(seed)") }
        #expect(r.metrics.seated == min(boat.capacity, roster.count) || rule != nil, "no rule ⇒ boat as full as possible")
        #expect(Greedy.autoFill(req) == r, "deterministic")
        // No single swap improves the result (2-opt local optimum).
        #expect(Suggestions.swaps(in: r.lineup, roster: roster, limit: 1).isEmpty, "seed \(seed)")
    }
}

import Testing
@testable import PaddltirCore

@Suite struct SelectionTests {
    let roster = standardMixedRoster()   // w01–w10 (erg 480–540), m01–m12 (erg 615–680)
    var all: [PaddlerID] { roster.ids }

    @Test func eligibleFiltersAndSorts() {
        let e = Selection.eligible(candidates: all, roster: roster, excluding: [PaddlerID("drum")])
        #expect(!e.contains(PaddlerID("sweep")) && !e.contains(PaddlerID("drum")))
        #expect(e.count == 22)
        #expect(e.first == PaddlerID("m06"))       // erg 680 is the highest
        #expect(e.last == PaddlerID("w10"))        // erg 480 lowest
    }
    @Test func noRuleTakesStrongest() {
        let o = Selection.select(capacity: 20, locked: [], candidates: all, roster: roster, rule: nil)
        #expect(o.chosen.count == 20 && o.ruleSatisfied)
        #expect(!o.chosen.contains(PaddlerID("w10")) && !o.chosen.contains(PaddlerID("w06")))  // two weakest cut
    }
    @Test func mixedRuleForcesMinimumWomen() {
        let o = Selection.select(capacity: 20, locked: [], candidates: all, roster: roster, rule: .mixed(for: .standard))
        let women = o.chosen.filter { roster[$0]!.gender == .female }.count
        #expect(o.chosen.count == 20 && women == 8 && o.ruleSatisfied)   // 8 women (min), 12 men (max)
    }
    @Test func lockedCountTowardsRule() {
        let lockedWomen = (1...9).map { PaddlerID(String(format: "w%02d", $0)) }
        let o = Selection.select(capacity: 20, locked: lockedWomen, candidates: all, roster: roster, rule: .mixed(for: .standard))
        let women = o.chosen.filter { roster[$0]!.gender == .female }.count
        #expect(o.chosen.count == 11 && women == 0 && o.ruleSatisfied)     // 9 locked women + 11 men = 20
    }
    @Test func capsReduceSeatedWhenNecessary() {
        let onlyWomenPlusThree = (1...10).map { PaddlerID(String(format: "w%02d", $0)) } + [PaddlerID("m01"), PaddlerID("m02"), PaddlerID("m03")]
        let o = Selection.select(capacity: 20, locked: [], candidates: onlyWomenPlusThree, roster: roster, rule: .mixed(for: .standard))
        #expect(!o.ruleSatisfied)         // minMen 8 impossible with 3 men → rule relaxed entirely
        #expect(o.chosen.count == 13)
    }
    @Test func maxCapHoldsWhenMinsFeasible() {
        let rule = GenderRule(minWomen: 2, maxWomen: 4, minMen: 2, maxMen: 20)
        let o = Selection.select(capacity: 20, locked: [], candidates: all, roster: roster, rule: rule)
        let women = o.chosen.filter { roster[$0]!.gender == .female }.count
        #expect(o.ruleSatisfied && women == 4 && o.chosen.count == 16)   // 4 women max + 12 men available
    }
    @Test func womenOnly() {
        let o = Selection.select(capacity: 10, locked: [], candidates: all, roster: roster, rule: .womenOnly)
        #expect(o.ruleSatisfied && o.chosen.count == 10 && o.chosen.allSatisfy { roster[$0]!.gender == .female })
    }
}

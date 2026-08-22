import Foundation
import Testing
@testable import PaddltirCore

@Suite struct GenderRuleTests {
    @Test func idbfPresets() {
        let std = GenderRule.mixed(for: .standard)
        #expect(std == GenderRule(minWomen: 8, maxWomen: 12, minMen: 8, maxMen: 12))
        let small = GenderRule.mixed(for: .small)
        #expect(small == GenderRule(minWomen: 4, maxWomen: 6, minMen: 4, maxMen: 6))
        #expect(GenderRule.womenOnly == GenderRule(minWomen: nil, maxWomen: nil, minMen: nil, maxMen: 0))
    }
    @Test func satisfaction() {
        let r = GenderRule.mixed(for: .standard)
        #expect(r.isSatisfied(women: 8, men: 12))
        #expect(r.isSatisfied(women: 10, men: 8))
        #expect(!r.isSatisfied(women: 7, men: 13))
        #expect(!r.isSatisfied(women: 13, men: 7))
        #expect(GenderRule.womenOnly.isSatisfied(women: 20, men: 0))
        #expect(!GenderRule.womenOnly.isSatisfied(women: 19, men: 1))
    }
    @Test func jsonOmitsNils() throws {
        let enc = JSONEncoder(); enc.outputFormatting = [.sortedKeys]
        let data = try enc.encode(GenderRule.womenOnly)
        #expect(String(decoding: data, as: UTF8.self) == #"{"maxMen":0}"#)
        let back = try JSONDecoder().decode(GenderRule.self, from: Data(#"{"minWomen":8,"maxWomen":12}"#.utf8))
        #expect(back == GenderRule(minWomen: 8, maxWomen: 12, minMen: nil, maxMen: nil))
    }
}

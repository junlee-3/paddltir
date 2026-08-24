import Foundation
import Testing
@testable import PaddltirCore

@Suite struct FixtureTests {
    @Test func evaluateFixturesMatchExactly() throws {
        let dir = fixturesURL().appendingPathComponent("evaluate")
        let fixtures = try Fixture.loadAll(in: dir)
        #expect(fixtures.count >= 2)
        for f in fixtures {
            let lineup = try #require(f.evaluationLineup)
            let expected = try #require(f.expected?.metrics)
            let reference = f.current.map { Lineup(boat: f.boat, drummerId: f.drummerId, sweepId: f.sweepId, assignments: $0) }
            let got = Scoring.evaluate(lineup, roster: f.roster, reference: reference)
            #expect(got.approximatelyEqual(expected), "\(f.name): got \(got) expected \(expected)")
        }
    }
    @Test func placementFixturesMatchGreedyGolden() throws {
        let dir = fixturesURL().appendingPathComponent("placement")
        for f in try Fixture.loadAll(in: dir) {
            let result = Greedy.autoFill(f.placementRequest)
            let golden = try #require(f.expected?.greedy, "\(f.name) has no expected.greedy — run `swift run FixtureTool update-greedy fixtures/placement`")
            #expect(result.lineup.assignments == golden.seats, "\(f.name) seats differ")
            #expect(result.metrics.approximatelyEqual(golden.metrics), "\(f.name) metrics differ")
            #expect(result.ruleSatisfied == golden.ruleSatisfied)
            // invariants hold regardless of golden content
            #expect(Validator.violations(in: result.lineup, roster: f.roster, rule: result.ruleSatisfied ? f.rule : nil).isEmpty)
            #expect(result.metrics.seated <= f.boat.capacity)
        }
    }
    @Test func placementFixtureNamesMatchFiles() throws {
        let dir = fixturesURL().appendingPathComponent("placement")
        for url in try FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil) where url.pathExtension == "json" {
            #expect(try Fixture.load(from: url).name == url.deletingPathExtension().lastPathComponent)
        }
    }
}

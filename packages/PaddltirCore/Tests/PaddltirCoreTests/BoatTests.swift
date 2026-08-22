import Testing
@testable import PaddltirCore

@Suite struct BoatTests {
    @Test func standardGeometry() {
        let b = Boat.standard
        #expect(b.benches == 10 && b.capacity == 20)
        #expect(b.midpoint == 5.5)
        #expect(b.arm(ofBench: 1) == -4.5 && b.arm(ofBench: 10) == 4.5)
        #expect(b.drummerArm == -5.5 && b.sweepArm == 5.5)
    }
    @Test func standardSections() {
        let b = Boat.standard
        #expect(b.benches(in: .stroke) == 1...1)
        #expect(b.benches(in: .pace) == 2...3)
        #expect(b.benches(in: .engine) == 4...7)
        #expect(b.benches(in: .sprint) == 8...10)
        #expect(b.section(ofBench: 5) == .engine && b.section(ofBench: 8) == .sprint)
    }
    @Test func smallSections() {
        let b = Boat.small
        #expect(b.capacity == 10 && b.midpoint == 3)
        #expect(b.benches(in: .stroke) == 1...1)
        #expect(b.benches(in: .pace) == 2...2)
        #expect(b.benches(in: .engine) == 3...3)
        #expect(b.benches(in: .sprint) == 4...5)
    }
    @Test func sectionsPartitionEveryBench() {
        for n in 4...12 {
            let b = Boat(benches: n)
            var covered: [Int] = []
            for s in Section.allCases { covered.append(contentsOf: Array(b.benches(in: s))) }
            #expect(covered == Array(1...n), "n=\(n)")
        }
    }
}

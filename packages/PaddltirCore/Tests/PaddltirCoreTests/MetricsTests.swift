import Testing
@testable import PaddltirCore

@Suite struct MetricsTests {
    func m(seated: Int = 20, power: Double = 10000, wl: Double = 700, wr: Double = 700, pl: Double = 5000, pr: Double = 5000,
           side: Int = 0, seat: Int = 0, trim: Double = 0, moves: Int? = nil) -> Metrics {
        Metrics(seated: seated, totalPower: power, weightLeft: wl, weightRight: wr, powerLeft: pl, powerRight: pr,
                sideMismatches: side, seatMismatches: seat, trimMoment: trim, women: 10, men: 10, moves: moves)
    }
    @Test func lexKeyOrdersByPriority() {
        #expect(m(seated: 20).lexKey < m(seated: 19, wl: 700, wr: 700).lexKey)          // more seated wins
        #expect(m(power: 10001).lexKey < m(power: 10000).lexKey)                          // more total power wins
        #expect(m(wl: 701).lexKey > m().lexKey)                                           // weight delta
        #expect(m(side: 1).lexKey > m(pl: 5010).lexKey)                                   // side beats power
        #expect(m(seat: 1).lexKey > m(pl: 5010).lexKey)                                   // seat beats power
        #expect(m(pl: 5010).lexKey > m(trim: 100).lexKey)                                 // power beats trim
        #expect(m(trim: 100, moves: 0).lexKey < m(trim: 100, moves: 3).lexKey)            // moves last
        #expect(m(trim: -5).lexKey == m(trim: 5).lexKey)                                  // |trim|
    }
    @Test func lexKeyToleratesFloatNoise() {
        #expect(m(wl: 700.0000000001).lexKey == m().lexKey)
    }
    @Test func warnings() {
        let t = Thresholds.default
        #expect(m().warnings(boat: .standard, thresholds: t).isEmpty)
        #expect(m(wl: 711).warnings(boat: .standard, thresholds: t) == [.weight])          // Δ 11 kg > 10
        #expect(m(pl: 5501, pr: 4499).warnings(boat: .standard, thresholds: t) == [.power]) // Δ 1002 > 10% of 10000
        #expect(m(side: 5).warnings(boat: .standard, thresholds: t) == [.side])             // 15/20 = 75% < 80%
        #expect(m(trim: 260).warnings(boat: .standard, thresholds: t) == [.trim])           // 2*260/10 = 52 kg > 50
    }
    @Test func derivedValues() {
        let x = m(wl: 690, wr: 710, pl: 4900, pr: 5100, trim: 55)
        #expect(x.weightDelta == 20 && x.powerDelta == 200 && x.totalWeight == 1400)
        #expect(x.trimDeltaKg(boat: .standard) == 11)
        #expect(x.sidePreferenceFraction == 1)
    }
}

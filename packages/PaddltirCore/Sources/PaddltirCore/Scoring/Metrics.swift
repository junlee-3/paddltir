import Foundation

/// Everything we measure about a lineup. Pure data; see fixtures/README.md for the JSON contract.
public struct Metrics: Hashable, Codable, Sendable {
    public var seated: Int
    public var totalPower: Double
    public var weightLeft: Double
    public var weightRight: Double
    public var powerLeft: Double
    public var powerRight: Double
    public var sideMismatches: Int
    public var seatMismatches: Int
    /// Signed fore-aft moment Σ w·arm (+ drummer/sweep). Negative = bow-heavy.
    public var trimMoment: Double
    public var women: Int
    public var men: Int
    /// Assignments changed relative to a reference lineup; nil when no reference.
    public var moves: Int?

    public init(seated: Int, totalPower: Double, weightLeft: Double, weightRight: Double, powerLeft: Double,
                powerRight: Double, sideMismatches: Int, seatMismatches: Int, trimMoment: Double,
                women: Int, men: Int, moves: Int? = nil) {
        self.seated = seated; self.totalPower = totalPower; self.weightLeft = weightLeft; self.weightRight = weightRight
        self.powerLeft = powerLeft; self.powerRight = powerRight; self.sideMismatches = sideMismatches
        self.seatMismatches = seatMismatches; self.trimMoment = trimMoment; self.women = women; self.men = men
        self.moves = moves
    }

    public var weightDelta: Double { abs(weightLeft - weightRight) }
    public var powerDelta: Double { abs(powerLeft - powerRight) }
    public var totalWeight: Double { weightLeft + weightRight }
    /// Share of seated paddlers on a side they accept (1.0 when nobody is seated).
    public var sidePreferenceFraction: Double { seated == 0 ? 1 : Double(seated - sideMismatches) / Double(seated) }
    /// Old-prototype-compatible "kg front/back heavy" figure: 2·|moment|/n.
    public func trimDeltaKg(boat: Boat) -> Double { 2 * abs(trimMoment) / Double(boat.benches) }

    public var lexKey: LexKey {
        LexKey(values: [Double(-seated), -totalPower, weightDelta, Double(sideMismatches), Double(seatMismatches),
                        powerDelta, abs(trimMoment), Double(moves ?? 0)])
    }

    public enum Warning: String, Hashable, Codable, Sendable, CaseIterable { case weight, power, side, trim }
    public func warnings(boat: Boat, thresholds: Thresholds = .default) -> Set<Warning> {
        var w: Set<Warning> = []
        if weightDelta > thresholds.weightDeltaWarnKg { w.insert(.weight) }
        if totalPower > 0, powerDelta > thresholds.powerDeltaWarnFraction * totalPower { w.insert(.power) }
        if sidePreferenceFraction < thresholds.sidePreferenceMinFraction { w.insert(.side) }
        if trimDeltaKg(boat: boat) > thresholds.trimDeltaWarnKg { w.insert(.trim) }
        return w
    }

    public func approximatelyEqual(_ o: Metrics, tolerance: Double = 1e-6) -> Bool {
        seated == o.seated && sideMismatches == o.sideMismatches && seatMismatches == o.seatMismatches
        && women == o.women && men == o.men && moves == o.moves
        && abs(totalPower - o.totalPower) <= tolerance && abs(weightLeft - o.weightLeft) <= tolerance
        && abs(weightRight - o.weightRight) <= tolerance && abs(powerLeft - o.powerLeft) <= tolerance
        && abs(powerRight - o.powerRight) <= tolerance && abs(trimMoment - o.trimMoment) <= tolerance
    }
}

/// Lexicographic ordering key. Lower is better at every position. Equality is tolerance-based (1e-9).
public struct LexKey: Comparable, Sendable, CustomStringConvertible {
    public static let tolerance = 1e-9
    public let values: [Double]
    public init(values: [Double]) { self.values = values }
    public static func == (a: LexKey, b: LexKey) -> Bool {
        a.values.count == b.values.count && zip(a.values, b.values).allSatisfy { abs($0 - $1) <= tolerance }
    }
    public static func < (a: LexKey, b: LexKey) -> Bool {
        for (x, y) in zip(a.values, b.values) {
            if abs(x - y) <= tolerance { continue }
            return x < y
        }
        return false
    }
    /// Index of the first component where `self` is strictly better than `other`, or nil.
    public func firstImprovement(over other: LexKey) -> Int? {
        for (i, (x, y)) in zip(values, other.values).enumerated() where abs(x - y) > LexKey.tolerance { return x < y ? i : nil }
        return nil
    }
    public var description: String { values.map { String(format: "%.3f", $0) }.joined(separator: " | ") }
}

public struct Thresholds: Hashable, Codable, Sendable {
    public var weightDeltaWarnKg: Double
    public var powerDeltaWarnFraction: Double
    public var sidePreferenceMinFraction: Double
    public var trimDeltaWarnKg: Double
    public init(weightDeltaWarnKg: Double = 10, powerDeltaWarnFraction: Double = 0.1,
                sidePreferenceMinFraction: Double = 0.8, trimDeltaWarnKg: Double = 50) {
        self.weightDeltaWarnKg = weightDeltaWarnKg; self.powerDeltaWarnFraction = powerDeltaWarnFraction
        self.sidePreferenceMinFraction = sidePreferenceMinFraction; self.trimDeltaWarnKg = trimDeltaWarnKg
    }
    public static let `default` = Thresholds()
}

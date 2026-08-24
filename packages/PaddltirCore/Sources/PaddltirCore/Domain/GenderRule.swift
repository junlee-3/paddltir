import Foundation

/// Bounds on how many women / men may be benched. `nil` = unbounded. Counted over benched paddlers only.
public struct GenderRule: Hashable, Codable, Sendable {
    public var minWomen: Int?
    public var maxWomen: Int?
    public var minMen: Int?
    public var maxMen: Int?
    public init(minWomen: Int? = nil, maxWomen: Int? = nil, minMen: Int? = nil, maxMen: Int? = nil) {
        self.minWomen = minWomen; self.maxWomen = maxWomen; self.minMen = minMen; self.maxMen = maxMen
    }
    /// IDBF default: standard 8–12 of each gender, small 4–6; other sizes scale 40–60 % of capacity.
    public static func mixed(for boat: Boat) -> GenderRule {
        let cap = Double(boat.capacity)
        let lo = Int((cap * 0.4).rounded()), hi = Int((cap * 0.6).rounded())
        return GenderRule(minWomen: lo, maxWomen: hi, minMen: lo, maxMen: hi)
    }
    public static let womenOnly = GenderRule(maxMen: 0)

    public func isSatisfied(women: Int, men: Int) -> Bool { violation(women: women, men: men) == nil }
    /// Human-readable reason the counts violate the rule, or nil.
    public func violation(women: Int, men: Int) -> String? {
        if let m = minWomen, women < m { return "needs at least \(m) women (has \(women))" }
        if let m = maxWomen, women > m { return "at most \(m) women allowed (has \(women))" }
        if let m = minMen, men < m { return "needs at least \(m) men (has \(men))" }
        if let m = maxMen, men > m { return "at most \(m) men allowed (has \(men))" }
        return nil
    }
    // Encode only non-nil keys so JSON stays minimal and language-neutral.
    enum CodingKeys: String, CodingKey { case minWomen, maxWomen, minMen, maxMen }
    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encodeIfPresent(minWomen, forKey: .minWomen); try c.encodeIfPresent(maxWomen, forKey: .maxWomen)
        try c.encodeIfPresent(minMen, forKey: .minMen); try c.encodeIfPresent(maxMen, forKey: .maxMen)
    }
}

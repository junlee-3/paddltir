import Foundation

public enum Violation: Hashable, Codable, Sendable {
    case unknownPaddler(PaddlerID)
    case seatOutOfRange(Seat)
    /// A paddler whose role is `sweep` is benched.
    case sweepOnBench(PaddlerID)
    /// The heat's drummer or sweep also occupies a bench.
    case drummerOnBench(PaddlerID)
    case sweepSeatedOnBench(PaddlerID)
    case drummerIsSweep(PaddlerID)
    case genderRule(String)
}

public enum Validator {
    public static func violations(in lineup: Lineup, roster: Roster, rule: GenderRule?) -> [Violation] {
        var out: [Violation] = []
        for a in lineup.assignments {
            if !lineup.boat.benchRange.contains(a.bench) { out.append(.seatOutOfRange(a.seat)) }
            guard let p = roster[a.paddlerId] else { out.append(.unknownPaddler(a.paddlerId)); continue }
            if p.role == .sweep { out.append(.sweepOnBench(p.id)) }
            if a.paddlerId == lineup.drummerId { out.append(.drummerOnBench(p.id)) }
            if a.paddlerId == lineup.sweepId { out.append(.sweepSeatedOnBench(p.id)) }
        }
        if let d = lineup.drummerId, d == lineup.sweepId { out.append(.drummerIsSweep(d)) }
        if let rule {
            let m = Scoring.evaluate(lineup, roster: roster)
            if let why = rule.violation(women: m.women, men: m.men) { out.append(.genderRule(why)) }
        }
        return out
    }
}

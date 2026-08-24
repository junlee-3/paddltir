import Foundation

/// Which lexicographic component a change improves first (index into LexKey.values).
public enum Improvement: String, Codable, Hashable, Sendable, CaseIterable {
    case seated, power, weight, side, seat, powerBalance, trim, moves
    static func at(index: Int) -> Improvement { Improvement.allCases[min(index, Improvement.allCases.count - 1)] }
}

public enum Move: Hashable, Codable, Sendable {
    case place(PaddlerID, at: Seat)
    case swap(Seat, Seat)
}

public struct SwapSuggestion: Hashable, Codable, Sendable {
    public var a: Seat
    public var b: Seat
    public var before: Metrics
    public var after: Metrics
    public var improves: Improvement
}

public struct ReplacementPlan: Hashable, Codable, Sendable {
    public var incoming: PaddlerID
    public var moves: [Move]
    public var after: Metrics
}

extension Lineup {
    public func applying(_ moves: [Move]) -> Lineup {
        var l = self
        for m in moves {
            switch m {
            case .place(let id, let seat): l.place(id, at: seat)
            case .swap(let a, let b): l.swap(a, b)
            }
        }
        return l
    }
}

public enum Suggestions {
    /// Strictly improving seat↔seat swaps, best first. Locked seats are never moved.
    public static func swaps(in lineup: Lineup, roster: Roster, reference: Lineup? = nil, limit: Int = 3) -> [SwapSuggestion] {
        let before = Scoring.evaluate(lineup, roster: roster, reference: reference)
        let seats = lineup.boat.allSeats
        var out: [SwapSuggestion] = []
        for i in 0..<seats.count where !lineup.isLocked(seats[i]) {
            for j in (i + 1)..<seats.count where !lineup.isLocked(seats[j]) {
                if lineup.paddler(at: seats[i]) == nil && lineup.paddler(at: seats[j]) == nil { continue }
                var trial = lineup
                trial.swap(seats[i], seats[j])
                let after = Scoring.evaluate(trial, roster: roster, reference: reference)
                if let idx = after.lexKey.firstImprovement(over: before.lexKey) {
                    out.append(SwapSuggestion(a: seats[i], b: seats[j], before: before, after: after, improves: .at(index: idx)))
                }
            }
        }
        out.sort { $0.after.lexKey < $1.after.lexKey }
        return Array(out.prefix(limit))
    }

    /// Plans to fill `seat` from `candidates`: either place directly, or place then one improving swap.
    /// Best first, distinct incoming paddlers preferred. Respects the gender rule when given.
    public static func replacements(for seat: Seat, in lineup: Lineup, candidates: [PaddlerID], roster: Roster,
                                    rule: GenderRule?, limit: Int = 3) -> [ReplacementPlan] {
        let fixed: Set<PaddlerID> = Set([lineup.drummerId, lineup.sweepId].compactMap { $0 }).union(lineup.seatedIDs)
        let pool = Selection.eligible(candidates: candidates, roster: roster, excluding: fixed)
        var plans: [ReplacementPlan] = []
        for id in pool {
            var filled = lineup
            filled.place(id, at: seat)
            let m0 = Scoring.evaluate(filled, roster: roster)
            if let rule, !rule.isSatisfied(women: m0.women, men: m0.men) { continue }
            var best = ReplacementPlan(incoming: id, moves: [.place(id, at: seat)], after: m0)
            if let s = swaps(in: filled, roster: roster, limit: 1).first {
                best = ReplacementPlan(incoming: id, moves: [.place(id, at: seat), .swap(s.a, s.b)], after: s.after)
            }
            plans.append(best)
        }
        plans.sort { $0.after.lexKey < $1.after.lexKey }
        var seen: Set<PaddlerID> = [], out: [ReplacementPlan] = []
        for p in plans where !seen.contains(p.incoming) { seen.insert(p.incoming); out.append(p); if out.count == limit { break } }
        return out
    }
}

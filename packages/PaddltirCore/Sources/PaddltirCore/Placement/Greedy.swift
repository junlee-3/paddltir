import Foundation

/// Instant, deterministic, offline placement. Select → construct → 2-opt improve.
public enum Greedy {
    public static func autoFill(_ req: PlacementRequest) -> PlacementResult {
        let boat = req.boat, roster = req.roster
        var lineup = Lineup(boat: boat, drummerId: req.drummerId, sweepId: req.sweepId,
                            assignments: req.locked.map { SeatAssignment(seat: $0.seat, paddlerId: $0.paddlerId, locked: true) })
        let fixed: Set<PaddlerID> = Set([req.drummerId, req.sweepId].compactMap { $0 })
        let lockedIDs = Array(lineup.seatedIDs)
        let pool = Selection.eligible(candidates: req.candidates, roster: roster, excluding: fixed.union(lockedIDs))
        let selection = Selection.select(capacity: boat.capacity, locked: lockedIDs,
                                         candidates: req.candidates.filter { !fixed.contains($0) }, roster: roster, rule: req.rule)
        let ruleActive = req.rule != nil && selection.ruleSatisfied
        let rule = ruleActive ? req.rule : nil

        // Construct: heaviest first (weight is priority 1 after selection), strongest as tie-break.
        let order = selection.chosen.sorted {
            let a = roster[$0]!, b = roster[$1]!
            if a.weightKg != b.weightKg { return a.weightKg > b.weightKg }
            if a.ergM != b.ergM { return a.ergM > b.ergM }
            return a.id < b.id
        }
        for id in order {
            var bestSeat: Seat? = nil, bestKey: LexKey? = nil
            for seat in lineup.emptySeats {
                var trial = lineup
                trial.place(id, at: seat)
                let key = Scoring.evaluate(trial, roster: roster, reference: req.current).lexKey
                if bestKey == nil || key < bestKey! { bestKey = key; bestSeat = seat }
            }
            if let bestSeat { lineup.place(id, at: bestSeat) }
        }

        let reserves = pool.filter { !lineup.seatedIDs.contains($0) }
        improve(&lineup, pool: reserves, roster: roster, rule: rule, reference: req.current)

        let metrics = Scoring.evaluate(lineup, roster: roster, reference: req.current)
        let unseated = pool.filter { !lineup.seatedIDs.contains($0) }
        return PlacementResult(lineup: lineup, metrics: metrics, ruleSatisfied: selection.ruleSatisfied, unseated: unseated)
    }

    /// 2-opt: repeatedly apply the single best improving swap (seat↔seat) or replacement (seat↔reserve).
    /// Locked seats never move. Replacements must keep the gender rule when one is active.
    static func improve(_ lineup: inout Lineup, pool: [PaddlerID], roster: Roster, rule: GenderRule?, reference: Lineup?) {
        let seats = lineup.boat.allSeats
        var reserves = pool
        var iterations = 0
        while iterations < 500 {
            iterations += 1
            let currentKey = Scoring.evaluate(lineup, roster: roster, reference: reference).lexKey
            var bestKey = currentKey
            var bestLineup: Lineup? = nil
            var bestReserves: [PaddlerID]? = nil

            for i in 0..<seats.count {
                let s1 = seats[i]
                if lineup.isLocked(s1) { continue }
                for j in (i + 1)..<seats.count {
                    let s2 = seats[j]
                    if lineup.isLocked(s2) { continue }
                    if lineup.paddler(at: s1) == nil && lineup.paddler(at: s2) == nil { continue }
                    var trial = lineup
                    trial.swap(s1, s2)
                    let key = Scoring.evaluate(trial, roster: roster, reference: reference).lexKey
                    if key < bestKey { bestKey = key; bestLineup = trial; bestReserves = reserves }
                }
                guard let out = lineup.paddler(at: s1) else { continue }
                for (ri, inId) in reserves.enumerated() {
                    var trial = lineup
                    trial.place(inId, at: s1)
                    let m = Scoring.evaluate(trial, roster: roster, reference: reference)
                    if let rule, !rule.isSatisfied(women: m.women, men: m.men) { continue }
                    if m.lexKey < bestKey {
                        bestKey = m.lexKey; bestLineup = trial
                        var r = reserves; r[ri] = out; bestReserves = r
                    }
                }
            }
            guard let next = bestLineup, let nextReserves = bestReserves else { break }
            lineup = next
            reserves = nextReserves
        }
    }
}

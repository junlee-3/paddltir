import Foundation

public enum Selection {
    public struct Outcome: Hashable, Sendable {
        public var chosen: [PaddlerID]       // strongest first, excludes locked
        public var ruleSatisfied: Bool
    }

    /// Known, may-paddle, not excluded; sorted erg desc, weight desc, id asc. Deterministic.
    public static func eligible(candidates: [PaddlerID], roster: Roster, excluding: Set<PaddlerID> = []) -> [PaddlerID] {
        var seen: Set<PaddlerID> = []
        let ps = candidates.compactMap { id -> Paddler? in
            guard !excluding.contains(id), !seen.contains(id), let p = roster[id], p.role.mayPaddle else { return nil }
            seen.insert(id); return p
        }
        return ps.sorted {
            if $0.ergM != $1.ergM { return $0.ergM > $1.ergM }
            if $0.weightKg != $1.weightKg { return $0.weightKg > $1.weightKg }
            return $0.id < $1.id
        }.map(\.id)
    }

    /// Chooses who fills the `capacity - locked.count` free seats. `locked` paddlers are already seated and count
    /// towards the rule. Returns the strongest feasible set; if the rule is infeasible it is dropped entirely.
    public static func select(capacity: Int, locked: [PaddlerID], candidates: [PaddlerID], roster: Roster, rule: GenderRule?) -> Outcome {
        let lockedSet = Set(locked)
        let pool = eligible(candidates: candidates, roster: roster, excluding: lockedSet)
        let slots = max(0, capacity - lockedSet.count)
        guard let rule else { return Outcome(chosen: Array(pool.prefix(slots)), ruleSatisfied: true) }

        let lockedW = locked.filter { roster[$0]?.gender == .female }.count
        let lockedM = locked.filter { roster[$0]?.gender == .male }.count
        let women = pool.filter { roster[$0]!.gender == .female }
        let men = pool.filter { roster[$0]!.gender == .male }
        let needW = max(0, (rule.minWomen ?? 0) - lockedW)
        let needM = max(0, (rule.minMen ?? 0) - lockedM)
        let capW = (rule.maxWomen ?? Int.max) == Int.max ? Int.max : rule.maxWomen! - lockedW
        let capM = (rule.maxMen ?? Int.max) == Int.max ? Int.max : rule.maxMen! - lockedM
        let feasible = capW >= needW && capM >= needM && needW <= women.count && needM <= men.count && needW + needM <= slots
        guard feasible else { return Outcome(chosen: Array(pool.prefix(slots)), ruleSatisfied: false) }

        var chosen: [PaddlerID] = Array(women.prefix(needW)) + Array(men.prefix(needM))
        var usedW = needW, usedM = needM
        for id in pool where chosen.count < slots && !chosen.contains(id) {
            if roster[id]!.gender == .female { if usedW < capW { chosen.append(id); usedW += 1 } }
            else { if usedM < capM { chosen.append(id); usedM += 1 } }
        }
        // Preserve strongest-first order in the output.
        let order = Dictionary(uniqueKeysWithValues: pool.enumerated().map { ($1, $0) })
        chosen.sort { order[$0]! < order[$1]! }
        return Outcome(chosen: chosen, ruleSatisfied: true)
    }
}

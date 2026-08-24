import Foundation

public enum Scoring {
    /// Computes all metrics for a lineup. Unknown paddler ids are ignored; drummer/sweep only affect trim.
    /// Precondition: the lineup is structurally valid (see `Validator`). Metrics are undefined for an invalid
    /// lineup — in particular, if a paddler is both benched and named as the lineup's drummer or sweep, their
    /// weight is counted twice in `trimMoment`. Callers guard with `Validator.violations(in:roster:rule:)`.
    public static func evaluate(_ lineup: Lineup, roster: Roster, reference: Lineup? = nil) -> Metrics {
        let boat = lineup.boat
        var seated = 0, side = 0, seat = 0, women = 0, men = 0
        var wl = 0.0, wr = 0.0, pl = 0.0, pr = 0.0, trim = 0.0
        for a in lineup.assignments {
            guard let p = roster[a.paddlerId] else { continue }
            seated += 1
            if a.side == .left { wl += p.weightKg; pl += p.ergM } else { wr += p.weightKg; pr += p.ergM }
            if !p.side.matches(a.side) { side += 1 }
            if let s = p.seatPref.section, !boat.benches(in: s).contains(a.bench) { seat += 1 }
            trim += p.weightKg * boat.arm(ofBench: a.bench)
            if p.gender == .female { women += 1 } else { men += 1 }
        }
        if let d = lineup.drummerId, let p = roster[d] { trim += p.weightKg * boat.drummerArm }
        if let s = lineup.sweepId, let p = roster[s] { trim += p.weightKg * boat.sweepArm }
        var moves: Int? = nil
        if let reference {
            moves = reference.assignments.filter { lineup.paddler(at: $0.seat) != $0.paddlerId }.count
        }
        return Metrics(seated: seated, totalPower: pl + pr, weightLeft: wl, weightRight: wr, powerLeft: pl, powerRight: pr,
                       sideMismatches: side, seatMismatches: seat, trimMoment: trim, women: women, men: men, moves: moves)
    }
}

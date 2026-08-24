from .model import Lineup, Metrics, Roster, Side


def evaluate(lineup: Lineup, roster: Roster, reference: Lineup | None = None) -> Metrics:
    """Identical semantics to PaddltirCore.Scoring.evaluate. Unknown ids ignored; drummer/sweep only affect trim."""
    boat = lineup.boat
    seated = side = seat = women = men = 0
    wl = wr = pl = pr = trim = 0.0
    for a in lineup.assignments:
        p = roster.get(a.paddler_id)
        if p is None: continue
        seated += 1
        if a.side is Side.left: wl += p.weight_kg; pl += p.erg_m
        else: wr += p.weight_kg; pr += p.erg_m
        if not p.side.matches(a.side): side += 1
        sec = p.seat_pref.section
        if sec is not None and a.bench not in boat.benches_in(sec): seat += 1
        trim += p.weight_kg * boat.arm(a.bench)
        if p.gender.value == "female": women += 1
        else: men += 1
    if lineup.drummer_id and (d := roster.get(lineup.drummer_id)): trim += d.weight_kg * boat.drummer_arm
    if lineup.sweep_id and (s := roster.get(lineup.sweep_id)): trim += s.weight_kg * boat.sweep_arm
    moves = None
    if reference is not None:
        moves = sum(1 for a in reference.assignments if lineup.paddler_at(a.seat) != a.paddler_id)
    return Metrics(seated, pl + pr, wl, wr, pl, pr, side, seat, trim, women, men, moves)

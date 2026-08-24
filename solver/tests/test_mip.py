from paddltir_solver.mip import DEFAULT_CAPS, solve
from paddltir_solver.model import (
    STAGES,
    Boat,
    Gender,
    GenderRule,
    Lineup,
    Paddler,
    PlacementRequest,
    Role,
    Roster,
    Seat,
    SeatAssignment,
    SeatPref,
    Side,
    SidePref,
)
from paddltir_solver.scoring import evaluate


def mk(i, w, e, side="either", g="male", pref="none", role="paddler"):
    return Paddler(i, i.upper(), w, e, SidePref(side), Gender(g), SeatPref(pref), Role(role))

def std_roster():
    women = [(58,520,"left","stroke"),(62,540,"right","stroke"),(60,500,"left","pace"),(64,515,"either","pace"),(66,530,"right","engine"),
             (59,490,"left","engine"),(63,505,"right","engine"),(61,495,"either","sprint"),(65,510,"left","sprint"),(57,480,"right","none")]
    men = [(78,640,"left","stroke"),(82,660,"right","pace"),(85,650,"left","engine"),(88,670,"right","engine"),(80,630,"either","engine"),
           (90,680,"left","engine"),(76,620,"right","sprint"),(84,645,"left","sprint"),(79,635,"either","sprint"),(86,655,"right","none"),
           (83,625,"left","none"),(77,615,"right","pace")]
    ps = [mk(f"w{i+1:02d}", *w[:2], w[2], "female", w[3]) for i, w in enumerate(women)]
    ps += [mk(f"m{i+1:02d}", *m[:2], m[2], "male", m[3]) for i, m in enumerate(men)]
    ps += [mk("drum", 52, 0, g="female", role="drummer"), mk("sweep", 81, 0, role="sweep")]
    return Roster(ps)

def req(rule=GenderRule(8, 12, 8, 12), boat=Boat(10), candidates=None, locked=(), current=None):
    r = std_roster()
    return PlacementRequest(boat, r, tuple(candidates or [i for i in r.ids if i not in ("drum", "sweep")]), "drum", "sweep", tuple(locked), rule, current)

def test_full_boat_respects_hard_constraints():
    res = solve(req())
    assert res.metrics.seated == 20 and res.rule_satisfied and res.metrics.women == 8 and res.metrics.men == 12
    assert len(res.lineup.seated_ids) == 20 and "drum" not in res.lineup.seated_ids and "sweep" not in res.lineup.seated_ids
    assert res.metrics.total_power == sum(sorted([p.erg_m for p in std_roster().by_id.values() if p.gender.value == "male"])[-12:]) + sum(sorted([p.erg_m for p in std_roster().by_id.values() if p.gender.value == "female"])[-8:])
    assert set(res.proven) == set(STAGES[:-1])      # no 'moves' stage without current
    assert all(res.proven[s] for s in ["seated", "power", "weight", "side", "seat", "powerBalance"]), res.proven
    assert res.metrics.weight_delta <= 1.0 + 1e-9 and res.metrics.side_mismatches == 0

def test_stage_caps_hold():
    res = solve(req())
    for s, ms in res.stage_ms.items():
        assert ms <= DEFAULT_CAPS[s] * 1000 + 400, (s, ms)   # +400ms slack for model build/overhead
    assert res.solve_ms < 8000

def test_is_deterministic():
    a, b = solve(req()), solve(req())
    assert a.lineup == b.lineup and a.metrics == b.metrics

def test_small_boat_and_underfull():
    res = solve(req(rule=None, boat=Boat(5)))
    assert res.metrics.seated == 10 and res.metrics.total_power == 6490   # top-10 men ergs
    few = [f"m{i:02d}" for i in range(1, 8)]
    res2 = solve(req(rule=None, candidates=few))
    assert res2.metrics.seated == 7 and res2.unseated == []

def test_locks_and_exclusions():
    lock = SeatAssignment(7, Side.right, "w10", True)
    res = solve(req(locked=[lock]))
    assert res.lineup.paddler_at(Seat(7, Side.right)) == "w10" and res.rule_satisfied and res.metrics.women == 8

def test_rule_infeasible_is_relaxed():
    cands = [f"w{i:02d}" for i in range(1, 6)] + [f"m{i:02d}" for i in range(1, 13)]
    res = solve(req(candidates=cands))
    assert not res.rule_satisfied and res.metrics.seated == 17

def test_moves_stage_prefers_current():
    base = solve(req()).lineup
    # current = base with two engine seats swapped; optimum set is the same, so moves should steer us back to base
    a, b = Seat(5, Side.left), Seat(6, Side.left)
    swapped = Lineup(base.boat, base.drummer_id, base.sweep_id, tuple(
        SeatAssignment(x.bench, x.side, base.paddler_at(b) if x.seat == a else base.paddler_at(a) if x.seat == b else x.paddler_id) for x in base.assignments))
    res = solve(req(current=swapped))
    assert "moves" in res.proven and res.metrics.moves is not None
    assert res.metrics.lex_key()[:7] <= evaluate(base, std_roster(), swapped).lex_key()[:7]

def test_never_worse_than_greedy_golden(fixtures_dir):
    from paddltir_solver import fixtures as fx
    from paddltir_solver.model import lex_less
    items = fx.load_all(fixtures_dir / "placement")
    assert len(items) >= 5, "placement fixtures missing"
    for f in items:
        g = f.raw.get("expected", {}).get("greedy")
        if not g: continue
        res = solve(f.placement_request())
        # gate only the six stages that PROVE within cap (seated, power, weight, side, seat, powerBalance);
        # trim/moves are heuristic within their 0.5s cap and vary run-to-run, so they are excluded here too.
        greedy = fx.Metrics.from_json(g["metrics"]).lex_key()[:6]
        mine = res.metrics.lex_key()[:6]
        assert not lex_less(greedy, mine, 1e-6), f"{f.name}: MIP {mine} worse than greedy {greedy}"

from paddltir_solver import fixtures as fx
from paddltir_solver.mip import solve


def test_mip_goldens(fixtures_dir):
    for f in fx.load_all(fixtures_dir / "placement"):
        exp = f.raw["expected"]["mip"]
        res = solve(f.placement_request())
        exp_metrics = fx.Metrics.from_json(exp["metrics"])
        # Same optimisation quality (what the product cares about), robust to equal-optimal tie choices:
        # a stage that only proves feasibility (not optimality) can return a different but equally-good
        # lineup between runs, so we compare the lexicographic objective key rather than exact seats.
        # gate only the six stages that PROVE within cap (seated, power, weight, side, seat, powerBalance);
        # trim/moves are heuristic within their 0.5s cap and vary run-to-run, so they are NOT golden-pinned
        assert res.metrics.lex_key()[:6] == exp_metrics.lex_key()[:6], f.name
        assert res.rule_satisfied == exp["ruleSatisfied"], f.name
        # Hard invariants hold regardless of which equally-optimal lineup was chosen.
        ids = [a["paddlerId"] for a in res.lineup.as_json()]
        assert len(ids) == len(set(ids)), f.name
        seats = [(a["bench"], a["side"]) for a in res.lineup.as_json()]
        assert len(seats) == len(set(seats)) and len(seats) <= f.boat.capacity, f.name
        if f.rule and res.rule_satisfied:
            assert f.rule.is_satisfied(res.metrics.women, res.metrics.men), f.name

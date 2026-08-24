import pytest
from paddltir_solver import fixtures as fx
from paddltir_solver.scoring import evaluate

def test_evaluate_fixtures_match_exactly(fixtures_dir):
    items = fx.load_all(fixtures_dir / "evaluate")
    assert len(items) >= 2
    for f in items:
        got = evaluate(f.evaluation_lineup(), f.roster, f.current_lineup())
        exp = f.expected_metrics()
        assert got.approx_equal(exp), f"{f.name}: got {got.to_json()} expected {exp.to_json()}"

def test_greedy_golden_metrics_are_reproducible_from_seats(fixtures_dir):
    """The Swift side stored seats+metrics; our evaluate() must agree on the metrics for those seats."""
    for f in fx.load_all(fixtures_dir / "placement"):
        g = f.raw.get("expected", {}).get("greedy")
        if not g: pytest.skip(f"{f.name} has no expected.greedy yet")
        lineup = f.lineup_from(g["seats"])
        assert evaluate(lineup, f.roster, f.current_lineup()).approx_equal(fx.Metrics.from_json(g["metrics"])), f.name

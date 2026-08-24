from hypothesis import given, settings, strategies as st, HealthCheck
from paddltir_solver.model import Boat, Gender, GenderRule, Paddler, PlacementRequest, Role, Roster, SeatPref, SidePref
from paddltir_solver.mip import solve

paddler = st.builds(lambda i, w, e, s, g, p: Paddler(f"p{i:03d}", f"P{i}", float(w), float(e), SidePref(s), Gender(g), SeatPref(p), Role.paddler),
                    st.integers(0, 999), st.integers(50, 100), st.integers(400, 700),
                    st.sampled_from(["left", "right", "either"]), st.sampled_from(["female", "male"]),
                    st.sampled_from(["stroke", "pace", "engine", "sprint", "none"]))

@settings(max_examples=25, deadline=None, suppress_health_check=[HealthCheck.too_slow])
@given(st.lists(paddler, min_size=3, max_size=24, unique_by=lambda p: p.id), st.sampled_from([5, 10]), st.sampled_from([None, "mixed", "women"]))
def test_invariants(paddlers, benches, rule_kind):
    boat = Boat(benches)
    rule = None if rule_kind is None else (GenderRule(*(4, 6, 4, 6) if benches == 5 else (8, 12, 8, 12)) if rule_kind == "mixed" else GenderRule(max_men=0))
    roster = Roster(paddlers)
    res = solve(PlacementRequest(boat, roster, tuple(roster.ids), None, None, (), rule, None))
    ids = [a.paddler_id for a in res.lineup.assignments]
    assert len(ids) == len(set(ids)) and len(ids) <= boat.capacity
    seats = [(a.bench, a.side) for a in res.lineup.assignments]
    assert len(seats) == len(set(seats))
    if rule is not None and res.rule_satisfied:
        assert rule.is_satisfied(res.metrics.women, res.metrics.men)
    if rule is None:
        assert res.metrics.seated == min(boat.capacity, len(paddlers))

import json
from paddltir_solver.model import (Boat, Section, Paddler, Roster, Seat, Side, SeatAssignment, Lineup,
                                   GenderRule, Metrics, SidePref, Gender, SeatPref, Role)

def test_boat_geometry_and_sections():
    b = Boat(10)
    assert b.capacity == 20 and b.midpoint == 5.5
    assert b.arm(1) == -4.5 and b.arm(10) == 4.5 and b.drummer_arm == -5.5 and b.sweep_arm == 5.5
    assert list(b.benches_in(Section.stroke)) == [1]
    assert list(b.benches_in(Section.pace)) == [2, 3]
    assert list(b.benches_in(Section.engine)) == [4, 5, 6, 7]
    assert list(b.benches_in(Section.sprint)) == [8, 9, 10]
    s = Boat(5)
    assert list(s.benches_in(Section.pace)) == [2] and list(s.benches_in(Section.engine)) == [3] and list(s.benches_in(Section.sprint)) == [4, 5]
    for n in range(4, 13):
        covered = [x for sec in Section for x in Boat(n).benches_in(sec)]
        assert covered == list(range(1, n + 1)), n

def test_paddler_json_roundtrip():
    j = {"id": "p1", "name": "Ana", "weightKg": 60, "ergM": 500, "side": "left", "gender": "female", "seatPref": "stroke", "role": "paddler"}
    p = Paddler.from_json(j)
    assert p.weight_kg == 60.0 and p.side is SidePref.left and p.gender is Gender.female and p.seat_pref is SeatPref.stroke and p.role is Role.paddler
    assert p.to_json() == j | {"weightKg": 60.0, "ergM": 500.0}

def test_lineup_lookups_and_json():
    l = Lineup(Boat(5), "d", "s", (SeatAssignment(1, Side.left, "a"), SeatAssignment(2, Side.right, "b", locked=True)))
    assert l.paddler_at(Seat(1, Side.left)) == "a" and l.seat_of("b") == Seat(2, Side.right) and l.seated_ids == {"a", "b"}
    assert l.as_json() == [{"bench": 1, "side": "left", "paddlerId": "a"}, {"bench": 2, "side": "right", "paddlerId": "b", "locked": True}]
    assert Seat(1, Side.left) < Seat(1, Side.right) < Seat(2, Side.left)

def test_gender_rule():
    r = GenderRule.from_json({"minWomen": 8, "maxWomen": 12})
    assert r.is_satisfied(8, 12) and not r.is_satisfied(7, 13)
    assert GenderRule.from_json({"maxMen": 0}).is_satisfied(10, 0)
    assert GenderRule.from_json(None) is None

def test_metrics_lex_key_and_json():
    m = Metrics(seated=4, total_power=2100, weight_left=60, weight_right=240, power_left=500, power_right=1600,
                side_mismatches=1, seat_mismatches=1, trim_moment=-45, women=2, men=2, moves=None)
    assert m.lex_key() == (-4, -2100, 180, 1, 1, 1100, 45, 0)
    j = m.to_json()
    assert "moves" not in j and j["trimMoment"] == -45
    assert Metrics.from_json(j) == m

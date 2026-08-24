import httpx, pytest
from paddltir_solver.auth import verify_user, AuthError
from paddltir_solver.cache import input_hash
from paddltir_solver.db import HEAT_CONTEXT_SQL, context_from_row
from paddltir_solver.model import Boat, PlacementRequest, Roster, Paddler, SidePref, Gender, SeatPref, Role, Seat, Side

def test_verify_user_ok_and_bad():
    def handler(request: httpx.Request):
        assert request.headers["apikey"] == "anon" and request.url.path == "/auth/v1/user"
        return httpx.Response(200, json={"id": "u1"}) if request.headers["authorization"] == "Bearer good" else httpx.Response(401, json={})
    client = httpx.Client(transport=httpx.MockTransport(handler))
    assert verify_user("good", "https://x.supabase.co", "anon", client) == "u1"
    with pytest.raises(AuthError): verify_user("bad", "https://x.supabase.co", "anon", client)

def test_input_hash_is_stable_and_sensitive():
    p = Paddler("a", "A", 70, 500, SidePref.left, Gender.male, SeatPref.none, Role.paddler)
    r1 = PlacementRequest(Boat(10), Roster([p]), ("a",)); r2 = PlacementRequest(Boat(10), Roster([p]), ("a",))
    r3 = PlacementRequest(Boat(5), Roster([p]), ("a",))
    assert input_hash(r1) == input_hash(r2) and input_hash(r1) != input_hash(r3) and len(input_hash(r1)) == 64

def test_context_from_row_builds_request():
    row = {"clubId": "c", "benches": 10, "rule": {"minWomen": 8, "maxWomen": 12, "minMen": 8, "maxMen": 12},
           "paddlers": [{"id": "a", "name": "A", "weightKg": 70, "ergM": 500, "side": "left", "gender": "male", "seatPref": "none", "role": "paddler"},
                        {"id": "b", "name": "B", "weightKg": 60, "ergM": 450, "side": "right", "gender": "female", "seatPref": "none", "role": "paddler"}],
           "candidates": ["a", "b"], "drummerId": None, "sweepId": None,
           "current": [{"bench": 1, "side": "left", "paddlerId": "a", "locked": True}]}
    ctx = context_from_row(row, extra_locked=[], excluded={"b"})
    assert ctx.club_id == "c" and ctx.request.candidates == ("a",) and ctx.request.rule.min_women == 8
    assert ctx.request.locked[0].paddler_id == "a" and ctx.request.current.paddler_at(Seat(1, Side.left)) == "a"
    assert "heats h" in HEAT_CONTEXT_SQL

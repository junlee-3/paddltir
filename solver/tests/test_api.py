from fastapi.testclient import TestClient
from paddltir_solver import app as appmod
from paddltir_solver.db import HeatContext
from paddltir_solver.model import Boat, PlacementRequest, Roster, Paddler, SidePref, Gender, SeatPref, Role

class FakeConn:  # records cache puts; no DB
    def __init__(self): self.cache = {}

def fake_ctx(heat_id, extra_locked, excluded):
    if heat_id == "missing": return None
    ps = [Paddler(f"p{i}", f"P{i}", 60 + i, 500 + i, SidePref.either, Gender.female if i % 2 else Gender.male, SeatPref.none, Role.paddler) for i in range(12)]
    r = Roster(ps)
    return HeatContext("club1", PlacementRequest(Boat(5), r, tuple(c for c in r.ids if c not in excluded), None, None, tuple(extra_locked), None, None), None, None)

def make_client(user="coach", coach=True):
    app = appmod.app
    app.dependency_overrides[appmod.get_conn] = lambda: FakeConn()
    app.dependency_overrides[appmod.get_user_id] = lambda: user
    appmod._fetch_ctx = fake_ctx
    appmod._is_coach_of = lambda conn, uid, club: coach
    appmod._cache_get = lambda conn, h: conn.cache.get(h)
    appmod._cache_put = lambda conn, h, club, res: conn.cache.__setitem__(h, res)
    return TestClient(app)

def test_health():
    assert make_client().get("/api/health").json()["ok"] is True

def test_optimize_happy_path():
    c = make_client()
    r = c.post("/api/optimize", json={"heatId": "h1", "lockedSeats": [], "excludedPaddlerIds": ["p0"]})
    assert r.status_code == 200, r.text
    j = r.json()
    assert len(j["seats"]) == 10 and "p0" not in {s["paddlerId"] for s in j["seats"]}
    assert j["metrics"]["seated"] == 10 and set(j["proven"]) >= {"seated", "weight"} and j["cached"] is False
    assert j["reserves"] == ["p11"] or len(j["reserves"]) == 1

def test_not_coach_is_403():
    assert make_client(coach=False).post("/api/optimize", json={"heatId": "h1"}).status_code == 403

def test_unknown_heat_is_404():
    assert make_client().post("/api/optimize", json={"heatId": "missing"}).status_code == 404

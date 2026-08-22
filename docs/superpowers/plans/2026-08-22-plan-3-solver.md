# Plan 3 — Solver Service Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A Python 3.12 package `paddltir_solver` implementing scoring parity with `PaddltirCore`, the lexicographic HiGHS MIP (stages 0, 0b, 1–6) with honest `proven` reporting and per-stage time caps, a FastAPI service `POST /api/optimize` that reads one heat's context from Supabase, verifies the coach's JWT, caches results, and deploys to Vercel as a Service.

**Architecture:** Pure functions over frozen dataclasses (`model.py`, `scoring.py`, `mip.py`) with no I/O; `fixtures.py` loads the shared `/fixtures` JSON; `db.py`/`auth.py`/`cache.py` are thin I/O adapters; `app.py` wires FastAPI with dependency injection so tests never touch the network.

**Tech Stack:** Python 3.12, `uv`, `highspy>=1.8`, `fastapi`, `pydantic>=2`, `psycopg[binary]>=3.2`, `httpx`, `pytest`, `hypothesis`.

**Spec:** `docs/superpowers/specs/2026-08-22-paddltir-design.md` §6 (MIP), §7 (hosting), §8 (testing); roadmap shared contracts; `fixtures/README.md` (Plan 1) for the JSON schema.

## Global Constraints
- Lexicographic priority: `(−seated, −totalPower, weightDelta, sideMismatches, seatMismatches, powerDelta, |trimMoment|, moves)`; stage names `["seated","power","weight","side","seat","powerBalance","trim","moves"]`.
- Time caps: stages seated/power/weight/side/seat/powerBalance **1.0 s** each, trim **0.5 s**, moves **0.5 s**. `proven[stage]` is `True` only when HiGHS reports `kOptimal` for that stage.
- `≤ 1` occupancy; `n_benches` a parameter; gender rule hard when feasible, else fully relaxed with `ruleSatisfied=False`; drummer/sweep weights from the lineup feed the fixed trim term; sweeps never benched; the heat's drummer/sweep never benched.
- JSON keys are camelCase everywhere (match `fixtures/README.md`).
- `mip_rel_gap=0`, `mip_abs_gap=1e-6`, `threads=1`, `random_seed=0` for determinism and honest optimality.
- No secrets in git. Env: `SUPABASE_URL`, `SUPABASE_ANON_KEY`, `DATABASE_URL` (pooler, transaction mode).
- Run tests with `cd solver && uv run pytest -q`.

---

## File structure
```
solver/
  pyproject.toml            project + deps + [tool.vercel] entrypoint + pytest config
  .python-version           3.12
  main.py                   `from paddltir_solver.app import app`
  paddltir_solver/
    __init__.py             SOLVER_VERSION = "1"
    model.py                Side/Gender/... enums, Boat, Paddler, Roster, Seat, SeatAssignment, Lineup, GenderRule, PlacementRequest, Metrics, lex_key
    scoring.py              evaluate(lineup, roster, reference=None) -> Metrics
    mip.py                  solve(request, caps=DEFAULT_CAPS) -> SolveResult
    fixtures.py             load_fixture/load_all + CLI `update`/`check`
    auth.py                 verify_coach(token, heat_club_id) via Supabase /auth/v1/user + profiles
    db.py                   fetch_heat_context(heat_id) -> HeatContext
    cache.py                input_hash(request) / get / put
    app.py                  FastAPI app: GET /api/health, POST /api/optimize
  tests/
    conftest.py  test_model.py  test_scoring_fixtures.py  test_mip.py  test_mip_fixtures.py  test_properties.py  test_api.py
vercel.json                 (repo root) services: solver (+ web later)
```

---

### Task 1: Project skeleton and model

**Files:**
- Create: `solver/pyproject.toml`, `solver/.python-version`, `solver/paddltir_solver/__init__.py`, `solver/paddltir_solver/model.py`, `solver/tests/test_model.py`, `solver/tests/conftest.py`

**Interfaces:**
- Produces (model.py): `Side`, `SidePref`, `Gender`, `SeatPref`, `Role`, `Section` (`str` Enums, lowercase values); `Boat(benches)` with `.capacity`, `.midpoint`, `.arm(bench)`, `.drummer_arm`, `.sweep_arm`, `.benches_in(section) -> range`, `.section_of(bench)`, `.all_seats`; `Paddler` frozen dataclass (`id, name, weight_kg, erg_m, side, gender, seat_pref, role`) + `from_json/to_json`; `Roster(paddlers)` with `__getitem__`, `.get`, `.ids`; `Seat(bench, side)` (orderable); `SeatAssignment(bench, side, paddler_id, locked=False)` + json; `Lineup(boat, drummer_id, sweep_id, assignments: tuple)` with `.paddler_at`, `.seat_of`, `.seated_ids`, `.as_json()`; `GenderRule(min_women, max_women, min_men, max_men)` + `.is_satisfied(w, m)` + json; `PlacementRequest(boat, roster, candidates, drummer_id, sweep_id, locked, rule, current)`; `Metrics` dataclass + `lex_key()` + `to_json()/from_json()` + `approx_equal`.

- [ ] **Step 1: Create the project**

```bash
mkdir -p solver/paddltir_solver solver/tests && cd solver && echo "3.12" > .python-version
```
```toml
# solver/pyproject.toml
[project]
name = "paddltir-solver"
version = "0.1.0"
description = "Paddltir lexicographic lineup optimiser (HiGHS) and API"
requires-python = ">=3.12"
dependencies = [
  "highspy>=1.8.0",
  "fastapi>=0.115",
  "pydantic>=2.8",
  "psycopg[binary]>=3.2",
  "httpx>=0.27",
]

[dependency-groups]
dev = ["pytest>=8", "hypothesis>=6.100", "pytest-timeout>=2.3"]

[tool.vercel]
entrypoint = "main:app"

[tool.pytest.ini_options]
testpaths = ["tests"]
timeout = 120

[build-system]
requires = ["hatchling"]
build-backend = "hatchling.build"

[tool.hatch.build.targets.wheel]
packages = ["paddltir_solver"]
```
Run: `cd solver && uv sync && uv run python -c "import highspy, fastapi; h=highspy.Highs(); print(highspy.__version__ if hasattr(highspy,'__version__') else 'ok', [m for m in dir(h) if m.startswith('add')])"`
Expected: prints the list including `addBinary`, `addVariable`, `addConstr`, `addConstrs`. If `addBinary` is missing, use `h.addVariable(0, 1, type=highspy.HighsVarType.kInteger)` wherever this plan says `addBinary()`.

- [ ] **Step 2: Write failing model tests**

```python
# solver/tests/conftest.py
from pathlib import Path
import pytest

FIXTURES = Path(__file__).resolve().parents[2] / "fixtures"

@pytest.fixture(scope="session")
def fixtures_dir() -> Path:
    assert FIXTURES.is_dir(), f"fixtures dir missing at {FIXTURES}"
    return FIXTURES
```
```python
# solver/tests/test_model.py
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
```

- [ ] **Step 3: Run to verify failure** — `uv run pytest -q tests/test_model.py` → `ModuleNotFoundError: paddltir_solver.model`.

- [ ] **Step 4: Implement model.py**

```python
# solver/paddltir_solver/__init__.py
SOLVER_VERSION = "1"
```
```python
# solver/paddltir_solver/model.py
"""Domain model shared with PaddltirCore (Swift). Keep field names/JSON keys identical to fixtures/README.md."""
from __future__ import annotations
from dataclasses import dataclass, field
from enum import Enum
from typing import Iterable, Optional

class Side(str, Enum):
    left = "left"; right = "right"
class SidePref(str, Enum):
    left = "left"; right = "right"; either = "either"
    def matches(self, side: Side) -> bool:
        return self is SidePref.either or self.value == side.value
class Gender(str, Enum):
    female = "female"; male = "male"
class Section(str, Enum):
    stroke = "stroke"; pace = "pace"; engine = "engine"; sprint = "sprint"
class SeatPref(str, Enum):
    stroke = "stroke"; pace = "pace"; engine = "engine"; sprint = "sprint"; none = "none"
    @property
    def section(self) -> Optional[Section]:
        return None if self is SeatPref.none else Section(self.value)
class Role(str, Enum):
    paddler = "paddler"; drummer = "drummer"; sweep = "sweep"
    @property
    def may_paddle(self) -> bool:
        return self is not Role.sweep

@dataclass(frozen=True)
class Boat:
    benches: int
    @property
    def capacity(self) -> int: return self.benches * 2
    @property
    def midpoint(self) -> float: return (self.benches + 1) / 2
    def arm(self, bench: int) -> float: return bench - self.midpoint
    @property
    def drummer_arm(self) -> float: return -self.midpoint
    @property
    def sweep_arm(self) -> float: return self.midpoint
    def benches_in(self, section: Section) -> range:
        n = self.benches
        if n < 4:
            return {Section.stroke: range(1, 2), Section.pace: range(2, 3) if n >= 2 else range(1, 2),
                    Section.engine: range(3, 4) if n >= 3 else (range(2, 3) if n >= 2 else range(1, 2)),
                    Section.sprint: range(n, n + 1)}[section]
        sprint_count = max(1, round(n * 0.3)); pace_count = max(1, round(n * 0.2))
        pace_end = 1 + pace_count; sprint_start = n - sprint_count + 1
        return {Section.stroke: range(1, 2), Section.pace: range(2, pace_end + 1),
                Section.engine: range(pace_end + 1, sprint_start), Section.sprint: range(sprint_start, n + 1)}[section]
    def section_of(self, bench: int) -> Section:
        for s in Section:
            if bench in self.benches_in(s): return s
        return Section.engine
    @property
    def all_seats(self) -> list["Seat"]:
        return [Seat(b, s) for b in range(1, self.benches + 1) for s in (Side.left, Side.right)]

@dataclass(frozen=True, order=True)
class Seat:
    bench: int
    side: Side
    def __lt__(self, o: "Seat") -> bool:  # left < right within a bench
        return (self.bench, self.side is Side.right) < (o.bench, o.side is Side.right)

@dataclass(frozen=True)
class Paddler:
    id: str; name: str; weight_kg: float; erg_m: float
    side: SidePref; gender: Gender; seat_pref: SeatPref; role: Role
    @staticmethod
    def from_json(j: dict) -> "Paddler":
        return Paddler(j["id"], j["name"], float(j["weightKg"]), float(j.get("ergM", 0)), SidePref(j["side"]),
                       Gender(j["gender"]), SeatPref(j.get("seatPref", "none")), Role(j.get("role", "paddler")))
    def to_json(self) -> dict:
        return {"id": self.id, "name": self.name, "weightKg": self.weight_kg, "ergM": self.erg_m, "side": self.side.value,
                "gender": self.gender.value, "seatPref": self.seat_pref.value, "role": self.role.value}

class Roster:
    def __init__(self, paddlers: Iterable[Paddler]):
        self.by_id: dict[str, Paddler] = {p.id: p for p in paddlers}
    def __getitem__(self, pid: str) -> Paddler: return self.by_id[pid]
    def get(self, pid: str) -> Optional[Paddler]: return self.by_id.get(pid)
    def __contains__(self, pid: str) -> bool: return pid in self.by_id
    @property
    def ids(self) -> list[str]: return sorted(self.by_id)
    def __len__(self) -> int: return len(self.by_id)

@dataclass(frozen=True)
class SeatAssignment:
    bench: int; side: Side; paddler_id: str; locked: bool = False
    @property
    def seat(self) -> Seat: return Seat(self.bench, self.side)
    @staticmethod
    def from_json(j: dict) -> "SeatAssignment":
        return SeatAssignment(int(j["bench"]), Side(j["side"]), j["paddlerId"], bool(j.get("locked", False)))
    def to_json(self) -> dict:
        d = {"bench": self.bench, "side": self.side.value, "paddlerId": self.paddler_id}
        if self.locked: d["locked"] = True
        return d

@dataclass(frozen=True)
class Lineup:
    boat: Boat
    drummer_id: Optional[str] = None
    sweep_id: Optional[str] = None
    assignments: tuple[SeatAssignment, ...] = ()
    def __post_init__(self):
        object.__setattr__(self, "assignments", tuple(sorted(self.assignments, key=lambda a: (a.bench, a.side is Side.right))))
    def paddler_at(self, seat: Seat) -> Optional[str]:
        return next((a.paddler_id for a in self.assignments if a.seat == seat), None)
    def seat_of(self, pid: str) -> Optional[Seat]:
        return next((a.seat for a in self.assignments if a.paddler_id == pid), None)
    @property
    def seated_ids(self) -> set[str]: return {a.paddler_id for a in self.assignments}
    def as_json(self) -> list[dict]: return [a.to_json() for a in self.assignments]

@dataclass(frozen=True)
class GenderRule:
    min_women: Optional[int] = None; max_women: Optional[int] = None
    min_men: Optional[int] = None; max_men: Optional[int] = None
    def is_satisfied(self, women: int, men: int) -> bool:
        return ((self.min_women is None or women >= self.min_women) and (self.max_women is None or women <= self.max_women)
                and (self.min_men is None or men >= self.min_men) and (self.max_men is None or men <= self.max_men))
    @staticmethod
    def from_json(j: Optional[dict]) -> Optional["GenderRule"]:
        if j is None: return None
        return GenderRule(j.get("minWomen"), j.get("maxWomen"), j.get("minMen"), j.get("maxMen"))
    def to_json(self) -> dict:
        return {k: v for k, v in {"minWomen": self.min_women, "maxWomen": self.max_women, "minMen": self.min_men, "maxMen": self.max_men}.items() if v is not None}

@dataclass(frozen=True)
class PlacementRequest:
    boat: Boat
    roster: Roster
    candidates: tuple[str, ...]
    drummer_id: Optional[str] = None
    sweep_id: Optional[str] = None
    locked: tuple[SeatAssignment, ...] = ()
    rule: Optional[GenderRule] = None
    current: Optional[Lineup] = None
    def canonical_json(self) -> dict:
        """Stable JSON used for cache hashing."""
        return {"boat": {"benches": self.boat.benches}, "rule": self.rule.to_json() if self.rule else None,
                "paddlers": [self.roster[i].to_json() for i in self.roster.ids], "candidates": sorted(self.candidates),
                "drummerId": self.drummer_id, "sweepId": self.sweep_id, "locked": [a.to_json() for a in sorted(self.locked, key=lambda a: (a.bench, a.side.value))],
                "current": self.current.as_json() if self.current else None}

@dataclass(frozen=True)
class Metrics:
    seated: int; total_power: float; weight_left: float; weight_right: float; power_left: float; power_right: float
    side_mismatches: int; seat_mismatches: int; trim_moment: float; women: int; men: int; moves: Optional[int] = None
    @property
    def weight_delta(self) -> float: return abs(self.weight_left - self.weight_right)
    @property
    def power_delta(self) -> float: return abs(self.power_left - self.power_right)
    def lex_key(self) -> tuple:
        return (-self.seated, -self.total_power, self.weight_delta, self.side_mismatches, self.seat_mismatches,
                self.power_delta, abs(self.trim_moment), self.moves or 0)
    def to_json(self) -> dict:
        d = {"seated": self.seated, "totalPower": self.total_power, "weightLeft": self.weight_left, "weightRight": self.weight_right,
             "powerLeft": self.power_left, "powerRight": self.power_right, "sideMismatches": self.side_mismatches,
             "seatMismatches": self.seat_mismatches, "trimMoment": self.trim_moment, "women": self.women, "men": self.men}
        if self.moves is not None: d["moves"] = self.moves
        return d
    @staticmethod
    def from_json(j: dict) -> "Metrics":
        return Metrics(int(j["seated"]), float(j["totalPower"]), float(j["weightLeft"]), float(j["weightRight"]), float(j["powerLeft"]),
                       float(j["powerRight"]), int(j["sideMismatches"]), int(j["seatMismatches"]), float(j["trimMoment"]),
                       int(j["women"]), int(j["men"]), j.get("moves"))
    def approx_equal(self, o: "Metrics", tol: float = 1e-6) -> bool:
        return (self.seated == o.seated and self.side_mismatches == o.side_mismatches and self.seat_mismatches == o.seat_mismatches
                and self.women == o.women and self.men == o.men and self.moves == o.moves
                and all(abs(a - b) <= tol for a, b in [(self.total_power, o.total_power), (self.weight_left, o.weight_left),
                    (self.weight_right, o.weight_right), (self.power_left, o.power_left), (self.power_right, o.power_right), (self.trim_moment, o.trim_moment)]))

STAGES = ["seated", "power", "weight", "side", "seat", "powerBalance", "trim", "moves"]

def lex_less(a: tuple, b: tuple, tol: float = 1e-9) -> bool:
    for x, y in zip(a, b):
        if abs(x - y) <= tol: continue
        return x < y
    return False
```

- [ ] **Step 5: Run** — `uv run pytest -q tests/test_model.py` → 5 passed.
- [ ] **Step 6: Commit** — `git add solver && git commit -m "feat(solver): project skeleton and domain model"`

---

### Task 2: Scoring parity with the Swift fixtures

**Files:**
- Create: `solver/paddltir_solver/scoring.py`, `solver/paddltir_solver/fixtures.py`, `solver/tests/test_scoring_fixtures.py`

**Interfaces:**
- Produces: `scoring.evaluate(lineup: Lineup, roster: Roster, reference: Lineup | None = None) -> Metrics`; `fixtures.Fixture` dataclass (`name, boat, rule, roster, drummer_id, sweep_id, candidates, locked, current, lineup, expected, raw, path`) with `.placement_request()`, `.evaluation_lineup()`; `fixtures.load(path)`, `fixtures.load_all(dir)`.

- [ ] **Step 1: Write failing tests**

```python
# solver/tests/test_scoring_fixtures.py
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
```

- [ ] **Step 2: Run** → `ModuleNotFoundError`.
- [ ] **Step 3: Implement scoring.py and fixtures.py**

```python
# solver/paddltir_solver/scoring.py
from .model import Lineup, Roster, Metrics, Side

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
```
```python
# solver/paddltir_solver/fixtures.py
"""Golden fixture loader + CLI. `python -m paddltir_solver.fixtures update|check <dir>` writes/checks expected.mip."""
from __future__ import annotations
import json, sys
from dataclasses import dataclass
from pathlib import Path
from typing import Optional
from .model import Boat, GenderRule, Lineup, Metrics, Paddler, PlacementRequest, Roster, SeatAssignment

@dataclass
class Fixture:
    path: Path
    raw: dict
    @property
    def name(self) -> str: return self.raw["name"]
    @property
    def boat(self) -> Boat: return Boat(int(self.raw["boat"]["benches"]))
    @property
    def rule(self) -> Optional[GenderRule]: return GenderRule.from_json(self.raw.get("rule"))
    @property
    def roster(self) -> Roster: return Roster(Paddler.from_json(p) for p in self.raw["paddlers"])
    @property
    def drummer_id(self): return self.raw.get("drummerId")
    @property
    def sweep_id(self): return self.raw.get("sweepId")
    def candidates(self) -> tuple[str, ...]:
        if self.raw.get("candidates") is not None: return tuple(self.raw["candidates"])
        return tuple(p.id for p in self.roster.by_id.values() if p.role.may_paddle and p.id not in (self.drummer_id, self.sweep_id))
    def lineup_from(self, seats: list[dict]) -> Lineup:
        return Lineup(self.boat, self.drummer_id, self.sweep_id, tuple(SeatAssignment.from_json(s) for s in seats))
    def evaluation_lineup(self) -> Lineup: return self.lineup_from(self.raw.get("lineup") or [])
    def current_lineup(self) -> Optional[Lineup]:
        return self.lineup_from(self.raw["current"]) if self.raw.get("current") is not None else None
    def expected_metrics(self) -> Metrics: return Metrics.from_json(self.raw["expected"]["metrics"])
    def placement_request(self) -> PlacementRequest:
        locked = tuple(SeatAssignment.from_json(s) for s in (self.raw.get("locked") or []))
        return PlacementRequest(self.boat, self.roster, self.candidates(), self.drummer_id, self.sweep_id, locked, self.rule, self.current_lineup())
    def write(self) -> None:
        self.path.write_text(json.dumps(self.raw, indent=2, sort_keys=True) + "\n")

def load(path: Path) -> Fixture: return Fixture(Path(path), json.loads(Path(path).read_text()))
def load_all(d: Path) -> list[Fixture]: return [load(p) for p in sorted(Path(d).glob("*.json"))]

def _cli(argv: list[str]) -> int:
    from .mip import solve  # local import: mip depends on model only
    if len(argv) < 2 or argv[0] not in ("update", "check"):
        print("usage: python -m paddltir_solver.fixtures update|check <dir-or-file>"); return 2
    target = Path(argv[1]); files = sorted(target.glob("*.json")) if target.is_dir() else [target]
    failures = 0
    for p in files:
        f = load(p); r = solve(f.placement_request())
        outcome = {"seats": r.lineup.as_json(), "metrics": r.metrics.to_json(), "ruleSatisfied": r.rule_satisfied, "proven": r.proven}
        if argv[0] == "update":
            f.raw.setdefault("expected", {})["mip"] = outcome; f.write()
            m = r.metrics
            print(f"{f.name}: seated {m.seated} power {m.total_power:.0f} Δw {m.weight_delta:.1f} side {m.side_mismatches} seat {m.seat_mismatches} Δp {m.power_delta:.0f} trim {m.trim_moment:.1f} rule {r.rule_satisfied} {r.solve_ms} ms proven {r.proven}")
        else:
            ok = f.raw.get("expected", {}).get("mip", {}).get("seats") == outcome["seats"]
            print(("ok " if ok else "MISMATCH ") + f.name); failures += 0 if ok else 1
    return 1 if failures else 0

if __name__ == "__main__":
    sys.exit(_cli(sys.argv[1:]))
```

- [ ] **Step 4: Run** — `uv run pytest -q tests/test_scoring_fixtures.py` → passed (2nd test may skip if Plan 1 hasn't generated greedy outputs yet; once Plan 1 is done it must pass — this is the cross-language parity gate).
- [ ] **Step 5: Commit** — `git add solver && git commit -m "feat(solver): scoring parity and fixture loader"`

---

### Task 3: The lexicographic MIP

**Files:**
- Create: `solver/paddltir_solver/mip.py`, `solver/tests/test_mip.py`

**Interfaces:**
- Produces: `DEFAULT_CAPS: dict[str, float]`; `SolveResult(lineup, metrics, proven: dict[str,bool], rule_satisfied, solve_ms: int, stage_ms: dict[str,int], unseated: list[str])`; `solve(request: PlacementRequest, caps: dict[str,float] = DEFAULT_CAPS) -> SolveResult`.

- [ ] **Step 1: Write failing tests**

```python
# solver/tests/test_mip.py
import time
from paddltir_solver.model import Boat, GenderRule, Lineup, Paddler, PlacementRequest, Roster, Seat, SeatAssignment, Side, STAGES
from paddltir_solver.mip import solve, DEFAULT_CAPS
from paddltir_solver.scoring import evaluate

def mk(i, w, e, side="either", g="male", pref="none", role="paddler"):
    return Paddler(i, i.upper(), w, e, __import__("paddltir_solver.model", fromlist=["SidePref"]).SidePref(side),
                   __import__("paddltir_solver.model", fromlist=["Gender"]).Gender(g),
                   __import__("paddltir_solver.model", fromlist=["SeatPref"]).SeatPref(pref),
                   __import__("paddltir_solver.model", fromlist=["Role"]).Role(role))

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
    for f in fx.load_all(fixtures_dir / "placement"):
        g = f.raw.get("expected", {}).get("greedy")
        if not g: continue
        res = solve(f.placement_request())
        greedy = fx.Metrics.from_json(g["metrics"]).lex_key()[:7]
        mine = res.metrics.lex_key()[:7]
        assert not lex_less(greedy, mine, 1e-6), f"{f.name}: MIP {mine} worse than greedy {greedy}"
```

- [ ] **Step 2: Run** → `ModuleNotFoundError: paddltir_solver.mip`.

- [ ] **Step 3: Implement mip.py**

```python
# solver/paddltir_solver/mip.py
"""Lexicographic MIP with HiGHS. Stages: seated↑, power↑, weight↓, side↓, seat↓, powerBalance↓, trim↓, moves↓.
Each stage locks its optimum (± eps) as a constraint before the next objective is solved."""
from __future__ import annotations
import time
from dataclasses import dataclass
import highspy
from .model import (Boat, GenderRule, Lineup, Metrics, PlacementRequest, Roster, Seat, SeatAssignment, Side, STAGES)
from .scoring import evaluate

DEFAULT_CAPS: dict[str, float] = {"seated": 1.0, "power": 1.0, "weight": 1.0, "side": 1.0, "seat": 1.0, "powerBalance": 1.0, "trim": 0.5, "moves": 0.5}
EPS = 1e-6

@dataclass
class SolveResult:
    lineup: Lineup
    metrics: Metrics
    proven: dict[str, bool]
    rule_satisfied: bool
    solve_ms: int
    stage_ms: dict[str, int]
    unseated: list[str]

def _eligible(req: PlacementRequest) -> list[str]:
    fixed = {req.drummer_id, req.sweep_id}
    out, seen = [], set()
    for cid in req.candidates:
        p = req.roster.get(cid)
        if p is None or cid in fixed or cid in seen or not p.role.may_paddle: continue
        seen.add(cid); out.append(cid)
    for a in req.locked:                      # locked paddlers are always candidates
        if a.paddler_id not in seen and a.paddler_id in req.roster: seen.add(a.paddler_id); out.append(a.paddler_id)
    return sorted(out)                        # stable order → deterministic model

class _Model:
    def __init__(self, req: PlacementRequest, rule: GenderRule | None):
        self.req, self.rule, self.boat, self.roster = req, rule, req.boat, req.roster
        self.cands = _eligible(req)
        self.seats = self.boat.all_seats
        h = highspy.Highs(); h.silent()
        h.setOptionValue("mip_rel_gap", 0.0); h.setOptionValue("mip_abs_gap", EPS)
        h.setOptionValue("threads", 1); h.setOptionValue("random_seed", 0)
        self.h = h
        self.x = {(a, s.bench, s.side): h.addBinary() for a in self.cands for s in self.seats}
        # ≤ 1 per seat, ≤ 1 per paddler
        for s in self.seats:
            h.addConstr(h.qsum([self.x[a, s.bench, s.side] for a in self.cands]) <= 1)
        for a in self.cands:
            h.addConstr(h.qsum([self.x[a, s.bench, s.side] for s in self.seats]) <= 1)
        # locks
        for l in req.locked:
            if l.paddler_id in self.cands:
                h.addConstr(self.x[l.paddler_id, l.bench, l.side] == 1)
        # gender rule (on benched paddlers)
        if rule is not None:
            w_expr = h.qsum([self.x[a, s.bench, s.side] for a in self.cands for s in self.seats if self.roster[a].gender.value == "female"])
            m_expr = h.qsum([self.x[a, s.bench, s.side] for a in self.cands for s in self.seats if self.roster[a].gender.value == "male"])
            if rule.min_women is not None: h.addConstr(w_expr >= rule.min_women)
            if rule.max_women is not None: h.addConstr(w_expr <= rule.max_women)
            if rule.min_men is not None: h.addConstr(m_expr >= rule.min_men)
            if rule.max_men is not None: h.addConstr(m_expr <= rule.max_men)
        # objective expressions
        R = self.roster
        self.seated_expr = h.qsum(list(self.x.values()))
        self.power_expr = h.qsum([R[a].erg_m * v for (a, _, _), v in self.x.items()])
        wl = h.qsum([R[a].weight_kg * v for (a, _, sd), v in self.x.items() if sd is Side.left])
        wr = h.qsum([R[a].weight_kg * v for (a, _, sd), v in self.x.items() if sd is Side.right])
        pl = h.qsum([R[a].erg_m * v for (a, _, sd), v in self.x.items() if sd is Side.left])
        pr = h.qsum([R[a].erg_m * v for (a, _, sd), v in self.x.items() if sd is Side.right])
        self.dW = h.addVariable(lb=0); h.addConstr(self.dW >= wl - wr); h.addConstr(self.dW >= wr - wl)
        self.dP = h.addVariable(lb=0); h.addConstr(self.dP >= pl - pr); h.addConstr(self.dP >= pr - pl)
        self.side_expr = h.qsum([v for (a, _, sd), v in self.x.items() if not R[a].side.matches(sd)])
        self.seat_expr = h.qsum([v for (a, b, _), v in self.x.items() if (sec := R[a].seat_pref.section) is not None and b not in self.boat.benches_in(sec)])
        fixed = 0.0
        if req.drummer_id and (d := R.get(req.drummer_id)): fixed += d.weight_kg * self.boat.drummer_arm
        if req.sweep_id and (s := R.get(req.sweep_id)): fixed += s.weight_kg * self.boat.sweep_arm
        trim = h.qsum([R[a].weight_kg * self.boat.arm(b) * v for (a, b, _), v in self.x.items()]) + fixed
        self.dT = h.addVariable(lb=0); h.addConstr(self.dT >= trim); h.addConstr(self.dT >= -trim)
        self.moves_expr = None
        if req.current is not None:
            kept = [self.x[a.paddler_id, a.bench, a.side] for a in req.current.assignments if (a.paddler_id, a.bench, a.side) in self.x]
            self.moves_expr = len(req.current.assignments) - h.qsum(kept) if kept else None

    def stages(self):
        yield "seated", self.seated_expr, "max"
        yield "power", self.power_expr, "max"
        yield "weight", self.dW, "min"
        yield "side", self.side_expr, "min"
        yield "seat", self.seat_expr, "min"
        yield "powerBalance", self.dP, "min"
        yield "trim", self.dT, "min"
        if self.moves_expr is not None: yield "moves", self.moves_expr, "min"

    def run(self, caps: dict[str, float]) -> tuple[Lineup | None, dict[str, bool], dict[str, int], bool]:
        h = self.h
        proven, stage_ms, have_solution, last_sol = {}, {}, False, None
        for name, expr, sense in self.stages():
            h.setOptionValue("time_limit", caps[name])
            t0 = time.perf_counter()
            if last_sol is not None: h.setSolution(last_sol)            # warm start from previous stage
            if sense == "max": h.maximize(expr)
            else: h.minimize(expr)
            stage_ms[name] = int((time.perf_counter() - t0) * 1000)
            status = h.getModelStatus()
            feasible = status == highspy.HighsModelStatus.kOptimal or (
                status in (highspy.HighsModelStatus.kTimeLimit, highspy.HighsModelStatus.kInterrupt)
                and h.getInfo().primal_solution_status == 2)           # 2 == kSolutionStatusFeasible
            if not feasible:
                if name == "seated": return None, proven, stage_ms, False   # infeasible model (rule)
                proven[name] = False; break                                  # keep previous stage's solution
            have_solution = True
            proven[name] = status == highspy.HighsModelStatus.kOptimal
            best = h.getObjectiveValue()
            last_sol = h.getSolution()
            if sense == "max": h.addConstr(expr >= best - EPS)
            else: h.addConstr(expr <= best + EPS)
        if not have_solution: return None, proven, stage_ms, False
        return self._lineup_from(last_sol), proven, stage_ms, True

    def _lineup_from(self, sol) -> Lineup:
        vals = sol.col_value
        assigns = []
        for (a, b, sd), var in self.x.items():
            if vals[var.index] > 0.5:
                locked = any(l.paddler_id == a and l.bench == b and l.side is sd for l in self.req.locked)
                assigns.append(SeatAssignment(b, sd, a, locked))
        return Lineup(self.boat, self.req.drummer_id, self.req.sweep_id, tuple(assigns))

def solve(req: PlacementRequest, caps: dict[str, float] = DEFAULT_CAPS) -> SolveResult:
    t0 = time.perf_counter()
    rule_satisfied = True
    lineup, proven, stage_ms, ok = _Model(req, req.rule).run(caps)
    if not ok and req.rule is not None:
        rule_satisfied = False
        lineup, proven, stage_ms, ok = _Model(req, None).run(caps)
    if not ok or lineup is None:   # only possible if even the empty lineup is infeasible (contradictory locks)
        lineup = Lineup(req.boat, req.drummer_id, req.sweep_id, tuple(req.locked)); proven = {}
    metrics = evaluate(lineup, req.roster, req.current)
    unseated = [c for c in _eligible(req) if c not in lineup.seated_ids]
    unseated.sort(key=lambda c: (-req.roster[c].erg_m, -req.roster[c].weight_kg, c))
    return SolveResult(lineup, metrics, proven, rule_satisfied, int((time.perf_counter() - t0) * 1000), stage_ms, unseated)
```
Notes for the implementer:
- `h.qsum` exists in highspy ≥1.8; if not, replace with Python `sum(...)` (slower but fine at 440 vars).
- `highs_var.index` is the column index; if the attribute is named differently in the installed version (`.index` vs `.idx`), check `dir(next(iter(self.x.values())))` and adapt once.
- `getInfo().primal_solution_status`: 0 none, 1 infeasible, 2 feasible.
- If `h.setSolution(last_sol)` raises because the model changed shape, the warm start is optional — wrap in `try/except` and log once; do not silently swallow forever: record `warm_start_ok` in the result for the benchmark.

- [ ] **Step 4: Run** — `uv run pytest -q tests/test_mip.py -x` → all pass. Then run the benchmark and record per-stage times in PROGRESS.md:
`uv run python -c "from tests.test_mip import req; from paddltir_solver.mip import solve; r=solve(req()); print(r.stage_ms, r.proven, r.solve_ms)"`
Expected: stages ≤ caps; trim likely `False` (unproven) — that is honest, not a failure.
- [ ] **Step 5: Commit** — `git add solver && git commit -m "feat(solver): lexicographic HiGHS MIP with stage caps, gender rule, locks, tie-break"`

---

### Task 4: Golden MIP outputs + property tests

**Files:**
- Modify: `fixtures/placement/*.json` (adds `expected.mip`)
- Create: `solver/tests/test_mip_fixtures.py`, `solver/tests/test_properties.py`

- [ ] **Step 1: Generate MIP goldens and review** — `cd solver && uv run python -m paddltir_solver.fixtures update ../fixtures/placement`. Read every printed line: seated/rule as expected per fixture (std-mixed-22: 20 / true; small-open-12: 10; std-women-16: 16; std-locked-current: 20 with locks honoured; std-rule-infeasible: 17 / false).
- [ ] **Step 2: Write the golden + property tests**

```python
# solver/tests/test_mip_fixtures.py
from paddltir_solver import fixtures as fx
from paddltir_solver.mip import solve

def test_mip_goldens(fixtures_dir):
    for f in fx.load_all(fixtures_dir / "placement"):
        exp = f.raw["expected"]["mip"]
        res = solve(f.placement_request())
        assert res.lineup.as_json() == exp["seats"], f.name
        assert res.metrics.approx_equal(fx.Metrics.from_json(exp["metrics"])), f.name
        assert res.rule_satisfied == exp["ruleSatisfied"], f.name
```
```python
# solver/tests/test_properties.py
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
```

- [ ] **Step 3: Run full suite** — `uv run pytest -q` → all pass (property test may take ~1–2 min; keep `max_examples=25`).
- [ ] **Step 4: Commit** — `git add solver fixtures && git commit -m "test(solver): MIP goldens and property tests"`

---

### Task 5: Service adapters — auth, db, cache

**Files:**
- Create: `solver/paddltir_solver/auth.py`, `solver/paddltir_solver/db.py`, `solver/paddltir_solver/cache.py`, `solver/tests/test_adapters.py`

**Interfaces:**
- `auth.verify_user(token: str, supabase_url: str, anon_key: str, client: httpx.Client | None = None) -> str` (user id; raises `AuthError`).
- `db.HeatContext(club_id, request: PlacementRequest, drummer_id, sweep_id)`; `db.fetch_heat_context(conn, heat_id, extra_locked: list[SeatAssignment], excluded: set[str]) -> HeatContext`; `db.is_coach_of(conn, user_id, club_id) -> bool`; `db.connect(database_url) -> psycopg.Connection`.
- `cache.input_hash(request: PlacementRequest) -> str`; `cache.get(conn, h) -> dict | None`; `cache.put(conn, h, club_id, result: dict)`.

- [ ] **Step 1: Write failing tests (pure parts only; DB parts are exercised in Task 6 against local Supabase)**

```python
# solver/tests/test_adapters.py
import httpx, pytest
from paddltir_solver.auth import verify_user, AuthError
from paddltir_solver.cache import input_hash
from paddltir_solver.db import HEAT_CONTEXT_SQL, context_from_row
from paddltir_solver.model import Boat, PlacementRequest, Roster, Paddler, SidePref, Gender, SeatPref, Role

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
    assert ctx.request.locked[0].paddler_id == "a" and ctx.request.current.paddler_at(__import__("paddltir_solver.model", fromlist=["Seat"]).Seat(1, __import__("paddltir_solver.model", fromlist=["Side"]).Side.left)) == "a"
    assert "heats h" in HEAT_CONTEXT_SQL
```

- [ ] **Step 2: Run** → ModuleNotFoundError.
- [ ] **Step 3: Implement**

```python
# solver/paddltir_solver/auth.py
import httpx

class AuthError(Exception):
    pass

def verify_user(token: str, supabase_url: str, anon_key: str, client: httpx.Client | None = None) -> str:
    """Ask GoTrue who this JWT belongs to. Avoids JWT-secret/JWKS handling entirely; one ~50 ms call per request."""
    c = client or httpx.Client(timeout=5.0)
    r = c.get(f"{supabase_url.rstrip('/')}/auth/v1/user", headers={"apikey": anon_key, "Authorization": f"Bearer {token}"})
    if r.status_code != 200:
        raise AuthError(f"auth failed ({r.status_code})")
    uid = r.json().get("id")
    if not uid:
        raise AuthError("no user id in auth response")
    return uid
```
```python
# solver/paddltir_solver/db.py
from __future__ import annotations
from dataclasses import dataclass
import psycopg
from .model import Boat, GenderRule, Lineup, Paddler, PlacementRequest, Roster, SeatAssignment, Side

HEAT_CONTEXT_SQL = """
with h as (select id, race_id, drummer_id, sweep_id from heats h where h.id = %(heat_id)s),
     r as (select r.id, r.crew_id, r.boat_size, r.session_id from races r join h on r.id = h.race_id),
     c as (select c.id, c.club_id, c.category from crews c join r on c.id = r.crew_id)
select json_build_object(
  'clubId', c.club_id,
  'benches', case r.boat_size when 'small' then 5 else 10 end,
  'rule', (select json_build_object('minWomen', cr.min_women, 'maxWomen', cr.max_women, 'minMen', cr.min_men, 'maxMen', cr.max_men)
           from category_rules cr where cr.club_id = c.club_id and cr.category = c.category and cr.boat_size = r.boat_size),
  'paddlers', (select coalesce(json_agg(json_build_object('id', p.id, 'name', p.name, 'weightKg', p.weight_kg, 'ergM', coalesce(pp.erg_m, 0),
                 'side', p.preferred_side, 'gender', p.gender, 'seatPref', p.seat_preference, 'role', p.boat_role)), '[]'::json)
               from paddlers p join paddlers_with_power pp on pp.id = p.id where p.club_id = c.club_id and p.archived_at is null),
  'candidates', (select coalesce(json_agg(cm.paddler_id), '[]'::json) from crew_members cm join paddlers p on p.id = cm.paddler_id
                 where cm.crew_id = c.id and p.archived_at is null
                   and not exists (select 1 from availability a where a.session_id = r.session_id and a.paddler_id = cm.paddler_id and a.status = 'out')),
  'drummerId', h.drummer_id, 'sweepId', h.sweep_id,
  'current', (select coalesce(json_agg(json_build_object('bench', s.bench, 'side', s.side, 'paddlerId', s.paddler_id, 'locked', s.locked) order by s.bench, s.side), '[]'::json)
              from seats s where s.heat_id = h.id)
) from h, r, c
"""

@dataclass
class HeatContext:
    club_id: str
    request: PlacementRequest
    drummer_id: str | None
    sweep_id: str | None

def context_from_row(row: dict, extra_locked: list[SeatAssignment], excluded: set[str]) -> HeatContext:
    boat = Boat(int(row["benches"]))
    roster = Roster(Paddler.from_json(p) for p in row["paddlers"])
    current_assigns = [SeatAssignment.from_json(s) for s in (row.get("current") or [])]
    current = Lineup(boat, row.get("drummerId"), row.get("sweepId"), tuple(current_assigns))
    locked = {a.seat: a for a in current_assigns if a.locked}
    for a in extra_locked: locked[a.seat] = SeatAssignment(a.bench, a.side, a.paddler_id, True)
    cands = tuple(c for c in row["candidates"] if c not in excluded)
    req = PlacementRequest(boat, roster, cands, row.get("drummerId"), row.get("sweepId"), tuple(locked.values()),
                           GenderRule.from_json(row.get("rule")), current)
    return HeatContext(str(row["clubId"]), req, row.get("drummerId"), row.get("sweepId"))

def connect(database_url: str) -> psycopg.Connection:
    return psycopg.connect(database_url, autocommit=True, connect_timeout=5)

def fetch_heat_context(conn: psycopg.Connection, heat_id: str, extra_locked: list[SeatAssignment], excluded: set[str]) -> HeatContext | None:
    with conn.cursor() as cur:
        cur.execute(HEAT_CONTEXT_SQL, {"heat_id": heat_id})
        row = cur.fetchone()
    if row is None: return None
    return context_from_row(row[0], extra_locked, excluded)

def is_coach_of(conn: psycopg.Connection, user_id: str, club_id: str) -> bool:
    with conn.cursor() as cur:
        cur.execute("select 1 from profiles where id = %s and club_id = %s and role in ('head_coach','coach')", (user_id, club_id))
        return cur.fetchone() is not None
```
```python
# solver/paddltir_solver/cache.py
import hashlib, json
import psycopg
from . import SOLVER_VERSION
from .model import PlacementRequest

def input_hash(req: PlacementRequest) -> str:
    payload = json.dumps({"v": SOLVER_VERSION, "req": req.canonical_json()}, sort_keys=True, separators=(",", ":"))
    return hashlib.sha256(payload.encode()).hexdigest()

def get(conn: psycopg.Connection, h: str) -> dict | None:
    with conn.cursor() as cur:
        cur.execute("select result from optimize_cache where input_hash = %s", (h,))
        row = cur.fetchone()
    return row[0] if row else None

def put(conn: psycopg.Connection, h: str, club_id: str, result: dict) -> None:
    with conn.cursor() as cur:
        cur.execute("insert into optimize_cache (input_hash, club_id, result) values (%s, %s, %s::jsonb) on conflict (input_hash) do nothing",
                    (h, club_id, json.dumps(result)))
```

- [ ] **Step 4: Run** → pass. **Step 5: Commit** — `git add solver && git commit -m "feat(solver): auth, db and cache adapters"`

---

### Task 6: FastAPI app

**Files:**
- Create: `solver/paddltir_solver/app.py`, `solver/main.py`, `solver/tests/test_api.py`

**Interfaces:**
- `POST /api/optimize` body `{"heatId": str, "lockedSeats": [{"bench","side","paddlerId"}], "excludedPaddlerIds": [str]}` → 200 `{"heatId","seats":[SeatAssignment],"drummerId","sweepId","reserves":[str],"metrics":Metrics,"proven":{stage:bool},"ruleSatisfied":bool,"solveMs":int,"stageMs":{},"cached":bool}`; 401 on bad token; 403 if not a coach of that club; 404 unknown heat.
- `GET /api/health` → `{"ok": true, "version": SOLVER_VERSION}`.
- Dependencies (overridable in tests): `get_settings()`, `get_conn()`, `get_user_id()`.

- [ ] **Step 1: Write failing API tests**

```python
# solver/tests/test_api.py
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
```

- [ ] **Step 2: Run** → fails.
- [ ] **Step 3: Implement app.py and main.py**

```python
# solver/paddltir_solver/app.py
from __future__ import annotations
import os
from functools import lru_cache
from typing import Annotated
from fastapi import Depends, FastAPI, Header, HTTPException
from pydantic import BaseModel, Field
from . import SOLVER_VERSION, auth, cache, db
from .mip import solve
from .model import SeatAssignment, Side

class Settings(BaseModel):
    supabase_url: str = ""
    supabase_anon_key: str = ""
    database_url: str = ""

@lru_cache
def get_settings() -> Settings:
    return Settings(supabase_url=os.getenv("SUPABASE_URL", ""), supabase_anon_key=os.getenv("SUPABASE_ANON_KEY", ""), database_url=os.getenv("DATABASE_URL", ""))

def get_conn(settings: Annotated[Settings, Depends(get_settings)]):
    conn = db.connect(settings.database_url)
    try: yield conn
    finally: conn.close()

def get_user_id(authorization: Annotated[str | None, Header()] = None, settings: Annotated[Settings, Depends(get_settings)] = None) -> str:
    if not authorization or not authorization.lower().startswith("bearer "):
        raise HTTPException(401, "missing bearer token")
    try:
        return auth.verify_user(authorization.split(" ", 1)[1], settings.supabase_url, settings.supabase_anon_key)
    except auth.AuthError as e:
        raise HTTPException(401, str(e))

# indirections so tests can stub I/O without a database
_fetch_ctx = None
_is_coach_of = db.is_coach_of
_cache_get = cache.get
_cache_put = cache.put

class LockedSeatIn(BaseModel):
    bench: int; side: Side; paddlerId: str

class OptimizeIn(BaseModel):
    heatId: str
    lockedSeats: list[LockedSeatIn] = Field(default_factory=list)
    excludedPaddlerIds: list[str] = Field(default_factory=list)

app = FastAPI(title="Paddltir solver", version=SOLVER_VERSION)

@app.get("/api/health")
def health(): return {"ok": True, "version": SOLVER_VERSION}

@app.post("/api/optimize")
def optimize(body: OptimizeIn, conn=Depends(get_conn), user_id: str = Depends(get_user_id)):
    extra_locked = [SeatAssignment(l.bench, l.side, l.paddlerId, True) for l in body.lockedSeats]
    fetch = _fetch_ctx or (lambda heat_id, el, ex: db.fetch_heat_context(conn, heat_id, el, ex))
    ctx = fetch(body.heatId, extra_locked, set(body.excludedPaddlerIds))
    if ctx is None: raise HTTPException(404, "heat not found")
    if not _is_coach_of(conn, user_id, ctx.club_id): raise HTTPException(403, "coaches only")
    h = cache.input_hash(ctx.request)
    if (hit := _cache_get(conn, h)) is not None:
        return hit | {"cached": True}
    res = solve(ctx.request)
    out = {"heatId": body.heatId, "seats": res.lineup.as_json(), "drummerId": ctx.drummer_id, "sweepId": ctx.sweep_id,
           "reserves": res.unseated, "metrics": res.metrics.to_json(), "proven": res.proven, "ruleSatisfied": res.rule_satisfied,
           "solveMs": res.solve_ms, "stageMs": res.stage_ms, "cached": False}
    _cache_put(conn, h, ctx.club_id, out)
    return out
```
```python
# solver/main.py
from paddltir_solver.app import app  # Vercel entrypoint (pyproject [tool.vercel] entrypoint = "main:app")
```

- [ ] **Step 4: Run** — `uv run pytest -q` → all pass.
- [ ] **Step 5: Integration check against local Supabase** (requires Plan 2 stack running): `export $(grep -v '^#' ../.env | xargs)`; `uv run uvicorn main:app --port 8000 &`; sign in as `coach@paddltir.dev` (password `password123`) via `POST $SUPABASE_URL/auth/v1/token?grant_type=password`; `HEAT=$(psql "$DATABASE_URL" -Atc "select id from heats where name='Heat 1'")`; `curl -s -X POST localhost:8000/api/optimize -H "Authorization: Bearer $TOKEN" -H 'content-type: application/json' -d "{\"heatId\":\"$HEAT\"}" | jq '.metrics, .proven, .solveMs, .cached'` → metrics with seated 20; call again → `cached: true`. Paste the output into PROGRESS.md.
- [ ] **Step 6: Commit** — `git add solver && git commit -m "feat(solver): FastAPI optimize endpoint with auth and cache"`

---

### Task 7: Vercel deploy (Services)

**Files:**
- Create: `vercel.json` (repo root), `solver/.vercelignore`

- [ ] **Step 1: Write vercel.json (solver only for now; Plan 5 adds the `web` service and its catch-all rewrite)**

```json
{
  "$schema": "https://openapi.vercel.sh/vercel.json",
  "services": {
    "solver": { "root": "solver/", "entrypoint": "main:app" }
  },
  "rewrites": [
    { "source": "/api/(.*)", "destination": { "service": "solver" } }
  ]
}
```
```
# solver/.vercelignore
tests/
.venv/
.pytest_cache/
```

- [ ] **Step 2: Link and deploy a preview** — from repo root: `vercel link --yes --project paddltir --scope junlee-3` then `vercel deploy --yes`. Set env vars first: `vercel env add SUPABASE_URL production preview`, `SUPABASE_ANON_KEY`, `DATABASE_URL` (the **transaction pooler** URL from Keychain item `paddltir-supabase-pooler-url`; never the direct 5432 one for serverless).
  Expected: a preview URL; `curl https://<preview>/api/health` → `{"ok":true,"version":"1"}`.
  **If `services` is rejected on the Hobby plan**, fall back: `cd solver && vercel link --yes --project paddltir-solver && vercel deploy --yes` (zero-config FastAPI project) and record the decision in PROGRESS.md.
- [ ] **Step 3: Benchmark cold and warm on Vercel** — `time curl -s -X POST https://<preview>/api/optimize -H "Authorization: Bearer $TOKEN" -d '{"heatId":"<hosted heat id>"}'` twice (needs a heat in the hosted DB — create one via the API as the throwaway coach from Plan 2 Task 7, or wait for Plan 6). Record cold/warm/solveMs in PROGRESS.md.
- [ ] **Step 4: Commit + push** — `git add vercel.json solver/.vercelignore && git commit -m "chore(solver): Vercel services config" && git push`

---

### Task 8: Wrap-up
- [ ] `uv run pytest -q` green; `uv run python -m paddltir_solver.fixtures check ../fixtures/placement` → all `ok`.
- [ ] `uv run ruff check .` (add `ruff` to dev deps) → clean.
- [ ] `solver/README.md` (what, how to run, how to regenerate fixtures, env vars).
- [ ] Update PROGRESS.md (timings, warm-start observation, proven flags seen), tick Plan 3 in the roadmap, commit + push.

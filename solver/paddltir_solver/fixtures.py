"""Golden fixture loader + CLI. `python -m paddltir_solver.fixtures update|check <dir>` writes/checks expected.mip."""
from __future__ import annotations

import json
import sys
from dataclasses import dataclass
from pathlib import Path

from .model import (
    Boat,
    GenderRule,
    Lineup,
    Metrics,
    Paddler,
    PlacementRequest,
    Roster,
    SeatAssignment,
)


@dataclass
class Fixture:
    path: Path
    raw: dict
    @property
    def name(self) -> str: return self.raw["name"]
    @property
    def boat(self) -> Boat: return Boat(int(self.raw["boat"]["benches"]))
    @property
    def rule(self) -> GenderRule | None: return GenderRule.from_json(self.raw.get("rule"))
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
    def current_lineup(self) -> Lineup | None:
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

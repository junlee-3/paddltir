"""Domain model shared with PaddltirCore (Swift). Keep field names/JSON keys identical to fixtures/README.md."""
from __future__ import annotations
from dataclasses import dataclass, field
from enum import Enum
from functools import total_ordering
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

@dataclass(frozen=True)
@total_ordering
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

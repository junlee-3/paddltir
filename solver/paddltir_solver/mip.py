"""Lexicographic MIP with HiGHS. Stages: seated↑, power↑, weight↓, side↓, seat↓, powerBalance↓, trim↓, moves↓.
Each stage locks its optimum (± eps) as a constraint before the next objective is solved."""
from __future__ import annotations

import time
from dataclasses import dataclass

import highspy

from .model import (
    GenderRule,
    Lineup,
    Metrics,
    PlacementRequest,
    SeatAssignment,
    Side,
)
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
    warm_start_ok: bool = True    # False if HiGHS rejected a stage warm start (see _Model.run)

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
        self.warm_start_ok = True
        h = highspy.Highs(); h.silent()
        h.setOptionValue("mip_rel_gap", 0.0); h.setOptionValue("mip_abs_gap", EPS)
        h.setOptionValue("threads", 1); h.setOptionValue("random_seed", 0)
        self.h = h
        self.x = {(a, s.bench, s.side): h.addBinary() for a in self.cands for s in self.seats}
        # y[a, side] == "a paddles on that side" — an exact aggregation of x over benches. Redundant in theory,
        # decisive in practice: every side-only objective (power/weight/side/powerBalance) is flat across the 10
        # interchangeable benches, so branching on x cannot separate anything and the dual bound crawls. Branching
        # on y splits the search directly (weight stage: 17.7 s → ~0.1 s to prove optimality).
        self.y = {(a, sd): h.addBinary() for a in self.cands for sd in (Side.left, Side.right)}
        # ≤ 1 per seat; y ties x to the side aggregate; ≤ 1 side per paddler
        for s in self.seats:
            h.addConstr(h.qsum([self.x[a, s.bench, s.side] for a in self.cands]) <= 1)
        for a in self.cands:
            for sd in (Side.left, Side.right):
                h.addConstr(self.y[a, sd] == h.qsum([self.x[a, s.bench, s.side] for s in self.seats if s.side is sd]))
            h.addConstr(self.y[a, Side.left] + self.y[a, Side.right] <= 1)
        # locks
        for l in req.locked:
            if (l.paddler_id, l.bench, l.side) in self.x:      # ignore locks naming a seat outside this boat
                h.addConstr(self.x[l.paddler_id, l.bench, l.side] == 1)
        # gender rule (on seated paddlers)
        if rule is not None:
            w_expr = h.qsum([v for (a, _), v in self.y.items() if self.roster[a].gender.value == "female"])
            m_expr = h.qsum([v for (a, _), v in self.y.items() if self.roster[a].gender.value == "male"])
            if rule.min_women is not None: h.addConstr(w_expr >= rule.min_women)
            if rule.max_women is not None: h.addConstr(w_expr <= rule.max_women)
            if rule.min_men is not None: h.addConstr(m_expr >= rule.min_men)
            if rule.max_men is not None: h.addConstr(m_expr <= rule.max_men)
        # objective expressions
        R = self.roster
        self.seated_expr = h.qsum(list(self.y.values()))
        self.power_expr = h.qsum([R[a].erg_m * v for (a, _), v in self.y.items()])
        wl = h.qsum([R[a].weight_kg * v for (a, sd), v in self.y.items() if sd is Side.left])
        wr = h.qsum([R[a].weight_kg * v for (a, sd), v in self.y.items() if sd is Side.right])
        pl = h.qsum([R[a].erg_m * v for (a, sd), v in self.y.items() if sd is Side.left])
        pr = h.qsum([R[a].erg_m * v for (a, sd), v in self.y.items() if sd is Side.right])
        self.dW = h.addVariable(lb=0); h.addConstr(self.dW >= wl - wr); h.addConstr(self.dW >= wr - wl)
        self.dP = h.addVariable(lb=0); h.addConstr(self.dP >= pl - pr); h.addConstr(self.dP >= pr - pl)
        self.side_expr = h.qsum([v for (a, sd), v in self.y.items() if not R[a].side.matches(sd)])
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
            if last_sol is not None:                                    # warm start from previous stage
                try:
                    h.setSolution(last_sol)
                except Exception:                                       # noqa: BLE001 — model shape changed → warm start is optional
                    self.warm_start_ok = False
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
    m = _Model(req, req.rule)
    lineup, proven, stage_ms, ok = m.run(caps)
    warm_start_ok = m.warm_start_ok
    if not ok and req.rule is not None:
        rule_satisfied = False
        m = _Model(req, None)
        lineup, proven, stage_ms, ok = m.run(caps)
        warm_start_ok = warm_start_ok and m.warm_start_ok
    if not ok or lineup is None:   # only possible if even the empty lineup is infeasible (contradictory locks)
        lineup = Lineup(req.boat, req.drummer_id, req.sweep_id, tuple(req.locked)); proven = {}
    metrics = evaluate(lineup, req.roster, req.current)
    unseated = [c for c in _eligible(req) if c not in lineup.seated_ids]
    unseated.sort(key=lambda c: (-req.roster[c].erg_m, -req.roster[c].weight_kg, c))
    return SolveResult(lineup, metrics, proven, rule_satisfied, int((time.perf_counter() - t0) * 1000), stage_ms, unseated, warm_start_ok)

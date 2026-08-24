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

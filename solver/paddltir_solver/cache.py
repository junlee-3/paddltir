import hashlib
import json

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

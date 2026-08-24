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

# paddltir-solver

Python + HiGHS (`highspy`) lineup optimiser for Paddltir, exposed as a FastAPI service
(`POST /api/optimize`, `GET /api/health`) and deployed on Vercel as a Python Service
(`vercel.json` at the repo root; `main.py` is the `main:app` entrypoint). Given a heat's
roster, boat size, gender rule and locked seats, it lexicographically maximises seated
count and power, then minimises weight/side/seat/power imbalance, trim, and moves.

## Run tests

    uv run pytest -q

## Run the API locally

    uv run uvicorn main:app

Needs `SUPABASE_URL`, `SUPABASE_ANON_KEY` (bearer-token auth against Supabase) and
`DATABASE_URL` (Postgres — transaction pooler URL in production, not the direct 5432 one).

## Regenerate MIP golden fixtures

    uv run python -m paddltir_solver.fixtures update ../fixtures/placement

## Benchmark

All eight stages prove optimal in ≈161ms on the 22-athlete standard instance
(`std-mixed-22`); trim is honestly unproven at its 0.5s cap on some rosters (still
feasible and no worse than greedy, just not certified optimal).

# Backend (Supabase)

Paddltir's backend: a Postgres schema on Supabase — tables, row-level
security (RLS), and RPCs for dragon boat club management (paddlers, erg
tests, crews, sessions, availability). No separate app server; the Data API
+ RLS is the API.

**Prereqs:** [OrbStack](https://orbstack.dev/) (Docker) + the
[Supabase CLI](https://supabase.com/docs/guides/cli).

**Local dev:**
```sh
supabase start     # boot local stack (Postgres, Auth, Studio, ...)
supabase db reset  # drop + recreate DB: applies migrations + seed.sql
supabase test db   # pgTAP suite, 93 tests across 6 files
```
Reset before testing if the DB has been poked at manually — stale rows can
make RLS/uniqueness-sensitive tests fail spuriously.

**Demo data:** `seed.sql` only sets up pgTAP test helpers. For a browsable
demo club, layer `seed_dev.sql` on top:
```sh
supabase db reset && psql "postgresql://postgres:postgres@127.0.0.1:54322/postgres" -f supabase/seed_dev.sql
```
Creates club "Paddltir Demo Club", invite code `DEMO2026`, coach
`coach@paddltir.dev`, paddler `lily@paddltir.dev`.

**Migrations:** `0001` types+tables · `0002` helpers/RPCs/profile triggers/
grants · `0003` RLS policies · `0004` views.

**Security model:** coaches get full CRUD within their club. Paddlers read
club-scoped rows, but only their own row from base `paddlers`; teammates are
visible only via `paddlers_public` (name/side/role — no weight/gender/erg/
email). Paddlers write only their own availability and their own erg
(`source='self'`). `anon` gets nothing. Club membership changes only via the
RPCs `create_club` / `join_club` / `claimable_paddlers` /
`regenerate_invite_code`.

**Hosted deploy (go-live):** pending, separate phase. `supabase link` +
`supabase db push` + `supabase config push` deploy migrations to a hosted
project; `seed_dev.sql` is never pushed.

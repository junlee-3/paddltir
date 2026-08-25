# Paddltir — paddler PWA

Next.js App Router + Supabase (`@supabase/ssr`) + Tailwind v4. Mobile-first, installable, realtime.

## Local setup
1. From the repo root: `supabase start`, `supabase db reset`, then load demo data:
   `/opt/homebrew/opt/libpq/bin/psql "postgresql://postgres:postgres@127.0.0.1:54322/postgres" -f supabase/seed_dev.sql`
   (`psql` isn't on `PATH` by default on macOS/Homebrew; if you have a different client, `docker exec -i supabase_db_paddltir psql -U postgres -d postgres -f -  < supabase/seed_dev.sql` also works.)
2. `cp .env.example .env.local` and paste the anon key from `supabase status`.
3. `pnpm install && pnpm dev` → http://localhost:3000 — sign in with the dev form as `lily@paddltir.dev` / `password123`
   (the form only renders when `NEXT_PUBLIC_PADDLTIR_DEV_LOGIN=1`; never set it on Vercel).

## Commands
`pnpm typecheck` · `pnpm lint` · `pnpm test` (Vitest, `lib/`) · `pnpm build` · `PADDLTIR_LIVE_SUPABASE=1 pnpm e2e` (Playwright smoke vs the local stack) · `pnpm icons` (regenerate PNG icons from `scripts/*.svg`).

## Shape
- `app/` routes: `/login` (magic link) · `/join` (invite code → claim your name) · `/` next event (+ `/session/[id]`) · `/availability` · `/erg` · `/profile` · `/auth/*` · `/offline`.
- `lib/` pure, unit-tested rules (boat sections mirror `PaddltirCore.Boat`; lineup lookup; gating; validation). No scoring — paddlers *see* lineups.
- Server Components read through the user's cookie session (RLS authorises); Server Actions write; `proxy.ts` refreshes the session.
- Realtime `postgres_changes` on `sessions/heats/seats/heat_reserves/availability` → `router.refresh()`.
- Regenerate DB types after a migration: `supabase gen types typescript --local --schema public > lib/db/database.types.ts`.

## End-to-end test
`e2e/smoke.spec.ts` is a Playwright smoke test that signs in, checks the next event and boat diagram, toggles availability, logs an erg, and views the profile — against the real local Supabase stack and the demo seed. It's gated behind `PADDLTIR_LIVE_SUPABASE=1` (see `web/playwright.config.ts`) so `pnpm e2e` alone reports it skipped and CI without a live stack stays green. Run the local setup steps above first, then `PADDLTIR_LIVE_SUPABASE=1 pnpm e2e`. The test logs a 555 m self erg row and deletes it again in `test.afterAll` (via `docker exec supabase_db_paddltir psql …`) so the seed is left clean; that cleanup only runs when `PADDLTIR_LIVE_SUPABASE` is set.

## Go-live (needs Jun)
Vercel project `paddltir` with services `web/` + `solver/` (`vercel.json`); env `NEXT_PUBLIC_SUPABASE_URL`, `NEXT_PUBLIC_SUPABASE_ANON_KEY`, `NEXT_PUBLIC_SITE_URL=https://paddltir.vercel.app`. Supabase Auth → add the Vercel URL to redirect URLs (already listed in `supabase/config.toml` for local).

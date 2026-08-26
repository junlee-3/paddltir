# Paddltir

Crew management for dragon boat clubs. Coaches build balanced lineups; paddlers see where they're sitting.

A dragon boat has ten benches, two seats each, a drummer at the bow and a sweep at the stern. Who sits where decides whether the boat runs level, whether the strong side of the crew is on the strong side of the boat, and whether the mixed-crew gender rule is met. Coaches have been working this out on paper, in spreadsheets and in group chats. Paddltir replaces that with two apps that share one set of rules and one database.

## The two apps

**Coach app** — native SwiftUI for iOS 26 and macOS 26 (`apple/`). Squad, crews, training sessions and race days. The centrepiece is the lineup editor: tap or drag paddlers into seats, lock a seat, set the drummer and sweep, undo and redo, and watch a balance readout update on every change — weight left/right, power left/right, side-preference satisfaction, trim, and the gender count against the club's rule. Auto-fill produces a sensible lineup in one tap; Suggest ranks the swaps that would improve it most. Works offline: the app keeps a local mirror of the club's data (GRDB) and syncs with the server when it can.

**Paddler app** — an installable web app (`web/`, Next.js). A paddler signs in with an email link, joins the club with its invite code, and gets one screen that matters: the next event. For a race day that is the boat diagram with their own seat highlighted, the full lineup by name, and a tab per heat; for a training night it is a one-tap In / Maybe / Out. They can also log erg results and manage their availability. Lineup changes made by the coach appear without a refresh.

What paddlers can see is decided by the database, not by the UI: a paddler can read club-mates' names and sides through a dedicated view, but never anyone else's weight, gender, email or erg results.

## How a lineup is judged

The scoring engine is a pure Swift package (`packages/PaddltirCore`) used by the coach app on every edit, and mirrored by the Python optimiser. Both rank lineups in the same order:

0. seat as many of the crew as capacity allows, and maximise the total erg power of the seated crew (so a strong paddler is never benched to shave a kilogram of imbalance);
1. minimal weight imbalance between left and right;
2. fewest side-preference mismatches;
3. fewest seat-section mismatches (stroke, pace, engine, sprint);
4. minimal power imbalance;
5. minimal trim moment (weight forward vs aft, measured from the boat's centre);
6. fewest moves from the current lineup, so suggestions stay predictable.

Hard constraints: one paddler per seat, each paddler once, locked seats stay put, unavailable paddlers stay out, the club's gender bounds hold, and only eligible people take the drummer and sweep positions. The readout turns red above the club-standard thresholds: weight Δ over 10 kg, power Δ over 10 %, side preference under 80 %, trim Δ over 50 kg.

A standard boat has 10 benches (stroke 1, pace 2–3, engine 4–7, sprint 8–10); a small boat has 5 (1 / 2 / 3 / 4–5).

## What's in the repository

| Path | What it is |
|---|---|
| `packages/PaddltirCore/` | The domain in pure Swift 6: boat geometry, lineup model, scoring, validation, a greedy auto-fill and a swap-suggestion engine. No UI, no I/O. |
| `apple/` | The coach app. XcodeGen project (`project.yml` → generated `.xcodeproj`), one target for iOS and macOS, GRDB local store, Supabase client, offline-first sync. |
| `web/` | The paddler app. Next.js App Router, `@supabase/ssr`, Tailwind, a service worker and manifest so it installs to the home screen, Playwright smoke test. |
| `supabase/` | The backend: Postgres migrations (tables, RPCs, row-level security, views, realtime publication), a local seed of test helpers, a demo dataset, and pgTAP tests. |
| `solver/` | Optional server-side optimiser: FastAPI + HiGHS mixed-integer programming that proves optimal lineups under the same priority order. Deployed alongside the web app on Vercel. |
| `fixtures/` | Golden JSON cases (roster + rules → expected lineup and metrics) run by both the Swift and Python test suites so the two implementations cannot drift. |
| `docs/` | The product spec, the visual direction, and the implementation plans with their execution records. |
| `PROGRESS.md` | Where the project is right now, what is merged, what is deferred. |

## How it fits together

Supabase is the single source of truth: Postgres with row-level security, a handful of RPCs for the flows that need elevated rights (create a club, join by invite code, claim a roster row), and Realtime on the tables that change during a session. Every row carries a `club_id`; a profile belongs to one club.

The coach app talks to it through supabase-swift and keeps a local mirror in GRDB. Reads come from the mirror (screens are live `ValueObservation`s over the local database), writes go to the mirror and an outbox, and a sync pass pulls changes and drains the outbox whenever the app is in the foreground and online.

The paddler app reads straight through the user's session, so the security policies decide what each request can see. Writes go through server actions that derive the paddler's identity on the server. Realtime events just tell the page to re-render from the server.

The solver is stateless: it receives a heat's roster, rules and locked seats, returns a lineup, and can honestly say which stages it proved optimal.

## Running it locally

You need Docker (or OrbStack) and the [Supabase CLI](https://supabase.com/docs/guides/cli) for the backend; Xcode 26 and [XcodeGen](https://github.com/yonaskolb/XcodeGen) for the coach app; Node 22 and pnpm for the paddler app; [uv](https://docs.astral.sh/uv/) for the solver.

### Backend

```sh
supabase start
supabase db reset                                  # applies every migration + test helpers
psql "postgresql://postgres:postgres@127.0.0.1:54322/postgres" -f supabase/seed_dev.sql   # demo club
supabase status                                    # prints the local URL and keys
```

The demo dataset is a club with invite code `DEMO2026`, a 24-person squad, a training night and a regatta with three heats. Two local accounts exist: `coach@paddltir.dev` and `lily@paddltir.dev`, both with password `password123`. They only exist on the local stack.

### Coach app

```sh
cp apple/Sources/Data/App/Secrets.example.swift apple/Sources/App/Secrets.swift   # paste the local anon key
cd apple && xcodegen generate && open Paddltir.xcodeproj
```

Run the `Paddltir` scheme on an iPhone simulator or on your Mac. Debug builds accept `PADDLTIR_DEBUG_AUTOSIGNIN=1` in the scheme's environment to sign in as the demo coach without typing.

### Paddler app

```sh
cd web
cp .env.example .env.local        # paste the local anon (or publishable) key
pnpm install
pnpm dev                          # http://localhost:3000
```

With `NEXT_PUBLIC_PADDLTIR_DEV_LOGIN=1` set (it is, in `.env.example`) the login page shows a password form for the local accounts. Never set that variable in a deployment.

### Solver

```sh
cd solver && uv run uvicorn main:app    # POST /api/optimize, GET /api/health
```

See `solver/README.md` for the environment it expects.

## Tests

| Surface | Command | Covers |
|---|---|---|
| Domain | `cd packages/PaddltirCore && swift test` | Boat geometry, scoring, validation, greedy fill, suggestions; property tests for capacity, uniqueness, gender bounds, locks and monotonicity; the golden fixtures. |
| Coach app | `cd apple && xcodegen generate && xcodebuild -scheme Paddltir -destination 'platform=iOS Simulator,name=iPhone 17 Pro' test` | 126 tests: repositories and observations against an in-memory database, view-model behaviour, the lineup editor's interactions, sync. Add `TEST_RUNNER_PADDLTIR_LIVE_SUPABASE=1` to also run the end-to-end tests against the local stack. |
| Database | `supabase test db` | 100 pgTAP tests: schema, RPCs, security policies exercised as head coach, coach, paddler and anonymous, the views, the realtime publication. Run on a freshly reset database. |
| Paddler app | `cd web && pnpm typecheck && pnpm lint && pnpm test && pnpm build` | 60 Vitest tests over the pure modules (boat sections, seat lookup, event mapping, time zone handling, validation, redirect safety). `PADDLTIR_LIVE_SUPABASE=1 pnpm e2e` runs a Playwright journey through sign-in, availability, the boat diagram, an erg log and the profile against the local stack. |
| Solver | `cd solver && uv run pytest -q` | 25 tests plus the shared golden fixtures. |

## Design

The look is deliberate and documented in `docs/design/direction.md`: slate text on off-white, depth from hairline borders rather than shadows, one typeface (Inter Tight) with tabular numerals for every number, and colour used only when it means something — green and amber seat tiles for gender, emerald and red for a readout that is inside or outside its threshold, a single teal accent for selection. The native app uses Liquid Glass on floating chrome only (the heat switcher, toolbars, the reserves tray); the web app does not fake it. Light mode only for now.

## Status

Everything described above is built, reviewed and merged. Nothing is deployed yet: the next step is provisioning the hosted Supabase project and the Vercel project, which needs the owner's credentials. `PROGRESS.md` has the current state and the go-live checklist; `docs/superpowers/specs/2026-08-22-paddltir-design.md` is the spec; the plans under `docs/superpowers/plans/` record how each part was built and what was deliberately left for later.

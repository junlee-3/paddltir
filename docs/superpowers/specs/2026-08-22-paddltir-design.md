# Paddltir — Product & System Design (v1)

*Date: 2026-08-22 · Status: approved in brainstorm, pending written review*

Paddltir is a dragon-boat crew-management product: a premium SwiftUI coach app
(iOS 26 + macOS 26), a paddler PWA (Next.js on Vercel), a Supabase backend, and a
Python lexicographic MIP solver. It is a from-scratch rebuild that solves the same
problem as the read-only CrewCoach prototype; nothing else is carried forward.

---

## 1. Domain

A **boat** seats `n` benches × 2 sides (L/R): standard `n = 10` (20 paddlers),
small `n = 5` (10 paddlers), plus a **drummer** (bow) and a **sweep** (stern).

**Bench sections** — standard: Stroke `[1]`, Pace `[2,3]`, Engine `[4–7]`,
Sprint `[8–10]`; small: Stroke `[1]`, Pace `[2]`, Engine `[3]`, Sprint `[4,5]`.

**Paddler** attributes: `weight_kg`, power (= latest 2-minute erg result in
metres, higher is better), `preferred_side` `left|right|either`, `gender`
`female|male`, `seat_preference` `stroke|pace|engine|sprint|none`, `boat_role`
`paddler|drummer|sweep` (a drummer/sweep may also paddle; a sweep-only paddler
is never benched by the algorithms).

**Age divisions:** `16U 18U 24U Premier "Senior A" "Senior B" "Senior C"`.
**Categories:** `open | women | mixed`. **Gender rule** (IDBF, verified
2026-08-22): mixed standard boat 8–12 of each gender /20; mixed small boat 4–6
/10; some events use 8–10 / 4–5 → stored per club as `category_rules`
(min/max women per category × boat size). `women` ⇒ all female, `open` ⇒ none.

**A good lineup** (in priority order, identical in both algorithms):
0. seats as many of the crew as capacity allows,
0b. maximises the total erg power of the seated crew (selection quality — so the
   optimiser never benches a strong paddler to shave grams of imbalance),
1. minimal weight imbalance `|ΣL_w − ΣR_w|`,
2. minimal side-preference mismatches,
3. minimal seat-section mismatches,
4. minimal power imbalance `|ΣL_p − ΣR_p|`,
5. minimal trim moment `|Σ w·arm + fixed|` where bench `b` has arm
   `b − (n+1)/2` (metres, 5.5 for standard), drummer arm `−(n+1)/2`, sweep arm
   `+(n+1)/2`,
6. fewest moves from the current lineup (determinism / trust).

Hard constraints: ≤ 1 paddler per seat; each paddler at most once; locked seats
fixed; excluded / unavailable paddlers out; gender bounds; boat-role
eligibility.

**Warning thresholds (HUD colour):** weight Δ > 10 kg, power Δ > 10 % of total,
side-preference satisfaction < 80 %, trim Δ > 50 kg (trimΔ = 2|moment|/n).

### Renamed concepts

| Old prototype | Paddltir | Meaning |
|---|---|---|
| Roster | **Squad** | all paddlers in a club |
| Crewlist | **Crew** | named group with age division + category (e.g. "Premier Mixed") |
| Config | **Race** | an event for one crew at a race day; has a boat size and **Heats** |
| lineupHeat1/2/Final | **Heat** | a heat *is* a lineup: seats + drummer + sweep + reserves |
| (none) | **Session** | training night or race day; availability hangs off it |

---

## 2. Users & access

- **Coach** (`head_coach` / `coach`): creates a club, gets an invite code, manages
  squad, crews, sessions, races, lineups; runs Optimise.
- **Paddler**: signs in by email magic link, joins with the invite code, claims
  their roster row (auto-linked when the coach entered their email), sees the
  full lineup (names only — never others' weights/erg/gender), submits
  availability and erg results.
- Multi-club ready from day one (every row carries `club_id`); a profile belongs
  to exactly one club in v1.

---

## 3. Coach app (SwiftUI, iOS 26 + macOS 26)

### Navigation — "Schedule · Crews · Squad"
iPhone: 3-tab bar + avatar/settings button. iPad/Mac: `NavigationSplitView`
(sidebar: Schedule / Crews / Squad / Settings → list → detail).

**First run:** Sign in (Sign in with Apple, email magic link) → *Create a club*
or *Join with code* → Schedule.

**Schedule** — timeline grouped by day. Top: **Up next** hero card (next
session: kind, venue, countdown, headcount `18 in · 2 out · 2 no reply`; for a
race day, its races with *Open lineup*). Then upcoming, then past (collapsed).
`+` → Training session | Race day.
- *Training detail:* availability list (In/Out/Maybe/No reply + notes), coach
  override, quick "record erg test".
- *Race day detail:* races (crew · boat size · distance), day availability
  summary, `+ Race`. Tap race → Lineup editor.

**Crews** — cards (name, division, category, members, next race). Detail:
members with side/weight/erg chips, add/remove from squad (search), races for
this crew, gender-rule check (`W 9 · M 13` vs rule).

**Squad** — searchable, sortable table (name, weight, erg, side, section, role);
filters (side, gender, role, linked). Paddler detail: fields, erg history
sparkline, availability history, invite/link status. **Archive**, never delete.

**Settings** — club name, invite code/link (share sheet), category gender rules,
coaches, appearance (system/light/dark), sign out.

### Lineup editor — the hero screen
- Boat fills the screen, bow at top. Glass capsule header: race name + **heat
  switcher** (`Heat 1 · Heat 2 · Final · +`; long-press → rename / duplicate /
  delete; "Copy from …" on create).
- Hull = solid legible surface: Drummer, `n` bench rows `L | # · section | R`,
  Sweep. Seat card: name, weight, side/section tags (amber when violated).
  Section bands subtly shaded.
- **Live balance HUD** (glass bar): Weight Δ kg (bubble level), Power Δ %, Trim
  (bow/stern bubble), Prefs (side % · seat %), gender badge `W 9 / 8–12`.
  Green/amber/red by thresholds. Tap → detail sheet.
- **Reserves tray** (glass bottom sheet): unseated crew as chips; unavailable
  today dimmed with *Out* (from session availability); search when > 8.
- **Interaction:** drag (long-press lift, haptic, scale+shadow; drop on occupied
  = swap with spring-back of displaced card, on empty = place, on tray =
  unseat; HUD previews while hovering); tap-tap swap for one-handed use;
  long-press menu (Lock seat, Mark reserve, Set drummer/sweep, View paddler);
  undo/redo always.
- **Toolbar (glass):** Suggest (top-3 greedy swaps with before→after deltas,
  one-tap apply), Auto-fill (greedy, offline, instant), Optimise (server MIP;
  progress sheet ticking stages with honest `proven` marks; preview diff of
  moves; Apply), Share (image snapshot).
- Mac/iPad: boat centred, right inspector (balance detail, suggestions,
  searchable reserves), keyboard shortcuts (⌘Z/⇧⌘Z, arrows + space to swap).

### Architecture
- `PaddltirCore` Swift package: **zero UI imports**. Domain structs, scoring,
  greedy algorithms, suggestion engine, sync diffing helpers; all pure, all
  `Codable`, all `Sendable`; Swift Testing.
- App: SwiftUI + Observation; GRDB (SQLite) local mirror; `supabase-swift` for
  Auth/PostgREST/Realtime; Liquid Glass via `.glassEffect()`,
  `GlassEffectContainer`, `glassEffectID`, `.buttonStyle(.glass)` on floating
  chrome only.
- Offline: pull on launch/foreground (`updated_at > last_sync` per table), push
  via outbox, last-write-wins on `updated_at`, Realtime when online. Greedy and
  cached optimise results work offline.

---

## 4. Paddler PWA (Next.js App Router on Vercel)

Routes: `/login` (magic link) · `/join` (invite code → claim name) · `/` (your
next event: race → your seat highlighted on a boat diagram + full lineup by
name, heat switcher; training → inline availability) · `/availability` ·
`/erg` (submit metres + date, history, sparkline) · `/profile`.
Installable (manifest + service worker, one-time add-to-home-screen nudge).
Realtime subscriptions to heats/seats/sessions. `@supabase/ssr`, Tailwind,
mobile-first, same palette/type/boat diagram as native, no fake glass.

---

## 5. Data model (Postgres / Supabase)

```sql
clubs            (id, name, invite_code UNIQUE, created_by, created_at)
profiles         (id PK → auth.users, club_id, role head_coach|coach|paddler,
                  display_name, avatar_url, created_at)
paddlers         (id, club_id, profile_id UNIQUE NULL, name, email NULL,
                  weight_kg, preferred_side, gender, seat_preference, boat_role,
                  archived_at NULL, updated_at)
erg_tests        (id, paddler_id, tested_at, metres, source coach|self,
                  recorded_by, created_at)
  -- view paddlers_with_power: paddlers + latest erg metres (erg_m)
crews            (id, club_id, name, age_division, category, updated_at)
crew_members     (crew_id, paddler_id)  PK(crew_id, paddler_id)
sessions         (id, club_id, kind training|race_day, title, starts_at, venue,
                  notes, updated_at)
availability     (session_id, paddler_id, status in|out|maybe, note, updated_at)
                  PK(session_id, paddler_id)
races            (id, session_id, crew_id, name, boat_size small|standard,
                  distance_m, sort_order, updated_at)
heats            (id, race_id, name, sort_order, drummer_id NULL, sweep_id NULL,
                  updated_at)
seats            (heat_id, bench, side, paddler_id, locked bool)
                  PK(heat_id, bench, side)  UNIQUE(heat_id, paddler_id)
heat_reserves    (heat_id, paddler_id)  PK(heat_id, paddler_id)
category_rules   (club_id, category, boat_size, min_women, max_women, min_men, max_men)
                  PK(club_id, category, boat_size)  -- nullable = unbounded; seeded with IDBF defaults
                  -- (women ⇒ max_men 0; mixed standard 8–12/8–12; mixed small 4–6/4–6)
optimize_cache   (input_hash PK, result jsonb, created_at)
```
All mutable tables carry `updated_at` (trigger-maintained) for sync. Deleting a
paddler is forbidden; `archived_at` hides them. `powerRatio` is gone: algorithms
use absolute erg metres (scale-invariant objective), the UI derives a relative
bar per crew at render time.

**Auth/onboarding:** Supabase Auth (magic link, Sign in with Apple). Trigger on
`auth.users` insert → `profiles` row; if `paddlers.email` matches → link
`profile_id`, role `paddler`. `join_club(code, paddler_id?)` SECURITY DEFINER
RPC validates the code and links; it is the only path by which a paddler
writes to `paddlers`. Email linking happens only after the address is verified
(confirmation trigger); rows with a coach-entered email are reserved for that
address and are not claimable by name. `create_club(name)` RPC makes the caller `head_coach`.

**RLS:** helper `auth_club_id()`, `is_coach()`.
- Coaches: full CRUD on every row of their club.
- Paddlers: SELECT crews, crew_members, sessions, races, heats, seats,
  heat_reserves, availability of own club; SELECT **`paddlers_public`** view
  (id, name, preferred_side, boat_role — no weight/erg/gender/email); SELECT own
  full `paddlers` row and own `erg_tests`; INSERT/UPDATE own `availability`;
  INSERT own `erg_tests` with `source='self'`; UPDATE own `profiles`.
- Anonymous: nothing. Solver: service role after verifying a coach JWT.

---

## 6. Algorithms

### Greedy (Swift, `PaddltirCore`)
1. **Select** — honour locks; fill remaining capacity from available crew by
   erg desc while satisfying gender min/max (selection ≠ placement, so the
   gender rule is enforceable here).
2. **Construct** — place candidates (weight desc, then erg) into the seat
   minimising the lexicographic score (incl. trim, with drummer/sweep fixed
   term).
3. **Improve** — 2-opt local search over seat↔seat swaps and seat↔reserve
   replacements; each iteration applies the single *best*-improving move
   (best-improvement steepest descent, not first-improvement — both
   deterministic; the golden fixtures pin the chosen variant); loop until no
   improvement. Deterministic (stable ordering). Measured ≈ 3 ms release for 20
   seats.
API: `evaluate(lineup) → Metrics`, `autoFill(...)`, `suggestSwaps(top:)`,
`replacementPlans(for:)`, `validate(lineup) → [Violation]`.

### MIP (Python 3.12, highspy)
Stages 0, 0b, 1–6 as in §1; each stage adds `objective ≤ best + ε` before the next;
warm-start from previous solution. Variables `x[a,b,s] ∈ {0,1}`, `d_drummer`
etc. fixed from lineup; slacks for absolute values. Caps: stages 0–4 1 s,
stage 5 0.5 s, stage 6 0.5 s; `proven[stage]` from HiGHS model status (stage 5
realistically `false`). Bench count, gender bounds, locks, exclusions, roles all
parameters. Deterministic for identical inputs.

**Service (wire format is camelCase, matching the fixture contract — the §6 prose above uses snake_case for the math):** FastAPI `POST /api/optimize` `{heat_id, locked_seats[],
excluded_paddler_ids[]}` → `{seats[], drummer_id, sweep_id, reserves[],
metrics{}, proven{}, solve_ms, cached}`. Verifies Supabase JWT + coach role,
one SQL read (psycopg), cache keyed by `sha256(canonical roster snapshot +
rule + locks + excluded + current lineup)` in `optimize_cache`.

---

## 7. Hosting & environments

- Supabase project `paddltir` (ap-southeast-2) = staging/prod; local stack via
  OrbStack + `supabase start` for migrations and pgTAP.
- Vercel project `paddltir` (Hobby, non-commercial): **Services** — `web/`
  (Next.js) at `/`, `solver/` (FastAPI + highspy) at `/api/optimize`. Fallback
  if Services is unavailable on the plan: file-based `web/api/optimize.py`.
- Secrets in Vercel/Supabase env; nothing committed.

## 8. Testing

- `fixtures/*.json` golden cases (input roster/rules/lineup → expected lineup &
  metrics) run by Swift Testing and pytest.
- Property tests: capacity, uniqueness, gender bounds, locks, lexicographic
  monotonicity (Hypothesis / Swift).
- pgTAP RLS tests as head_coach / coach / paddler / anon attempting forbidden
  reads and writes (`supabase test db`).
- PWA: Vitest unit + one Playwright smoke. Solver timing benchmark script.

## 9. Repo layout
```
apple/                 Xcode project (iOS + macOS targets)
packages/PaddltirCore/ pure Swift package + tests
web/                   Next.js PWA
solver/                FastAPI + paddltir_solver package + pytest
supabase/              migrations, seed, tests (pgTAP)
fixtures/              golden JSON
docs/superpowers/      specs, plans
PROGRESS.md
```

## 10. Out of scope (v1)
Recurring sessions, regatta entity, results/timing, messaging, Android, full
offline authoring/conflict resolution, paid plans.

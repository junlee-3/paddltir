# Plan 5 — execution ledger (SDD)

> Verbatim copy of the git-ignored SDD ledger + the final-review fix brief, kept for the record.
> Plan: `2026-08-26-plan-5-paddler-pwa.md`. Merge: 243b6c3 (head d8bf369).

## Go-live checklist for Jun (needs your credentials — nothing here was run)
1. Supabase hosted project `paddltir` (ap-southeast-2): `supabase link` + `supabase db push` (all migrations incl. realtime
   publication); Auth → Site URL `https://paddltir.vercel.app`, Redirect URLs `https://paddltir.vercel.app/**` (+ the app's
   `paddltir://auth/callback`); SMTP provider for magic links (local uses Mailpit); confirm `enable_confirmations` policy.
2. Vercel project `paddltir` (Hobby): import the repo; `vercel.json` already declares services `web` (Next) + `solver` (FastAPI);
   env for `web`: `NEXT_PUBLIC_SUPABASE_URL`, `NEXT_PUBLIC_SUPABASE_ANON_KEY` (publishable key), `NEXT_PUBLIC_SITE_URL`;
   do NOT set `NEXT_PUBLIC_PADDLTIR_DEV_LOGIN`. Solver env per `solver/README.md`.
3. Coach app: swap `apple/Sources/App/Secrets.swift` to the hosted URL + anon key (git-ignored); SIWA/magic-link need a signed build.
4. Smoke on hosted: sign in by magic link as a real paddler; `/` shows the next event; install to Home Screen on iPhone; toggle
   availability; log an erg; check the coach app sees the change (sync) and the PWA sees a lineup edit live (Realtime).
5. Optional: Lighthouse PWA audit; Vercel Analytics; custom domain.


## Ledger

# SDD ledger — plan: docs/superpowers/plans/2026-08-26-plan-5-paddler-pwa.md

Spec: docs/superpowers/specs/2026-08-22-paddltir-design.md §4/§5/§7/§8/§9 (read). Visual authority: docs/design/direction.md.
Worktree: `.worktrees/plan-5-pwa` (branch `plan-5-pwa`) — create from main AFTER Plan 4h merges. Local Supabase stack must be up + `seed_dev.sql` loaded.

## Pre-flight scan (2026-08-26, before Task 1)
| Pair | Produces → consumes | Finding |
|---|---|---|
| T1→T2 | `app/page.tsx` placeholder → `git mv` to `(app)/page.tsx`; `ui.tsx` (Card/MicroLabel/PrimaryButton/SegmentedControl/Pill); vitest include `lib/**/*.test.ts` | consistent — T2 tests live under `lib/auth/` |
| T2→T3 | `getViewer()/Viewer/OwnPaddler`, `createClient()`, `(app)/layout.tsx` gate, `createBrowserClient()` | consistent; `viewer.paddler!` safe behind the gate |
| T3→T4 | `setAvailability(sessionId,status)` + `AvailabilityToggle(sessionId,value,label)`; `(app)/actions.ts` extended (imports `parseErgSubmission`, `CLUB_TZ` added in T4) | consistent |
| T3→T6 | migration `20260826000600_realtime.sql` + pgTAP `007` → `supabase test db` in T6 gate | consistent |
| T1/T2→T5 | `layout.tsx` gains SW/nudge mounts + `icons.apple`; `proxy.ts` matcher + `isPublicPath` already exclude `/icons/`, `/sw.js`, `/manifest.webmanifest`, `/offline` | consistent |
| T2/T3/T4→T6 | Playwright selectors: `getByLabel("Password")` (dev form aria-label) · radiogroup "Availability for Tuesday training" · link /Sydney Regatta/ · heading "Premier Mixed 200m" · Pill text "Bench 1 left" · tile label "Bench 1 left: Lily (you)" · tab "Final" · "Not in this heat" · label "Metres (1 min)" · `role=status` "Saved 555 m." · "Signed in as lily@paddltir.dev" · `link[rel=manifest]` | one defect: `getByText("555 m")` matched two nodes → **Ruling P1** below |
| each task | self-consistency (tests vs code, files created vs touched) | T1 boat maths matches Boat.swift (10: 1/2–3/4–7/8–10; 5: 1/2/3/4–5); T2 `safeNext`/`isPublicPath` tests match impl; T3 `event.test.ts` imports `paddlerIds` (fixed from a `require`); T4 erg/sparkline tests match; T5 nudge test matches |

Rulings:
- P1: `e2e/smoke.spec.ts` uses `getByText("555 m", { exact: true })` — the status line "Saved 555 m." would otherwise also match (Playwright strict mode). Plan patched.
- P2: `.env.local` may use either the legacy `ANON_KEY` JWT or `PUBLISHABLE_KEY` (`sb_publishable_…`) from `supabase status`; never `SECRET_KEY`/`SERVICE_ROLE_KEY`.
- P3: Task 1 runs `create-next-app@latest` with `--yes` (Next 16.3 verified 2026-08-26 → `proxy.ts`); if a `src/` dir appears, flatten it before continuing (plan says so).
- P4 (dispatch policy): T1 cheap-tier is tempting but the scaffold needs judgment on generated files → sonnet for every task; reviewers sonnet; final review fable.

## Task log
(none yet — start at Task 1 after 4h merges)

Worktree created: .worktrees/plan-5-pwa (branch plan-5-pwa from main 9ee71a0) — project convention (.worktrees/, git-ignored) used instead of the native EnterWorktree tool so the controller session stays on main for docs. pgTAP baseline run before Task 1 (see below).
Baseline: pgTAP FAILED on the dirty local DB (leftover clubs from gated live tests → multi-row subquery in 004/006); `supabase db reset` → pgTAP 98/98 PASS; demo seed reloaded.
Ruling P5: `psql` is not on this shell PATH — load the seed via `docker exec -i supabase_db_paddltir psql -U postgres -d postgres < supabase/seed_dev.sql` (carry into every dispatch + fix the README/plan text in Task 6).
Task 1: dispatched (sonnet) BASE=9ee71a0.
P5 amended: psql exists at /opt/homebrew/opt/libpq/bin/psql (off PATH) — use that full path or the docker exec form; seed reload verified (24 paddlers / 3 heats / 1 club).
Task 1: IMPLEMENTED at c40711a (DONE_WITH_CONCERNS — all observations: scaffold .gitignore fixed to allow .env.example; comment wording; harmless Vite configLoader notice) — vitest 4/4, typecheck/lint/build clean; next 16.3.3 / react 19.2.8 / tailwindcss 4.3.3 / vitest 4.1.11. Implementer agent ac7f30e7b783a90f3 (sonnet). Review dispatched (sonnet), package 9ee71a0..c40711a.
PRE-VERIFIED for T2/T3: `supabase gen types typescript --local --schema public` succeeds (29.8 KB); Views.paddlers_public present (all columns nullable — T3 mapper guards `if (p.id && p.name)`); Functions.join_club Args { p_code: string; p_paddler_id?: string } (undefined omits → default null); claimable_paddlers present; Enums availability_status/boat_side/boat_size/erg_source/session_kind as the plan assumes.
Task 1: complete (commit c40711a, review Approved — Sonnet; Minor: scaffold README mentions Geist → Task 6 rewrites README)
Task 2: dispatched (sonnet) BASE=c40711a; carries P2 (key), P5 (psql path), gen-types pre-verification, proxy.ts config-name check.
PRE-VERIFIED for T3: pg_publication has supabase_realtime (puballtables=f, 0 tables) on the local stack → `alter publication supabase_realtime add table sessions, heats, seats, heat_reserves, availability` is valid; pgTAP 007 expects exactly those 5.
PRE-VERIFIED for T5/T6: registry sharp 0.35.3, @playwright/test 1.62.1 (matches the installed CLI 1.62.1); ~/Library/Caches/ms-playwright already holds chromium-1208 + headless shells → `playwright install chromium` is fast/offline-ish.
Task 2: IMPLEMENTED at 7eb0daa — 23 vitest, gate clean; manual: 307→/login, dev sign-in 303 + cookie, GET / 200, signout 303; join flow live (Mailpit + RPCs). Concern: one cold-start 307→/join on the first authenticated request (self-resolved) — reviewer asked to assess getViewer/proxy ordering. Implementer agent a80f837cc8b34bd1b (sonnet). Review dispatched (sonnet), package c40711a..7eb0daa.
Task 2: review (sonnet) = Needs fixes — 1 Important: getViewer discards query `error` → misroutes to /join on any query failure (brief defect; matches the cold-start flake).
Ruling P6: getViewer throws on query error (assertNoQueryError helper + test); error boundaries `(app)/error.tsx` + `join/error.tsx` via a shared components/ErrorState.tsx; cold-start GET / repeated 3× to observe. Fix round 1: same implementer resumed. Then scoped re-review (sonnet).
Task 2 fix round 1: IMPLEMENTED at 7f3e49a — 25 vitest, gate clean; cold-start flake root-caused (transient "JWT issued at future" clock skew from the local auth container) — now surfaces as a 500/error boundary instead of a silent /join.
Ruling P7: root `web/app/error.tsx` added beyond the literal two files — required because a segment error.tsx cannot catch its own layout.tsx throw (getViewer runs in (app)/layout.tsx). Accepted.
Task 2: scoped re-review dispatched (sonnet), package 7eb0daa..7f3e49a.
Task 2 re-review round 1 (sonnet): finding Addressed; NEW Important — Next 16 error boundaries must call `retry()` (refreshes the RSC payload) rather than bare `reset()` after a server-component throw; P6 literally said reset() → ruling P8: ErrorState calls `(retry ?? reset)()`; all three error.tsx pass `retry` through. Fix round 2: same implementer resumed. Then scoped re-check (sonnet).
PRE-VERIFIED for T3 (live, as lily@paddltir.dev via PostgREST): `races?select=id,name,boat_size,sort_order,crews(name),heats(id,name,sort_order,drummer_id,sweep_id,seats(bench,side,paddler_id),heat_reserves(paddler_id))` → 1 race, crews.name "Premier Mixed", heats Heat 1 (20 seats, 2 reserves), Heat 2 (0), Final (0), drummer ids present; paddlers_public readable; sessions = [training "Tuesday training", race_day "Sydney Regatta"]. Nested-order note: heats came back in sort_order without an explicit referencedTable order — T3 still sorts in toRaceViews.
Task 2 fix round 2: IMPLEMENTED at 46555f1 (retry ?? reset in ErrorState + all three error.tsx; verified against next/dist error-boundary.js + bundled docs). Scoped re-check dispatched (sonnet), package 7f3e49a..46555f1.
Task 2: complete (commits 7eb0daa + 7f3e49a + 46555f1; 2 fix rounds — P6 query errors surfaced, P8 retry() — re-check Approved; 25 vitest)
Task 3: dispatched (sonnet) BASE=46555f1; carries P5 (psql path), the embed/publication pre-verifications, and a realtime-evidence rule (Node script subscriber + psql update) since no browser automation is available.
NOTE: controller live RLS pre-check (availability upsert / self erg insert / display_name) collided with T3's `supabase db reset` (401 + "database system is shutting down") — deferred; stay off the local DB while T3 runs. Re-run after T3 reports (or rely on T6 Playwright smoke + static RLS reading in the T4 review).
Task 3: IMPLEMENTED at 1426ee4 — vitest 34 (7 files), pgTAP 100/100 incl. 007_realtime, realtime seats UPDATE event received as Lily, curl page assertions on / and /session/[id] all matched; availability upsert verified under Lily RLS via PostgREST (covers the deferred controller pre-check for availability). Concerns: brief's psql demo update conflicted with seed occupancy (bench 5 left occupied) → swap transaction used; server actions not POSTable from curl (expected). Implementer agent abe22a3c7bcd54fc0 (sonnet). Review dispatched (sonnet), package 46555f1..1426ee4.
PRE-VERIFIED for T4 (live as lily via PostgREST): erg_tests self insert (source=self, recorded_by=auth.uid) → 201; source=coach → 403; own history readable (2 coach + 1 self); profiles.display_name PATCH → 204 (reverted); clubs name readable. Test row deleted via container psql; seed intact (2 erg rows for Lily).
Task 3: complete (commit 1426ee4, review Approved — Sonnet; Minors inherited from the brief: `as unknown as RaceRow[]` cast (a `.returns<RaceRow[]>()` would be idiomatic), raw `.micro` span in the reserves line — no action)
Task 4: dispatched (sonnet) BASE=1426ee4; carries the T4 RLS pre-verification (self erg 201 / coach 403 / display_name 204) and the curl-evidence rule for server actions.
Task 4: IMPLEMENTED at a582823 — vitest 38 (+4), gate clean; curl assertions on /availability /erg /profile matched; writes verified via PostgREST under Lily (555 m self row appeared, coach-source 403, profile PATCH 204), seed restored. Note for T6: React SSR inserts `<!-- -->` text-node markers, so raw-HTML greps can miss "520 m" — Playwright DOM text is unaffected. Implementer agent a8a8190683a77a2af (sonnet). Review dispatched (sonnet), package 1426ee4..a582823.
Task 4: complete (commit a582823, review Approved — Sonnet; 0 findings; P6 applied to all three page reads)
Task 5: dispatched (sonnet) BASE=a582823; carries sharp 0.35.3 pre-check, `pnpm start` curl verification, production-only SW registration.
Task 5: IMPLEMENTED at 520e992 — vitest 41 (+3), gate clean; prod-build curls: manifest JSON (name Paddltir, 3 icons), sw.js headers no-cache + Service-Worker-Allowed, icon-512 200, /offline copy. Deviation: scoped eslint-disable react-hooks/set-state-in-effect in InstallNudge (new error-level rule in eslint-config-next 16.3.3) — reviewer to weigh vs an idiomatic alternative. Implementer agent a6e3bb7eab359976a (sonnet). Review dispatched (sonnet), package a582823..520e992.
Ruling P9 (Task 6 docs): the implementer must NOT edit PROGRESS.md or the plan doc inside the worktree (brief Step 4) — the controller has been editing PROGRESS.md on main throughout and owns the merge-time docs (PROGRESS bullet, roadmap/plan ticks, execution-ledger copy). Task 6 commits only web/, vercel.json, web/README.md. — avoids a guaranteed PROGRESS.md merge conflict — costs nothing if wrong.
Task 6 dispatch notes: e2e first authenticated navigation wrapped in expect.toPass (local auth clock-skew flake, see memory); PADDLTIR_LIVE_SUPABASE=1 pnpm e2e must pass with the demo seed loaded; README replaces the scaffold text (Geist mention) and uses the libpq psql path.
PRE-VERIFIED for T6 (read-only psql): seed intact — Lily availability(training)=in, erg rows=2 (coach), display_name=Lily, seat Heat 1 bench 1 left, heats=3, clubs=1, self erg rows=0.
Task 5: complete (commit 520e992, review Approved — Sonnet; Minors: scoped eslint-disable judged the correct choice; SW static VERSION → unbounded same-cache growth across deploys (brief design; future task: bump VERSION per build))
Task 6: dispatched (sonnet) BASE=520e992; carries P9 (no PROGRESS/plan edits in the worktree), P5 (psql path), the clock-skew retry note, the seed-state check, browser cache note.
Task 6: IMPLEMENTED at d4db93a — vitest 41, e2e skip-mode 1 skipped, e2e live 1 passed (3 clean runs), pgTAP 100/100 after reset+reseed. Test-only deviations: waitForURL after the dev sign-in click (server-action transition race); "555 m" assertion scoped to the history <li> (the Trend card "Best 555 m" also matched — P1 did not foresee it). Implementer agent ae3139d06baf06335 (sonnet).
Ruling P10: both smoke deviations accepted (app code unchanged; selectors match the reviewed app).
Task 6: review dispatched (sonnet), package 520e992..d4db93a.
Post-smoke check (read-only): seed intact (Lily in / 2 erg / display_name Lily / Heat 1 bench 1 left / 3 heats / 1 club / 0 self rows); port 3000 free.
FINAL whole-branch review dispatched (fable) on 9ee71a0..d4db93a (slim package, 112 KB) in parallel with the Task 6 task review — Task 6 touched only tests/config/README, so the app-code review subject is stable; any Task 6 fix commit will be folded into the final fix-wave re-review range.
Task 6: complete (commit d4db93a, review Approved — Sonnet; Minor: skip-mode `pnpm e2e` still starts/stops `next dev` (Playwright WebServerPlugin runs before test filtering) → README caveat in the final fix wave). ALL SIX TASKS COMPLETE. Awaiting FINAL review (fable).
FINAL REVIEW (fable) on d4db93a: "With fixes" — 0 Critical; 6 Important: (1) safeNext accepts `/\evil.com` → open redirect (WHATWG `\`→`/`); (2) fetchEvent swallows availability + paddlers_public read errors (P6; plan code); (3) next event uses gte(now) → today's race day vanishes once it starts (plan gap); (4) AvailabilityToggle state never follows the server after router.refresh(); (5) BoatDiagram aria-label on role-less divs is ignored by screen readers; table semantics wrong; (6) updateDisplayName swallows errors, no feedback. Minors: join error double-decode + raw PG text; signOut global scope; RaceCard deleted-heat fallback; session id validation; erg "1e3"/Feb-30; contrast/micro/font-mono/shadow; h1s; nudge on /login; e2e exact/await; README skip-mode caveat.
Rulings W1–W9 in final-fix-brief.md: W1 safeNext hardening + tests; W2 P6 on both reads; W3 startOfTodayISO (CLUB_TZ) anchors the upcoming query + relativeDay midnight/DST tests; W4 key AvailabilityToggle on value; W5 real table/row/cell semantics, reserves outside, .micro labels; W6 NameState feedback; W7 accepted Minors (join messages via pure joinErrorMessage, signOut local, RaceCard fallback, UUID guard, erg digits + calendar validity, design fixes, h1s, nudge → (app) layout, e2e exact/await, README caveat); W8 whereAmI precedence test; W9 deferred (arrow keys, next typegen, preview deploy validation, in-browser realtime e2e, SW VERSION, CLUB_TZ column). ONE fix dispatch (sonnet) → scoped re-review (fable).
Final fix wave: dispatched (sonnet) BASE=d4db93a.
Final fix wave: IMPLEMENTED at 8a601f0 — vitest 57 (11 files), e2e live 1 passed ×2, skip 1 skipped, pgTAP 98/98 (ran from MAIN → 6 files; local DB reset WITHOUT the realtime migration — merged gate must reset from merged main first). Concern: W3 DST-start expectation in the brief was WRONG (Sydney DST begins 02:00 → midnight 2026-10-04 is +10:00) → Ruling W10: exact local midnight for all days incl. both transitions; tests corrected; implementer resumed for one more commit. Concern 3 (`!viewer.user` guard) accepted.
W10: IMPLEMENTED at bde8d53 — vitest 58 (11 files), gate clean. Scoped re-review dispatched (fable), package d4db93a..bde8d53 (slim).
Scoped re-review (fable) on bde8d53: W1–W10 all Addressed; NEW Important from the W1 algorithm as ruled — dot-segment normalisation turns `/.//evil.com` into `//evil.com` (protocol-relative redirect via /login redirect()); Minors: aria-hidden spacers in cap rows; key-remount mid-transition note. Ruling W11: post-parse output guard (`//` / `/\`) + 4 tests + spacer aria-hidden. Same agent resumed (fix round 2 of the wave). Then a scoped re-check (sonnet).
W11: IMPLEMENTED at d8bf369 — vitest 60 (+2), gate clean. Scoped re-check dispatched (sonnet), package bde8d53..d8bf369.
W11 re-check (sonnet): Addressed; 20/20 probes on-site; Ready to merge = Yes. MERGING.


## Final-review fix brief (rulings W1–W9; W10/W11 in the ledger)

# Plan 5 — final-review fix wave (ONE dispatch)

Branch `plan-5-pwa`, base for this wave: `d4db93a`. Worktree: `/Users/junlee/Documents/programming/paddltir/.worktrees/plan-5-pwa`. All paths below are under `web/`.
Every item is a controller ruling (W1–W9) on a final-review finding. Implement all of them; nothing else. App conventions stay: Server Components by default; `"use client"` only where already used; tokens only (no raw hex); `&apos;` for apostrophes in JSX; server actions derive ids server-side; P6 (query errors surface via `assertNoQueryError`) everywhere.

## W1 — `safeNext` closes the backslash open redirect (Important 1)
`lib/auth/paths.ts`: WHATWG URL treats `\` as `/`, so `/\evil.com` resolves to `https://evil.com/`. New rule — accept ONLY when all hold: `raw` starts with `/`; second char is neither `/` nor `\`; `raw` contains no `\` and no `%5c`/`%5C`; and `new URL(raw, "http://x").origin === "http://x"`. Return `u.pathname + u.search` (drop any hash) on success, else `"/"`.
Tests (`lib/auth/paths.test.ts`): add `"/\\evil.com"`, `"/\\/evil.com"`, `"/%5Cevil.com"`, `"/%5cevil.com"`, `"https://evil.example"`, `"//evil.example"` → `"/"`; keep `"/erg"` and `"/session/abc?x=1"` passing; `"/erg#frag"` → `"/erg"`.

## W2 — Two swallowed reads in `lib/data/sessions.ts` (Important 2, P6)
In `fetchEvent`: the `availability` read (training branch) and the `paddlers_public` read (race branch) must destructure `error` and call `assertNoQueryError("availability", error)` / `assertNoQueryError("paddlers_public", error)` before using `data`. (The `sessions`/`races` reads already `throw error` — leave them.)

## W3 — "Next event" keeps today's event after it starts (Important 3)
`lib/time.ts`: add `export function startOfTodayISO(nowISO: string): string` — midnight of `now`'s calendar day in `CLUB_TZ` as an ISO string with the correct Sydney offset (compute the `YYYY-MM-DD` via the existing `ymd` formatter, then build the instant: find the offset by formatting `new Date(`${ymd}T00:00:00Z`)` parts in `CLUB_TZ` or use a small loop; simplest correct approach: iterate `Date.UTC(y, m-1, d, h)` for `h` in [-14..14] and pick the one whose `ymd`/hour in `CLUB_TZ` is that date at 00:00 — write it clearly and test it).
Tests: `startOfTodayISO("2026-09-04T23:30:00+10:00")` → `"2026-09-04T00:00:00+10:00"` instant (compare by `Date.parse`); `startOfTodayISO("2026-10-04T06:00:00+11:00")` (DST) → `2026-10-04T00:00:00+11:00`; `startOfTodayISO("2026-09-04T13:59:00Z")` (= 23:59 Sydney) → `2026-09-04T00:00:00+10:00`.
`app/(app)/page.tsx` and `app/(app)/availability/page.tsx`: `fetchUpcomingSessions(supabase, startOfTodayISO(nowISO), …)` so a race day stays on `/` and in `/availability` for its whole calendar day; `relativeDay` still uses `nowISO`. Add `relativeDay` tests around Sydney midnight and the DST switch: now `2026-09-04T23:59:00+10:00` vs event `2026-09-05T00:10:00+10:00` → "Tomorrow"; now `2026-10-03T23:30:00+10:00` vs `2026-10-04T06:00:00+11:00` → "Tomorrow" (fix the implementation if either fails).

## W4 — `AvailabilityToggle` follows the server after a realtime refresh (Important 4)
`components/AvailabilityToggle.tsx`: `useState(value)` seeds once, so a coach-side change re-rendered by `router.refresh()` never shows. Fix at the two call sites (`EventView.tsx`, `availability/page.tsx`): `key={`${sessionId}:${value ?? "none"}`}` so the control remounts when the server value changes (optimistic updates keep working between refreshes). Add a one-line comment on the component explaining the key contract.

## W5 — Boat diagram seat labels reach screen readers (Important 5)
`components/BoatDiagram.tsx`: `aria-label` on a role-less `<div>` is ignored by VoiceOver/NVDA. Make the grid real: container `role="table"` + `aria-label` (keep); each bench row `role="row"` with THREE `role="cell"` children (left tile, the bench-number/section column, right tile); the drummer and sweep rows are `role="row"` containing a single `role="cell"` tile (wrap the tile in the row; keep the centred layout); `Tile` renders `role="cell"` + the SAME `aria-label` strings as today (`"Bench 1 left: Lily (you)"`, `"Drummer: Dee Drummer"`, `"…: empty"`); the reserves `<p>` moves OUTSIDE the `role="table"` element (sibling after it). Also lift the bench section micro-label from `text-[9px]` to the `.micro` class (11px) and widen the middle column (`3.25rem` → `4rem`) so it fits. Playwright's `getByLabel(...)` selectors keep working (aria-label on `role="cell"` is valid).

## W6 — `updateDisplayName` reports success/failure (Important 6)
`app/(app)/actions.ts`: `updateDisplayName(prev: NameState, formData): Promise<NameState>` with `type NameState = { status: "idle" } | { status: "saved" } | { status: "error"; message: string }`; empty name → error "Enter a display name."; use `assertNoQueryError`-style handling: on Supabase `error` return `{ status: "error", message: "Couldn't save — try again." }`; success → `revalidatePath("/profile")` + `{ status: "saved" }`. `profile/DisplayNameForm.tsx`: `useActionState`, `role="status"` "Saved." / `role="alert"` message, pending state on the button.

## W7 — Accepted Minors in files this wave already touches (do all)
- `app/join/page.tsx`: drop `decodeURIComponent(error)` (Next already decodes); map known RPC messages to copy: `invalid invite code` → "That code isn&apos;t valid.", `paddler not claimable` → "That name has already been claimed — pick another or ask your coach.", `already in another club` → "You&apos;re already in another club.", anything else → "Couldn&apos;t join — try again."; do this in a pure `lib/auth/joinError.ts` `joinErrorMessage(raw: string | undefined): string | null` with a 4-case test.
- `app/auth/signout/route.ts`: `signOut({ scope: "local" })`.
- `components/RaceCard.tsx`: `const heat = race.heats.find(...) ?? race.heats[0] ?? null` and reset `heatId` when it no longer exists (derive: `const heatId = race.heats.some(h => h.id === selected) ? selected : race.heats[0]?.id`).
- `app/(app)/session/[id]/page.tsx`: validate `id` with a UUID regex before querying; invalid → `notFound()`.
- `lib/erg.ts`: metres must match `/^\d+$/` (no `1e3`/`0x`); date must be a real calendar date (round-trip `y/m/d` through `Date.UTC`); tests for `"1e3"` → error and `"2026-02-30"` → error.
- Design: `ErgForm.tsx` saved message `text-ink font-semibold` (drop `text-good` text — contrast); `JoinForm.tsx` remove `font-mono` (Inter Tight only; keep `tracking-widest uppercase`); `InstallNudge.tsx` `shadow-lg` → `border border-border` (hairline depth); `/login` and `/join` headlines become `<h1>`.
- `InstallNudge` mounts in `app/(app)/layout.tsx` (not the root layout) so it never shows on `/login`/`/join`; `RegisterServiceWorker` stays in the root layout.
- `e2e/smoke.spec.ts`: `getByRole("link", { name: "Erg", exact: true })` and `"Profile"` likewise; after the final "In" click, `await expect(group.getByRole("radio", { name: "In" })).toHaveAttribute("aria-checked", "true")` before navigating; README: add the caveat that skip-mode `pnpm e2e` still boots and tears down `next dev` (Playwright starts `webServer` before test filtering).

## W8 — Tests the review asked for (add)
- `lib/lineup.test.ts`: `whereAmI` precedence — a paddler who is both drummer and seated → `{ kind: "seat", … }` (seat wins), and `toRaceViews` still shows the drummer name.
- (W1, W3, W6-adjacent, W7 tests as listed above.)

## W9 — Deferred (do NOT do now)
Arrow-key navigation for heat tabs / segmented radios; `next typegen` in CI; preview-deploy validation of `vercel.json`; in-browser realtime e2e; SW `VERSION` per build; `CLUB_TZ` as a club column.

## Gate
From `web/`: `pnpm typecheck && pnpm lint && pnpm test && pnpm build`; then `PADDLTIR_LIVE_SUPABASE=1 pnpm e2e` (local stack up, seed intact; the smoke restores the seed) — 1 passed; then `pnpm e2e` without the flag — 1 skipped. From the repo root: `supabase test db` (100; if dirty: `supabase db reset` → test → reseed with `/opt/homebrew/opt/libpq/bin/psql "postgresql://postgres:postgres@127.0.0.1:54322/postgres" -f supabase/seed_dev.sql`). No dev server left on :3000.
Commit as ONE commit: `fix(web): final-review wave — safeNext backslash redirect, P6 reads, today-anchored next event, toggle follows server, boat-diagram semantics, display-name feedback, join/erg/signout polish` with the trailers:
Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_014jeZcQK2MeLkeExLWsA6ov
Report to `/Users/junlee/Documents/programming/paddltir/.superpowers/sdd/2026-08-26-plan-5-paddler-pwa/final-fix-report.md` (per item W1–W8: what changed, the covering test, RED/GREEN for new tests, the gate + e2e + pgTAP output).

MERGED to main as 243b6c3 (no-ff). Merged-tree gate on main: pnpm install frozen OK; typecheck OK; lint OK; vitest 60/60 (11 files); build OK; e2e skip-mode 1 skipped; supabase db reset (merged migrations incl. realtime) → pgTAP 100/100 (7 files) → demo reseeded → e2e live 1 passed; seed restored (0 self erg rows, 1 club); port 3000 free. Worktree/branch/workspace removed after preserving artifacts.

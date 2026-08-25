# PROGRESS.md — Paddltir

> Source of truth across sessions. After any compaction: re-read this file and the
> implementation plan (docs/superpowers/plans/) BEFORE anything else.

## Current phase
**Building the SwiftUI coach app (Plan 4). Foundation + data + auth + Schedule + Crews/Squad + Lineup editor MERGED; next = coach-app integration & polish (4g).**

MERGED TO MAIN:
- Phase 1 (backend/algorithms): PaddltirCore (Swift, 56 tests) · solver (Python HiGHS MIP, 25 tests) ·
  supabase (98 pgTAP, 3 opus security reviews) · cross-language golden fixtures · vercel.json.
- **Plan 4a — Coach app FOUNDATION (commit ac2b8ea).** apple/ XcodeGen app (iOS26+macOS26), PaddltirCore
  linked, Inter Tight bundled (OFL), full enhanced-CrewCoach design system (17 colour tokens, Inter Tight
  type scale, primitives + domain components: SeatTile/TelemetryGrid/BalanceBeam/HeatSwitcher/AvailabilityRing),
  Design System gallery (screenshot verified vs concept), real Liquid Glass, LIGHT MODE ENFORCED. Builds
  iOS+macOS, reproducible from apple/project.yml. Final review clean.
- **Plan 4f — Lineup editor, the hero (commit 3edcc81).** The lineup editor over PaddltirCore + GRDB.
  ENGINE (fully TDD, 92 tests): LineupRepository saveHeat/createHeat/heats(raceId:) (drummer/sweep persistence,
  the 4b/4d carry-forward); LineupViewModel (@MainActor) — loads a heat's PlacementRequest+Heat, holds a
  PaddltirCore.Lineup + tap selection + undo stack; tap-to-place/swap, unseat, undo, reserves (erg-desc), save
  (lineup→SeatRows via saveSeats + drummer/sweep via saveHeat); live metrics via Scoring.evaluate, beamImbalance,
  Auto-fill via Greedy, Suggest via Suggestions.swaps — ALL seat/balance/placement logic delegates to PaddltirCore,
  nothing reimplemented. UI: HullGrid (SeatTile rows, section labels, tap), LineupEditorView (glass HeatSwitcher +
  hull + Balance HUD via GlassBar/TelemetryGrid/BalanceBeam + reserves chips + glass toolbar Suggest/Auto-fill/Undo),
  wired from RaceDayDetailView via RaceHeatLoader (opens first heat or creates "Heat 1"). Gated live e2e verified.
  DEBUG deep-link (PADDLTIR_DEBUG_OPEN_FIRST_HEAT/AUTOFILL) for screenshots. Final review clean (Ready to merge: Yes).
  **NO editor screenshot** captured: the auto-capture reached the editor but the globally-first SEED heat has an
  incomplete race→crew→members chain → placementRequest nil → editor spins (a seed-data gap + a real polish gap:
  no empty/error state). Editor is otherwise proven by the 92-test engine + built on already-screenshotted 4a components.
  **4g carry-forward (editor polish):** seat drag+haptics+animations; Optimise (server MIP, go-live/Plan 6); Share
  snapshot; multi-heat switcher nav (HeatSwitcher "+" currently inert); redo; long-press lock/drummer/sweep menu;
  section-band shading; empty/error state when placementRequest nil; GenderBadge reuse; two-empty-seat swap no-op
  guard; "unavailable today" reserve dimming; heats(raceId:) test; Mac centred-hull + right-inspector layout.
- **Plan 4e — Crews & Squad (commit 1d8dbca).** SQUAD: searchable/sortable/filterable roster (SquadView over
  SquadViewModel + pure SquadQuery/GenderTally); paddler detail (fields, erg-history sparkline via Swift Charts,
  invite/link status, archive) + create/edit form (SquadRepository.upsert); SquadRepository.ergHistory added.
  CREWS: crew cards (CrewsView over CrewRepository.summaries — member count + soonest-future race); crew detail
  (members with chips, IDBF gender-rule check reusing PaddltirCore.GenderRule.violation for (category, standard),
  add/remove-from-squad via setMembers, races) + create-crew form; CrewRepository createCrew/racesForCrew/summaries.
  Both placeholders replaced; 84 tests; gated live e2e verified vs seed; Squad+Crews screenshots surfaced. DEBUG
  PADDLTIR_DEBUG_TAB env selects the launch tab (screenshots). Final review clean (Ready to merge: Yes).
  **4f/4g carry-forward:** CrewDetailModel gender-rule-verdict unit test; guard SquadView add-sheet on non-empty
  clubId (falls back to "" today); boat-size-specific gender check (4f); surface side/gender/role squad filter chips.
- **Plan 4d — Schedule & availability (commit 3b13bf6).** Schedule tab: up-next glass hero (with headcount),
  day-grouped timeline, past collapsed, `+` create menu → SessionFormView (training/race-day); TrainingDetailView
  (availability list + coach override write + record-erg quick action); RaceDayDetailView (races list + day
  headcount + add-race; race → LineupEditorPlaceholder nav stub for 4f). Data: ScheduleRepository writes
  (createSession/setAvailability[upsert]/createRace) + SquadRepository.recordErg, each atomic mutation+Outbox in
  one db.write; `upcomingSessions()`→`sessions()`. Pure Headcount + ScheduleGrouping (day-bucket, up-next,
  upcoming/past; now-injected, unit-tested). ScheduleViewModel composes it. 76 tests; gated live onboarding+sync
  e2e VERIFIED vs local stack. Screenshot surfaced (real seed data). Final review caught + fixed an up-next
  duplication bug (hero + list). DEBUG auto-sign-in launch hook + DEBUG in-memory AuthLocalStorage (gated on
  PADDLTIR_DEBUG_AUTOSIGNIN) enable signed-in screenshots in the unsigned sim.
  **4g DEFERRALS:** screens load once via `.task` and do NOT reload when background AppEnvironment.sync() finishes
  (add a sync-completion refresh / GRDB observation); ScheduleViewModel.load() lacks a re-entrancy guard; per-paddler
  availability NOTE editing is read-through only; erg `recordedBy` passed nil (wire to current coach). Also still
  open: MainShell tabs not wrapped in NavigationStack (so child `.navigationTitle` no-ops); heat drummer/sweep
  persistence (4e — no repo writes `heats`). Plus the 4c deferred-polish list (.dsMono token, teal placeholder, etc).
- **Plan 4c — Auth & onboarding (commit cd2579b).** 3-state AuthState gate over RootView driven by
  SessionController (subscribes to supabase-swift authStateChanges, resolves club via ClubService);
  AppModel composition root shares ONE SupabaseClient between sync (AppEnvironment, now @MainActor) and auth.
  ClubService wraps create_club/join_club/claimable_paddlers/regenerate_invite_code (decode via PostgREST.decoder
  / .execute().data, never .value). AuthView (Sign in with Apple + email magic link + DEBUG dev sign-in),
  OnboardingView (create club / join-with-code + claim-your-name), SettingsView (invite code + ShareLink +
  regenerate, category rules read-only, sign out). 66 tests; the gated live onboarding round-trip
  (signUp→create_club→8-char invite→join_club) VERIFIED PASS against the local stack. iOS+macOS build.
  **SIWA + magic-link functional verification DEFERRED to a signed go-live build** (entitlements need code
  signing, which is off for the unsigned CI/sim build; magic link needs SMTP + deep-link redirect) — both are
  built and render, just not runnable unsigned. AuthView screenshot surfaced to Jun.
  DEFERRED POLISH (do in 4d/4e or a Settings pass): add a `.dsMono` typography token (SettingsView currently
  uses the one sanctioned Font.system for the invite code); wrap MainShell tabs in NavigationStack (so
  `.navigationTitle` renders + placeholders get nav chrome); surface errors in SettingsView.load()/regenerate()
  (currently `try?`-swallowed); drive the post-onboarding gate flip from createClub's returned Club (more robust
  than re-querying); email-field placeholder renders teal (RootView `.tint` bleed) → make it muted grey;
  reorder DEBUG Design tab after Settings. NOTE: `@MainActor AppEnvironment` + `sync()` wired into RootView
  (`.task` + scenePhase `.active`) — the 4b carry-forward is DONE.
- **Plan 4b — Data layer & sync (commit a7e83d2).** Row models (snake_case Codable) + GRDB local store &
  migrations; PostgREST date pipeline (wire→model→GRDB, never raw); DomainMapping to PaddltirCore; offline
  sync (pull-since / outbox / LWW=outbox-wins-until-pushed); Squad/Crew/Schedule/Lineup repositories
  (LineupRepository.placementRequest walks heat→race→crew→members→category_rule→seats into a PlacementRequest).
  59 tests, live Supabase smoke gated behind PADDLTIR_LIVE_SUPABASE. Final review caught 3 cross-cutting
  bugs — all fixed pre-merge: outbox deletes now route to RemoteStore.delete (were resurrecting via upsert);
  drain in parent-first order (was nondeterministic FK-wedge); clubID caches only on success (was dead-ending
  post-sign-in sync); + outbox collapses to net op per PK. **SETUP GOTCHA:** `Secrets.swift` is git-ignored,
  so a fresh checkout / new worktree needs it copied from `Sources/Data/App/Secrets.example.swift` before the
  app compiles (README documents it).

VISUAL DIRECTION (APPROVED by Jun): enhanced CrewCoach — slate-on-white, hairline borders, green=Male
(#DCFCE7/#86EFAC) / amber=Female (#FEF3C7/#FCD34D) tiles + emerald(#059669)/red(#DC2626) verdicts KEPT;
teal #0D7377 accent; Inter Tight sans (NO serif); LIGHT ONLY; Liquid Glass on floating chrome; 12px cards.
Tokens: docs/design/direction.md. Concept: docs/design/concepts/coach-app-concepts.html (artifact published).

BUILD MECHANICS (learned): XcodeGen (apple/project.yml → run `xcodegen generate` before each build);
`.xcodeproj`/`DerivedData`/`screenshots` are git-ignored; build gate = `xcodebuild -scheme Paddltir
-destination 'platform=iOS Simulator,name=iPhone 17 Pro' -derivedDataPath DerivedData build/test`;
UI verify = boot iPhone 17 Pro sim + `xcrun simctl io ... screenshot`. Real Liquid Glass API:
`.glassEffect(.regular, in: .rect(cornerRadius:))` + `GlassEffectContainer(spacing:content:)` (iOS/macOS 26).

REMAINING (in order): **Plan 4g** (coach-app integration & polish) — THEN Plan 5 (paddler PWA), GO-LIVE (hosted
Supabase ap-southeast-2 + Vercel deploy incl. the Python solver — which unblocks Optimise), Plan 6 end-to-end.
4g SCOPE (the accumulated polish + integration): (editor) seat drag+haptics+animations, Optimise UI wired to the
deployed solver, Share snapshot, multi-heat switcher nav (HeatSwitcher "+" inert now), redo, long-press
lock/drummer/sweep menu, section-band shading, empty/error state when placementRequest nil, GenderBadge reuse,
two-empty-seat swap no-op guard, Mac centred-hull+inspector; (cross-cutting) sync-completion refresh for feature
screens (they load once via `.task`), VM load() re-entrancy guards, availability note editing, erg recordedBy→
current coach, CrewDetailModel gender-rule test + heats(raceId:) test, guard SquadView add-sheet clubId, surface
side/gender/role squad filter chips, .dsMono token + teal-placeholder fix, boat-size-specific per-heat gender check,
accessibility pass (empty-seat labels), offline smoke, verification-before-completion. Full-run reproducibility:
each plan built via subagent-driven-development on `.worktrees/plan-4X`, merged after final review.
Deferred to Plan 6: ISO8601 ms-truncation causes newest row to re-pull each sync (idempotent); splitRows
returns [] on non-array response; live PUSH never exercised (live PULL + onboarding RPCs now are).
Then Plan 5 (paddler PWA), GO-LIVE (hosted Supabase project ap-southeast-2 + Vercel deploy), Plan 6
end-to-end integration (incl. deferred solver hardening: UUID-validate heatId, httpx reuse, auth-before-conn).
Execution: subagent-driven-development on a per-sub-plan branch/worktree, merge to main after each final review.

## (was) Phase 1 — Plans 1–3 (core, supabase, solver). Spec approved 2026-08-22.
Plans live in `docs/superpowers/plans/` — start from `2026-08-22-roadmap.md`.
Execution: subagent-driven, parallel (Jun chose 2026-08-23). One git worktree + branch per plan:
`.worktrees/plan-1-core` (branch plan-1-core), `.worktrees/plan-2-supabase`, `.worktrees/plan-3-solver`.
Each worktree has an SDD ledger at `<worktree>/.superpowers/sdd/<plan>/progress.md` (git-ignored) —
after compaction: read those ledgers + `git log` on each branch to find the next task. Branches are pushed
as tasks complete; each plan merges to main after its final review. Plan 3 Task 2+ waits for Plan 1's
fixtures to land on main (then `git merge main` into plan-3-solver).

## Hard rules (from the brief)
- Old project `/Users/junlee/Documents/CGS/IB/IA/LEEJun-CSIA/Product/crewCoach` is **READ-ONLY**. Never write/modify anything there.
- Any mention of "CrewCoach" in the product → **Paddltir**.
- Architecture is locked (SwiftUI coach app + PaddltirCore pkg, Next.js paddler PWA on Vercel,
  Supabase backend, Python+highspy solver as Vercel Python fn). Raise objections with the user, don't deviate silently.
- Commit + push to GitHub as we go.

## Decisions made (with reasoning)
- 2026-08-22: Project lives in the existing empty repo at cwd (user confirmed).
- 2026-08-22: **Club model = invite-code clubs.** Coach signs up → creates club → shareable invite code/link. Paddlers sign in by email magic link, enter code, claim their roster row (auto-linked if coach entered their email). Multi-club ready. (user chose)
- 2026-08-22: **Supabase = new hosted project (ap-southeast-2) + OrbStack locally** for `supabase start` + pgTAP RLS tests. Hosted = staging/prod. (user chose). Jun to install OrbStack: `brew install --cask orbstack`.
- 2026-08-22: **Availability = coach-defined sessions** (training / race day); paddlers respond In/Out/Maybe + note. (user chose)
- 2026-08-22: **Navigation = Schedule · Crews · Squad** (approach A). Concepts renamed: Roster→Squad, Crewlist→Crew, Config→Race, heats are rows, Session new. (user chose)
- 2026-08-22: **powerRatio dropped** — algorithms use absolute erg metres (objective is scale-invariant); UI derives relative bar. (user approved)
- 2026-08-22: Hosting: Vercel **Services** (web/ Next.js + solver/ FastAPI) preferred; fallback file-based web/api/optimize.py. Python 3.12.
- 2026-08-22: **Selection-quality stage added** (maximise total erg of seated crew) between "max seated" and "weight balance" in BOTH algorithms — otherwise the optimiser may bench the strongest paddler to shave grams of imbalance. Flagged to Jun at plan handoff; proceed unless vetoed.
- 2026-08-22: `category_rules` carries min/max for both women and men (women-only = max_men 0).
- 2026-08-22: Plans 4 (coach app) and 5 (PWA) are written AFTER the visual-direction phase (frontend-design + ui-ux-pro-max + imagegen) per the brief's skill order.
- 2026-08-22: Mixed-crew gender rule (IDBF, verified): standard boat 8–12 of each gender /20; small boat 4–6 /10. Some events use 8–10 / 4–5 → configurable per category (min/max women).

## Domain facts from old prototype (extracted 2026-08-22, see agent brief)
- Erg score = metres in a 2-minute erg test (higher better). powerRatio = erg/max(erg over roster), derived, never stored.
- Enums: side Left|Right|Both; gender Male|Female; seat pref Stroke|Pace|Engine|Sprint; role Paddler|Drummer|Sweep;
  size small(5 benches)|standard(10); category open|women|mixed; age divisions 16U 18U 24U Premier "Senior A" "Senior B" "Senior C".
- Sections standard: Stroke[1] Pace[2,3] Engine[4–7] Sprint[8–10]; small: Stroke[1] Pace[2] Engine[3] Sprint[4,5].
- Warn thresholds: weight Δ 10 kg; power Δ 10% of total; side-pref < 80%; trim Δ 50 kg.
- Trim: arm for bench b = b − (n+1)/2 (5.5 standard); drummer arm −(n+1)/2; sweep arm +(n−(n+1)/2+1). trimDelta = 2|Σw·arm|/n.
- Old greedy: lexicographic 4-tuple [|ΔW|, |ΔP|, −sideMatches, −benchMatches], 3 deterministic orderings, ignores trim + drummer/sweep weight. Suggestions: top-2 swaps; replacement plans ≤3 moves.
- Old app: heats hardcoded (heat1/heat2/final), no paddler login, no availability, no gender constraint.

## Done
- [x] Project directory confirmed
- [x] PROGRESS.md created

## In progress
- [x] Brainstorm UX / screen architecture — all 6 sections approved
- [x] Spec written and approved (docs/superpowers/specs/2026-08-22-paddltir-design.md)
- [x] Roadmap + Plans 1–3 written and self-reviewed (docs/superpowers/plans/)
- [x] **Plan 1 (PaddltirCore): MERGED to main** (commit 40a7882). 12 tasks, 56/56 tests, 0 warnings, greedy auto-fill ≈3ms release, golden fixtures. Final whole-branch review clean. Branch+worktree deleted. Rulings recorded in git history + scratchpad ledger copy.
- [x] **Plan 2 (Supabase): MERGED to main** (commit 2c34fac). 4 migrations (tables/RPCs/RLS/views), helpers+demo seed split, 98 pgTAP tests. THREE opus security reviews + final-review RLS hardening — every cross-tenant write/read path closed and live-probe-verified. Task 7 (hosted project) + Vercel deploy = go-live. Branch+worktree deleted.
- [x] **Plan 3 (Solver): MERGED to main** (commit e6aa5e0). Python model + scoring (EXACT cross-lang parity), lexicographic HiGHS MIP (y-reformulation proves all provable stages ~161ms), MIP goldens, auth/db/cache adapters, FastAPI /api/optimize (authz-ordered, cache), vercel.json. 25 tests. Final review clean. LIVE deploy deferred to go-live. Branch+worktree deleted.

## Next
- [x] Write design spec → docs/superpowers/specs/2026-08-22-paddltir-design.md
- [ ] Phase 2: visual direction (frontend-design + ui-ux-pro-max) → docs/design/direction.md; concepts via imagegen-frontend-mobile
- [ ] Write Plans 4 (coach app) + 5 (PWA), then execute
- [ ] Plan 6 integration + verification

## Blocked / open questions for Jun
- (none right now)

## Learned the hard way
(nothing yet)

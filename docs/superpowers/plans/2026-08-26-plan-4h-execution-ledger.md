# Plan 4h — execution ledger (SDD)

> Verbatim copy of the git-ignored SDD ledger + the final-review fix brief, kept for the record.
> Plan: `2026-08-26-plan-4h-quality-pass.md`. Merge: b809334.

## Ledger

# SDD ledger — plan: docs/superpowers/plans/2026-08-26-plan-4h-quality-pass.md

Worktree: .worktrees/plan-4h-quality (branch plan-4h-quality), base = 4803f2d (main, post-4g merge). CREATED 2026-08-26.
Spec: docs/superpowers/specs/2026-08-22-paddltir-design.md §3. Reachable ✓. Baseline = merged 4g tree.
Secrets.swift copied into the worktree (git-ignored).

## Pre-flight conflict scan (plan self-consistency; done before the worktree exists)

| Rows checked | Finding |
|---|---|
| T1 observe*() + snapshot structs → T3/T4/T7 consumers | names/fields consistent (observePaddlers/observePaddlerDetail/observeSummaries/observeCrewDetail/observeSchedule/scheduleSnapshot/observeTrainingDetail/observeRaceDay/observeHeats; ScheduleSnapshot{sessions,squadSize,availabilityBySession}, TrainingDetail{paddlers,availability}, RaceDaySnapshot{races,crews,availability,squadSize}, CrewDetail{crew,members,races,squad,rule}, PaddlerDetail{paddler,ergHistory}) ✓ |
| T1 static fetch fns are @Sendable-safe | static funcs referenced by `ValueObservation.tracking(Self.fetchX)` ✓; closures capturing `id`/`now` (Sendable) ✓ |
| T1 CrewRepository imports PaddltirCore for GenderRule | UI-free import ✓ |
| T2 removes syncGeneration + the 3 `.onChange` readers | T3 then removes `load()`-on-appear in favour of observe() — ordered T2→T3 ✓ |
| T3 & T4 both edit tab views' navigationDestination call sites | T3 leaves detail inits as-is; T4 changes detail inits + updates call sites — ordered T3→T4 ✓ (H1) |
| T3 ScheduleViewModel drops clubId/headcount(for:) | ScheduleViewModelTests must be updated (clubId assertion removed; create test calls createTraining(clubId:) then load()) — stated in T3 ✓ |
| T4 PaddlerDetailModel drops clubId param | PaddlerDetailView reads app.environment.clubId for the edit form ✓ |
| T4 CrewDetailModel keeps load() | CrewGenderRuleTests (4g) still passes via load() ✓ |
| T5 StatusBanner (DS) → used by T5 views only | no earlier consumer ✓ |
| T6 HullActions replaces HullGrid.onTapSeat | LineupEditorView is the only HullGrid call site (+ DebugFirstHeatEditor via LineupEditorView) — T6 updates it ✓ |
| T6 `mutate` clears redo / `undo` pushes redo | existing LineupViewModelTests (unseatAndUndo) + LineupSwapGuardTests unaffected in semantics ✓ |
| T7 LineupEditorView(race:db:) replaces (heatId:raceName:db:) | RaceHeatLoader deleted; RaceDayDetailView + DebugFirstHeatEditor call sites updated in T7 ✓; T7 must come after T6 (HullActions) ✓ |
| T7 `selectedHeatIndex didSet` spawns Task | @MainActor class; fine. `Array[safe:]` helper added in Shared/ ✓ |
| `Loadable` (T1) | may end up unused (VMs use isLoaded+lastError) → delete in T8 if unreferenced (H2) |
| .draggable(String)/.dropDestination/.contextMenu/.sensoryFeedback | all SwiftUI ≥ iOS 17 / macOS 14 — deployment is 26 ✓ |
| new test files each task | need xcodegen generate before xcodebuild → H3 |

## Rulings (pre-flight)

Ruling H1 (execution order): strictly T1→T2→T3→T4→T5→T6→T7→T8 as written (T2 before T3 removes the syncGeneration readers; T3 before T4 on the shared call sites; T6 before T7 on HullActions). — Cost if wrong: a forward-reference compile error caught by the gate; low.
Ruling H2 (dead code): `Loadable` ships in T1 for optional use; if no view-model references it by T8, delete it in T8 (YAGNI) rather than leave dead code. — Cost if wrong: trivial.
Ruling H3 (build mechanics): every implementer runs `cd apple && xcodegen generate` before xcodebuild. — low.

## Task log
Task 1: dispatched (sonnet, agent a38b48ac9d5f86fa4), BASE=4803f2d. Repository ValueObservations + snapshot structs + Loadable + ObservationTests. Carrying H3.

## Carried from the 4g final review (fable) — fold into the named tasks' dispatches
- T3 (CrewsView): give the add-crew sheet the same non-empty-clubId guard + styled dismissible fallback as SquadView (4g fixed SquadView only). With T3's `app.environment.clubId` gating of the "+" button this is naturally covered — verify the sheet can't render empty.
- T4: the detail + editor screens must be observation targets (in 4g they don't reload on sync — a crew synced while the editor is open needs back-and-in). T4 already observes Training/RaceDay/Crew/Paddler detail; for the EDITOR, T7's `observeHeats` covers heats — ALSO re-run `load(heatId:)` when `placementRequest` was nil and a later heats/crew emission arrives (so the "couldn't load this race's crew" state self-heals once sync lands).
- T6/T7 (HullGrid): extract the seat accessibility-label composition into `SeatTile` (a `static func accessibilityLabel(name:gender:side:weightKg:violatesPref:)` or an `accessibilityText` on the tile) so HullGrid's outer label reuses it instead of hand-copying; and make the hint contextual (deselect / place here / select). Also use `Int(weightKg.rounded())` in both tile + label so VoiceOver matches the visible "73".
- T3 (ScheduleViewModel): drop `isLoading` entirely (isLoaded replaces it; no double-load flicker once observe() is the only path).
DISPATCH NOTES (verified 2026-08-26): T3 must edit ScheduleViewModelTests — `loadComposesGroupingsAndClub` line 23 `#expect(vm.clubId == "club-1")` → REMOVE (clubId leaves the VM); `createTrainingWritesThenReloads` line 34 → `createTraining(clubId: "club-1", …)` then add `await vm.load()` after it (one-shot path doesn't observe). SquadViewModelTests uses `load()` (kept). CrewGenderRuleTests uses `CrewDetailModel.load()` (T4 keeps load()).
Task 1: IMPLEMENTED at 4436087 (98/28, macOS builds). Deviations (documented): crew(id:) → new static fetchCrewWithMembers (not fetchCrewDetail — avoids races/squad/rule over-fetch); ergHistory shares inner fetchErgHistory only (ErgHistoryTests inserts ergs with no paddler row). Review dispatched (fable, agent ab4b392c9d250d2b6 — foundation diff, most-capable tier), package 4803f2d..4436087. Branch pushed at 4436087.
Task 1: review (fable) = NEEDS FIXES (narrow). IMPORTANT: fetchCrewDetail re-inlines racesForCrew's query → extract `static fetchRacesForCrew(_:crewId:)` used by both. Minors: `Crew.order(name)` ×3 (crews/fetchSummaries/observeRaceDay) → `static fetchCrews`; no test on fetchCrewDetail (composite-key rule lookup + all-empty fallback); observeSummaries(now:) freezes `now` (note for T3: derive "next race" view-side or re-subscribe on foreground). Both deviations APPROVED; behavior preservation verified line-by-line; CategoryRule composite PK confirmed safe.
Ruling H4: fix round 1 takes the Important + both cheap same-file minors (fetchCrews extraction; a 2-case fetchCrewDetail test) — the crew-detail migration (T4) depends on this code being right. `now`-freeze → carried to T3/T4 notes. — Cost if wrong: a few lines + one test; nil.
Task 1: fix round 1/5 dispatched — resumed implementer a38b48ac9d5f86fa4. FIX_BASE=4436087.
Ruling H5 (observeSummaries now-freeze): accept `now` captured at subscription — the view's `.task` re-subscribes on every appearance, and "next race" rolls over on an hours/days scale, so staleness is bounded by one continuous screen session. T3 dispatch: keep `observeSummaries(now: Date())` in `observe()`; no re-subscribe plumbing. — Cost if wrong: a "Next:" label can lag within a long-lived Crews screen until the next appear/sync; cosmetic.
Task 1: fix round 1 IMPLEMENTED at 633d396 (99/28, zero warnings, macOS builds). Scoped re-review dispatched (sonnet, agent ad2d8b5ccde67aba0), package 4436087..633d396. Branch pushed at 633d396.
Task 1: fix round 1/5 (3 addressed, 0 open — fetchRacesForCrew + fetchCrews shared statics; fetchCrewDetail test w/ verified composite key; commits 4436087..633d396)
Task 1: complete (commits 4803f2d..633d396, review clean after 1 fix round). Suite 99/28.
Task 2: dispatched (sonnet, agent aa0a00b4335203149), BASE=633d396. AppEnvironment.clubId + observeClub(); remove syncGeneration + the 3 `.onChange` readers; RootView .task; AppEnvironmentClubTests. Carrying H3.
Task 2: IMPLEMENTED at 6d5fbec (100/29, zero warnings, macOS builds; syncGeneration grep empty). Review dispatched (sonnet, agent aa804fc276b90e85e), package 633d396..6d5fbec. Branch pushed at 6d5fbec.
PRE-VERIFIED for T5–T7: gallery file = apple/Sources/DesignSystem/Gallery/DesignSystemGallery.swift (T5 adds a StatusBanner sample there); no existing `StatusBanner` / `HullActions` / `subscript(safe:)` — names free.
Task 2: complete (commits 633d396..6d5fbec, review clean — Sonnet; no findings)
Task 3: IMPLEMENTED at 1c56596 (feat(app): reactive tab view-models; eager view construction; no reload hacks) — 102/30, macOS OK. Implementer agent ac046451134809d97 (sonnet). Review dispatched (sonnet), package 6d5fbec..1c56596.
Task 3: complete (commit 1c56596, review Approved — Sonnet; 1 Minor carried, see H6)
Ruling H6: Task 3 Minor — SquadViewModel.load()/CrewsViewModel.load() set isLoaded but do not reset lastError = nil on success (stale error after a later successful load). Deferred to Task 5 (the task that surfaces lastError via StatusBanner): implementer must clear lastError on every successful emission/load in all three tab VMs — because fixing it where it becomes user-visible keeps Task 4 unblocked — costs nothing if wrong (one-line fix).
Ruling H7 (Task 4 carry of the 4g-review rec "editor re-runs load when placementRequest was nil and data arrives later"): the editor keeps a one-shot load(heatId:) because its Lineup is a local editing value (a live observation would clobber unsaved edits); instead the "Couldn't load this race's crew" empty state gains a "Try again" button that re-runs load(heatId:). — honest, cheap, no data-loss risk — if wrong, costs a later observation-based reload (Task 7 territory).
Task 4: dispatched (sonnet) BASE=1c56596.
Task 4: IMPLEMENTED at e22ad73 (DONE_WITH_CONCERNS) — 102/30, macOS OK. Implementer agent a5d61a13795c314a5 (sonnet).
Ruling H8: the acceptance grep for optional view-models also hits OnboardingView.swift:64 (`OnboardingViewModel?`) — predates 4h; onboarding is a one-shot network flow (ClubService), not a GRDB observation, so it is OUT of 4h scope; the grep intent is Features/{Schedule,Squad,Crews,Lineup}. Accepted as-is. — costs nothing if wrong (a later polish item).
Task 4: review dispatched (sonnet), package 1c56596..e22ad73.
Task 4: complete (commit e22ad73, review Approved — Sonnet; Minor parked: pre-existing redundant `_ = try await squad.upsert(row)` in PaddlerDetailView.swift:34 — not introduced by 4h; leave for the final-review wave if it touches that file)
Task 5: dispatched (sonnet) BASE=e22ad73; carries H6 (clear lastError on success in Squad/Crews load()) + H3 (regen after adding StatusBanner.swift).
Ruling H9 (Task 6 carry of the 4g-review a11y recs — HullGrid.seatAccessibilityLabel duplicates SeatTile's label; both use Int(weightKg) which truncates while the tile shows .precision(.fractionLength(0)) which rounds — 58.6 kg reads "58" but shows "59"): in Task 6, (a) SeatTile owns the occupant description — add `public static func accessibilityDescription(name:gender:side:weightKg:violatesPref:) -> String` used by SeatTile's own .accessibilityLabel, and HullGrid composes "Bench N left/right, " + that (empty: "Bench N left, empty"); (b) weight = Int(weightKg.rounded()) in that one place; (c) contextual hints from `selection`: nothing selected → "Double-tap to select"; this cell selected → "Double-tap to deselect"; another seat/reserve selected → empty target "Double-tap to move <selected name> here", occupied target "Double-tap to swap with <occupant name>"; (d) occupied cells expose the context-menu actions as VoiceOver custom actions via .accessibilityAction(named:) (Unseat / Lock seat|Unlock seat / Set as drummer / Set as sweep) so drag-and-drop-only affordances stay reachable. — single source of truth + parity with the visual + reachable actions; if wrong it costs one small view edit.
Task 5: IMPLEMENTED at 2fad6b9 — 102/30, macOS OK, screenshots 4h-t5-schedule.png + 4h-t5-gallery-statusbanner.png. Implementer agent a53ab9b4f396b96bc (sonnet).
Ruling H10: accept both Task 5 deviations — (1) no extra .padding(.horizontal, DS.Space.l) on banners inside VStacks that already apply .padding(DS.Space.l) (a literal reading would double-inset the banner vs sibling cards); (2) .accessibilityElement(children: .combine) scoped to the icon+text pair so the Retry/action button remains its own focusable element. — both serve the brief's intent (placement parity; reachable action) — costs nothing if wrong.
Task 5: review dispatched (sonnet), package e22ad73..2fad6b9.
Task 5: complete (commit 2fad6b9, review Approved — Sonnet)
Ruling H11: Task 5 Minor (StatusBanner "Retry" text button has no 44pt minimum hit area; mirrors pre-existing Edit/Archive text buttons) — parked for Task 8 controller polish: add `.frame(minHeight: 44)` (via DS.Space or a `minTouch` constant if one exists) to the banner action; the pre-existing Edit/Archive buttons stay as-is (out of 4h scope, noted as deferred a11y audit item). — cheap, DS-owned — costs nothing if wrong.
Task 6: dispatched (sonnet) BASE=2fad6b9; carries H9 (seat a11y single source of truth + rounding + contextual hints + custom actions) + H3.
Task 6: IMPLEMENTED at eac3f62 — 108/31, macOS OK, screenshots 4h-t6-editor*.png. Implementer agent adaddbeb70bd8f0c7 (sonnet). Review dispatched (sonnet), package 2fad6b9..eac3f62.
NOTE: Task 6 commit rebased eac3f62 -> 744a638 (a stray docs commit ed25887 had landed on the branch via a drifted shell cwd; dropped). Review package regenerated: 2fad6b9..744a638.
Task 6: complete (commit 744a638, review Approved — Sonnet; 3 Minors: 2 carried into H12, path-header comment ignored — not a house rule)
Ruling H12 (Task 7 carry of Task 6 Minors): (1) drops accept any String payload and PaddlerID(raw) never fails → the VM validates ids at its single choke point: dragDrop/dropOnTray/setDrummer/setSweep `guard roster.byID[id] != nil else { return }` (no undo entry, no save) — plus a unit test dropping an unknown id is a no-op; (2) the reserves tray renders always (drop target for drag-to-unseat even when the boat is full) with an empty-state line "No reserves — drag a paddler here to unseat" (dsFootnote, ink3). — both are one-screen fixes in files T7 already edits — cheap if wrong.
Task 7: dispatched (sonnet) BASE=744a638; carries H12 + H3 + H2 (Loadable stays until T8) + auto-create guard note.
Task 7: IMPLEMENTED at 6c35f84 — 109/31, macOS OK, screenshots 4h-t7-editor*.png (+ macOS wide). Implementer agent a26b3bd7977d0175b (sonnet). Observation: iPad sim DEBUG auto-signin hung >2 min on a fresh device (harness, pre-existing) — Task 8 may retry iPad once. Review dispatched (sonnet), package 744a638..6c35f84.
Task 7: complete (commit 6c35f84, review Approved — Sonnet; 2 Minors: addHeat index timing → fixed in Task 8 polish; unconditional save after a guarded no-op drop → accepted (pre-existing pattern; no bad data written))
Task 8 (controller): gates on 6c35f84 GREEN — iOS 109/31, macOS build, gated live 2/2; fresh-install single-launch screenshots tab0/1/2 populated (verified); editor deep-link spun (DebugFirstHeatEditor one-shot Race read on an empty DB — fixed below).
Ruling H13 (Task 8 polish commit): (a) H11 StatusBanner action .frame(minWidth/minHeight 44) + contentShape; (b) H2 delete Loadable.swift + its loadableValueAccessor test (no production usage); (c) DebugFirstHeatEditor observes the first Race (ValueObservation, break on first non-nil) instead of a one-shot read; (d) addHeat selects by id lookup (`heats.firstIndex { $0.id == h.id } ?? heats.count`). — all DEBUG/one-liners; re-gated before commit.
Task 8: polish committed at 192c5a7 (H13 a–d); re-gate GREEN — iOS 108/31 (Loadable test removed by design), macOS build, fresh-install editor deep-link screenshot populated. Final whole-branch review dispatched (fable), package 4803f2d..192c5a7.
FINAL REVIEW (fable) on 192c5a7: "With fixes" — 0 Critical, 5 Important (heat auto-create can duplicate during the races/heats sync window; first-emission failure = dead-end spinner; editor swallows save/load errors + no banner; drummer/sweep one-way door; selectedHeatIndex not reconciled), Minors (locked-seat rule = plan gap; addHeat double-load/name collision; "Heat Heat 1" a11y; haptic on load; stale comments/CrewCoach in SeatTile; literals; test timeouts; pre-existing items). Report in agent output affa0f5e998d718ed.
Rulings F1–F8 recorded in final-fix-brief.md: F1 heats born with the race in createRace's transaction, no editor auto-create (fixes a real cross-device duplicate; plan gap in T7); F2 isLoaded=true in every observe() catch; F3 editor do/catch → lastError + StatusBanner; F4 clearDrummer/clearSweep + cap rows as drop targets + seat/cap exclusivity; F5 heat-selection state machine (pendingHeatId, reconcile on every emission, createHeat(raceId:) names in-transaction); F6 locked seats resist manual moves (product rule: a lock means "do not move" — spec only mentions locks for the solver; ruled explicitly); F7 small a11y/motion/copy; F8 deferred list. ONE fix dispatch (sonnet) then ONE scoped re-review (fable).
Final fix wave: dispatched (sonnet) BASE=192c5a7.
Final fix wave: IMPLEMENTED at 81ad123 (DONE_WITH_CONCERNS) — 123/33 (+15 tests), macOS OK. Concern 1 (some brief-mandated tests not independently RED — behaviour pre-existed) ACCEPTED. Concerns 2+3 adjudicated as real residuals → same agent resumed for ONE follow-up commit: (A) StatusBanner above "Not found" in CrewDetailView/PaddlerDetailView when a read failed (F2 case); (B) setDrummer/setSweep no-op for an occupant of a LOCKED seat (F6 consistency) + test.
Final fix wave: follow-ups at e4b6c8e — 125/33, macOS OK. Scoped re-review dispatched (fable), package 192c5a7..e4b6c8e.
Task 8 verification on e4b6c8e: iOS 125/33, macOS build, gated live 2/2 (local stack), fresh-install single-launch screenshots tab0/1/2 + editor all populated (editor shows the seeded Heat 1/Heat 2/Final — no auto-created duplicate). Screenshots copied to main apple/screenshots/4h/ (git-ignored); review packages copied to this workspace.
Scoped re-review (fable) on e4b6c8e: F1/F4/F5/F7/F8/A/B Addressed; F2/F3 partial (editor empty branches hide lastError); F6 partial (tapReserve unguarded — lock bypass via select→lock→tap reserve); Minors 3–6. Verdict "With fixes".
Ruling R1: residuals adjudicated as load-bearing (a lock bypass + hidden editor errors defeat the wave) → same agent resumed for ONE remainder commit: editor banners in both empty branches; placeFromReserve helper w/ lock guard + cap-clear + toggleLock clears selection + test; heat-switch failure resets selectedHeatIndex; named createHeat uses max+1; detail banner inset xl. Minor 3 (loadingHeatId) DEFERRED. Then a scoped re-check (sonnet) limited to these items.
Remainders: IMPLEMENTED at 7b5a156 — 126/33, macOS OK. Scoped re-check dispatched (sonnet), package e4b6c8e..7b5a156.
Scoped re-check (sonnet) on 7b5a156: all five remainders Addressed; Ready to merge = Yes; 1 Minor (new test does not isolate the placeFromReserve guard — defence in depth, disclosed) ACCEPTED. Merging.


## Final-review fix brief (rulings F1–F8)

# Plan 4h — final-review fix wave (ONE dispatch)

Branch `plan-4h-quality`, base for this wave: `192c5a7`. Worktree: `/Users/junlee/Documents/programming/paddltir/.worktrees/plan-4h-quality`.
Every item below is a controller ruling (F1–F8) on a final-review finding. Implement all of them; nothing else.
Conventions: `@MainActor @Observable` models; every lineup change through `mutate(_:)`; design-system tokens only
(`DS.Space.*`, `DS.R.*`, `.dsFootnote/.dsCaption`, `DS.ink3/.surface2/.border/.danger`, `StatusBanner`, `SecondaryButton`);
never raw hex / `Font.system` / magic paddings; strings say "Paddltir"; never touch `apple/Sources/App/Secrets.swift`.
Regenerate after adding files: `xcodegen generate` from `apple/`.

## F1 — Heats are born with the race; the editor never auto-creates (Important 1)
Problem: `LineupViewModel.observeHeats` creates "Heat 1" on the first empty emission. `SyncEngine.syncAll` pulls `races` and
`heats` in separate transactions, so an editor open in that window creates a local "Heat 1" that syncs up as a permanent duplicate.
Fix:
1. `ScheduleRepository.createRace(...)` (find the existing write) creates the race AND its first heat (`name: "Heat 1"`,
   `sort_order: 1`) in the SAME `db.write` transaction, enqueueing the heat's outbox entry exactly the way `LineupRepository.createHeat`
   does (reuse that code — extract a `static func insertHeat(_ db: Database, raceId:name:sortOrder:) throws -> Heat` used by both
   `createHeat` and `createRace`; do not duplicate the outbox logic).
2. Remove the auto-create branch (and `didAutoCreate`) from `observeHeats`. An empty list is a legitimate state: set
   `heats = []`, `heat = nil`, `lineup = nil`, `placementRequest = nil` (whatever the editor reads), `isLoaded = true`, and `continue`.
3. Editor view: when `model.isLoaded && model.heats.isEmpty` render an empty state inside `ScreenScaffold` — title "No heats yet",
   note "Tap + to add the first heat for this race." — with the `HeatSwitcher` still visible so "+" works.
Tests (in `HeatsQueryTests.swift` or a new `HeatCreationTests.swift`, in-memory `AppDatabase`):
- `createRaceCreatesItsFirstHeat`: after `createRace`, `LineupRepository.fetchHeats(db, raceId:)` (use the real static name) returns one
  heat named "Heat 1" with `sort_order == 1`, and the outbox holds an entry for it (assert via the same outbox query other tests use).
- `observeHeatsWithNoHeatsCreatesNoneAndLoads`: race with zero heats → `observeHeats` sets `isLoaded == true`, `heats.isEmpty`, and a
  second empty emission (insert+delete an unrelated row on `heats` to force one) still creates none.

## F2 — A failed first emission renders, it doesn't spin (Important 2)
In EVERY `observe()` (`ScheduleViewModel`, `SquadViewModel`, `CrewsViewModel`, `TrainingDetailModel`, `RaceDayModel`,
`CrewDetailModel`, `PaddlerDetailModel`, `LineupViewModel.observeHeats`, and `AppEnvironment.observeClub` if it has an `isLoaded`):
the `catch` sets `lastError = error.localizedDescription` AND `isLoaded = true`, so the view leaves the spinner and shows its empty
state with the `StatusBanner`. Views: keep the banner where it is (inside the loaded branch) — verify every screen's loaded branch
renders the banner even when its data is empty (a `List`/`ForEach` with zero rows must not hide the banner). Test: in
`ReactiveViewModelTests`, add one case that closes/poisons the DB (e.g. use a `DatabaseQueue` on an `AppDatabase` whose `dbQueue`
you close via `try db.dbQueue.close()` before `observe()` if the API allows; otherwise construct the observation over a missing table
by using a fresh `DatabaseQueue()` without migrations wrapped in an `AppDatabase` if the initializer permits) and asserts
`isLoaded == true && lastError != nil` within the bounded poll. If neither is feasible with the public `AppDatabase` API, say so in the
report and instead unit-test `apply`/`catch` via a small `internal` seam — do not skip silently.

## F3 — The editor surfaces every error (Important 3)
`LineupViewModel`: `save()` — replace `try?` with `do { … } catch { lastError = error.localizedDescription }`; on success
`lastError = nil`. `load(heatId:)` — replace `try?` on reads with do/catch → `lastError` (the nil-`placementRequest` empty state stays
for the genuine "no crew" case; a thrown read is an error, not "no crew"). Remove the unused `isSaving` if nothing reads it.
`LineupEditorView`: `if let e = model.lastError { StatusBanner(e).padding(.horizontal, DS.Space.l) }` as the first element of the
content (both wide and narrow layouts — put it in the shared column so it isn't duplicated). Test: `LineupInteractionTests` — after a
successful `save()`, `lastError == nil`; and a `load(heatId:)` against a heat id that doesn't exist yields `isLoaded == true` and
`placementRequest == nil` (no error — "no crew"), documenting the distinction.

## F4 — Drummer/sweep can be cleared; a paddler is never both seated and a cap (Important 4)
1. `HullActions` gains `var clearDrummer: () -> Void` and `var clearSweep: () -> Void` (keep `setDrummer/setSweep(PaddlerID)` as they are).
2. `HullGrid` cap rows ("Drummer"/"Sweep"): when occupied, a `.contextMenu { Button("Clear drummer") … ; Button("Move to reserves") … }`
   (both call `clearDrummer`/`clearSweep` — one button is enough if they're identical: use "Clear drummer" / "Clear sweep" only) plus the
   matching `.accessibilityAction(named:)`; the cap row is `.accessibilityElement(children: .combine)` with label
   "Drummer, <name>" / "Drummer, empty"; every cap row is a `.dropDestination(for: String.self)` that calls `setDrummer`/`setSweep` with the
   dropped id (validated in the VM per H12).
3. `LineupViewModel.dragDrop(_:onto:)` and the tap-to-place path: before placing id into a seat, if `lineup.drummerId == id` set it nil,
   if `lineup.sweepId == id` set it nil (inside the same `mutate`). `setDrummer(id)`/`setSweep(id)` already unseat (keep); also if the
   paddler is the other cap (drummer→sweep), clear the old role in the same `mutate`.
4. `LineupEditorView.hullActions` wires `clearDrummer: { model.setDrummer(nil); save }`, `clearSweep: { model.setSweep(nil); save }`.
Tests (`LineupInteractionTests`): `setDrummer(nil)` clears and pushes undo; `dragDrop` of the current drummer onto an empty seat seats them
AND clears `drummerId`; `setSweep` of the current drummer clears `drummerId`.

## F5 — Heat selection is a small state machine that survives reorders and additions (Important 5 + addHeat minors)
`LineupViewModel`:
- `var selectedHeatIndex = 0 { didSet { guard let h = heats[safe: selectedHeatIndex], h.id != heat?.id else { return }; Task { await load(heatId: h.id) } } }`
- `private var pendingHeatId: String?`
- `observeHeats`, per emission: `heats = list`; then
  `if list.isEmpty { …F1 empty state… }`
  `else if let p = pendingHeatId, let i = list.firstIndex(where: { $0.id == p }) { pendingHeatId = nil; selectedHeatIndex = i }`
  `else if let i = list.firstIndex(where: { $0.id == heat?.id }) { selectedHeatIndex = i }` (reconcile after a reorder; didSet no-ops)
  `else { selectedHeatIndex = 0 }` (nothing loaded yet, or the current heat vanished → load the first).
  Note `selectedHeatIndex = i` when `i == selectedHeatIndex` does not fire a load (ids match) — fine.
- `addHeat(raceId:)`: `do { let h = try await repo.createHeat(raceId: raceId); if let i = heats.firstIndex(where: { $0.id == h.id }) { selectedHeatIndex = i } else { pendingHeatId = h.id } } catch { lastError = … }`
  — no explicit `load` (the didSet loads exactly once, whichever ordering the observation lands in).
- `LineupRepository.createHeat(raceId:)` (new overload, no name): computes `sort_order = (max existing) + 1` and `name = "Heat \(sort_order)"`
  inside the write transaction (no collision on fast taps); the existing `createHeat(raceId:name:)` stays for tests and F1.
Tests (`LineupInteractionTests` or a new `HeatSwitchingTests.swift`, in-memory DB, bounded polls, `defer { task.cancel() }`):
- `addHeatSelectsTheNewHeat`: race with 1 heat → `observeHeats` running → `addHeat` → within the poll `heats.count == 2`,
  `selectedHeatIndex == 1`, `heat?.id == heats[1].id`, name "Heat 2".
- `reorderKeepsTheEditedHeatSelected`: two heats, second selected; update `sort_order` so it becomes first → `selectedHeatIndex == 0`,
  `heat?.id` unchanged.
- `deletedSelectedHeatFallsBackToFirst`: delete the selected heat row → `selectedHeatIndex == 0`, `heat?.id == remaining.id`.

## F6 — Locked seats resist manual moves (Minor, ruled as product behaviour)
Rule: a locked seat's occupant cannot be moved by tap/drag/swap and nothing can be dropped onto a locked seat; the coach unlocks first
(context menu / custom action). Implement in the VM at the choke points (`dragDrop`, `tapSeat`/the swap path, `dropOnTray` for a locked
occupant): `guard !lineup.isLocked(seat)` (and for swaps, both seats) → no-op, no undo entry. Hints (H9c): a locked target reads
"Locked — unlock to change". Tests: drop onto a locked seat is a no-op (`lineup == before`, `canUndo == false`); `dropOnTray` of a locked
occupant is a no-op; `toggleLock` then drop succeeds.

## F7 — Small a11y/motion/copy fixes in files this branch already touched (Minors)
- `HeatSwitcher.swift`: segment a11y label is the name itself (no "Heat " prefix — it now reads "Heat Heat 1").
- Reserve chips: `.accessibilityAddTraits(selected ? .isSelected : [])` like seats.
- Haptics: add `private(set) var revision = 0` to `LineupViewModel`, incremented in `mutate`, `undo`, `redo` only; `.sensoryFeedback(.impact(weight: .light), trigger: model.revision)` — no haptic on initial load or heat switch. Keep `.animation(..., value: model.lineup)`.
- `LineupViewModel.swift` header comment: describe what the file IS now (no "added in the next task"). `SeatTile.swift` header: replace "CrewCoach" wording with "Paddltir" (the visual lineage note may say "carried from the original CrewCoach design" once — that is a design-history mention, not product naming; keep it to one mention or drop it).

## F8 — Deferred (do NOT do now; listed so the reviewer doesn't flag them as missed)
`isTargeted` hover affordance / `SeatTile.lifted`; `560`/`40`/`360` layout constants into DS; `ObservationTests` unbounded
`iterator.next()` timeouts; `nonisolated(unsafe)` ISO formatters in `PostgRESTCoding.swift` (pre-existing); per-edit `saveSeats`
outbox churn (pre-existing); Edit/Archive 44pt buttons (pre-existing); `MainShell` dual environment access.

## Gate
From `apple/`: `xcodegen generate && xcodebuild -scheme Paddltir -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -derivedDataPath DerivedData test 2>&1 | grep -E "Test run with|error:|warning: .*Paddltir|TEST (SUCCEEDED|FAILED)|BUILD (SUCCEEDED|FAILED)"`
and `xcodebuild -scheme Paddltir -destination 'platform=macOS' -derivedDataPath DerivedData build 2>&1 | grep -E "error:|BUILD (SUCCEEDED|FAILED)"` — both green, no new warnings,
test count ≥ 108 + the new tests. Commit as ONE commit: `fix(app): 4h final-review wave — heats born with races, error surfaces, cap-row clear, heat-selection state machine, locked-seat rule`
with the trailers:
Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_014jeZcQK2MeLkeExLWsA6ov
Report to `/Users/junlee/Documents/programming/paddltir/.superpowers/sdd/2026-08-26-plan-4h-quality-pass/final-fix-report.md`
(per item F1–F7: what changed, which test covers it, RED/GREEN evidence for the new tests, the gate output).

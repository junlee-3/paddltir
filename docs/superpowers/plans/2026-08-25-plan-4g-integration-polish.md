# Plan 4g — Coach App Integration & Polish Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make the coach app robust end-to-end: feature screens refresh when the background sync lands (so a fresh launch actually shows data), infinite spinners become real empty/error states, a handful of correctness + coverage gaps close, the last cosmetic warts (mono token, teal placeholder) go away, and a focused accessibility pass lands. This is the integration/robustness pass — NOT the premium editor interactions.

**Architecture:** `AppEnvironment` gains an observable `syncGeneration` counter bumped on every successful `sync()`; the three tab view-models reload when it changes (SwiftUI `.onChange`), so the load-once-via-`.task` screens finally reflect pulled data. Views that could load nothing (lineup editor, paddler/crew detail) render explicit empty/error states instead of a perpetual `ProgressView`. Small correctness fixes + unit tests for previously-untested glue. A `.dsMono` typography token replaces the one sanctioned `Font.system`. An accessibility pass on the hull.

**Tech Stack:** SwiftUI + Observation, the existing Plan 4b–4f app (`AppEnvironment`, feature view-models, `LineupRepository`, DesignSystem), PaddltirCore.

**Spec:** `docs/superpowers/specs/2026-08-22-paddltir-design.md` — §3 (the "quality floor": offline-first, VoiceOver, dense-data legibility). Visual direction: `docs/design/direction.md`.

## Global Constraints

- **Rename:** any in-product "CrewCoach" → **Paddltir**.
- **Platforms:** iOS 26 + macOS 26; every change compiles + lays out on both; guard platform-only APIs with `#if os(...)`.
- **Design system — REAL names only:** spacing `DS.Space.{xs,s,m,l,xl}`; radius `DS.R.{card,ctl,sm,tile}`; typography `.font(.dsX)` (`.dsLargeTitle/.dsTitle/.dsHeadline/.dsSubhead/.dsBody/.dsCallout/.dsFootnote/.dsCaption/.dsMicro` — and the NEW `.dsMono` from Task 4); colors `DS.bg/.surface/.surface2/.ink/.ink2/.ink3/.border/.border2/.accent/.good/.danger/.maleFill/.maleBorder/.femaleFill/.femaleBorder/.primary/.onPrimary`; components `HairlineCard`, `MicroLabel`, `Pill(_ , tint:, foreground:)`, `PrimaryButton`/`SecondaryButton`, `GlassBar`/`GlassContainer`, `ScreenScaffold`, `SeatTile`, `TelemetryGrid`, `BalanceBeam`, `HeatSwitcher`, `AvailabilityRing`. Never raw hex; `Font.system` ONLY inside the new `.dsMono` token definition.
- **Light mode only.**
- **All lineup/domain logic stays in PaddltirCore.** Writes remain atomic (mutation + `Outbox.enqueue` in one `db.write`).
- **Repositories + PaddltirCore stay UI-free.** Live Supabase tests gated + skipped by default. No secrets committed.
- **Build gate:** `cd apple && xcodegen generate && xcodebuild -scheme Paddltir -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -derivedDataPath DerivedData test` — regenerate first. Also `xcodebuild -scheme Paddltir -destination 'platform=macOS' build`.
- **Explicitly OUT OF SCOPE (deferred — do NOT build here; a later "premium polish" pass or go-live owns them):** seat drag-and-drop + haptics + swap animations; **Optimise** (needs the deployed solver — go-live/Plan 6); Share image snapshot; multi-heat switcher navigation (create/rename/duplicate/delete); redo; long-press lock/drummer/sweep menu; section-band shading; GenderBadge reuse; availability free-text note editing; erg `recordedBy`→current coach; surfacing the side/gender/role squad filter chips; boat-size-specific per-heat gender check; the full Mac centred-hull + right-inspector editor layout. 4g does a LIGHT Mac pass (builds + runs) only.

## Current-state facts (verified)
- `AppEnvironment` (`@MainActor @Observable`): `private(set) var isSyncing`, `private(set) var lastSyncError`, `func sync() async` (guards `isSyncing`, `try await syncEngine.syncAll()`, sets `lastSyncError`). `RootView`'s `.ready` branch already calls `environment.sync()` on `.task` + scenePhase `.active`.
- Feature views read `@Environment(AppModel.self) private var app`; `app.environment` is the `AppEnvironment`. Each loads once: `ScheduleView` `.task { … await model?.load() }` (line ~42), `SquadView` `.task { … await model?.load() }` (~33), `CrewsView` `.task { … await model?.load() }` (~44).
- `Typography.swift`: tokens are `static let dsX = PaddltirFont.font(size, weight)`. No mono token yet.
- Known infinite-spinner spots: `LineupEditorView` (shows `ProgressView` while `model.lineup`/`roster`/`boat` nil — i.e. `placementRequest` returned nil), `RaceHeatLoader`, `PaddlerDetailView`/`CrewDetailView` (spin if the entity isn't found).
- `LineupViewModel.tapSeat` `.seat` case swaps even when both seats are empty (pushes a useless undo). `LineupRepository.heats(raceId:)` has no test. `CrewDetailModel` gender-rule verdict has no test. `SquadView`'s add-sheet falls back to `clubId = ""`.
- The AuthView email `TextField` placeholder renders teal (RootView's `.tint(DS.accent)` bleeding into the field).

## File Structure

Modified:
- `Sources/App/AppEnvironment.swift` — add `syncGeneration`.
- `Sources/Features/Schedule/ScheduleView.swift`, `Sources/Features/Squad/SquadView.swift`, `Sources/Features/Crews/CrewsView.swift` — reload on `syncGeneration` change; SquadView add-sheet clubId guard.
- `Sources/Features/Lineup/LineupEditorView.swift` (+ `RaceHeatLoader`), `Sources/Features/Squad/PaddlerDetailView.swift`, `Sources/Features/Crews/CrewDetailView.swift` — empty/error states.
- `Sources/Features/Lineup/LineupViewModel.swift` — two-empty-seat swap guard.
- `Sources/Features/Lineup/HullGrid.swift` — empty-seat accessibility labels.
- `Sources/DesignSystem/Typography.swift` — `.dsMono`; `Sources/Features/Settings/SettingsView.swift` + squad/paddler erg text — use `.dsMono`; `Sources/App/AuthView.swift` — placeholder fix.
- Tests: `Tests/PaddltirAppTests/LineupSwapGuardTests.swift`, `CrewGenderRuleTests.swift`, `HeatsQueryTests.swift`.

---

## Task 1: Sync-completion refresh (`AppEnvironment.syncGeneration` + view reloads)

**Files:** Modify `apple/Sources/App/AppEnvironment.swift`, `ScheduleView.swift`, `SquadView.swift`, `CrewsView.swift`.

**Interfaces:** `AppEnvironment` gains `private(set) var syncGeneration = 0` (incremented after each successful `syncAll()`).

- [ ] **Step 1: Add `syncGeneration`** to `AppEnvironment`

Add the property near `isSyncing`:
```swift
    /// Bumped after each successful sync so views that loaded from a
    /// then-empty cache can reload once pulled data lands. (The feature
    /// screens load once via `.task`; they observe this to refresh.)
    private(set) var syncGeneration = 0
```
And in `sync()`, bump it on success — change the `do` block to:
```swift
        do {
            try await syncEngine.syncAll()
            lastSyncError = nil
            syncGeneration += 1
        } catch {
            lastSyncError = error
        }
```

- [ ] **Step 2: Reload the three tabs when it changes**

In each of `ScheduleView`, `SquadView`, `CrewsView`, add — next to the existing `.task { … await model?.load() }` — an `.onChange` that reloads when the sync generation advances. The views already hold `@Environment(AppModel.self) private var app`. Add:
```swift
        .onChange(of: app.environment.syncGeneration) {
            Task { await model?.load() }
        }
```
(Attach it to the same view the `.task` is on. `AppEnvironment` is `@Observable`, so reading `app.environment.syncGeneration` in `.onChange(of:)` tracks it.)

- [ ] **Step 3: Build + verify**

Run the iOS build gate + macOS build. Expected: green, count unchanged, zero warnings. (No unit test: the bump is a one-liner and the reload is UI wiring; Task 6's single-launch screenshots are the real proof that first-launch now populates.)

- [ ] **Step 4: Commit**

```bash
git add apple/Sources/App/AppEnvironment.swift apple/Sources/Features/Schedule/ScheduleView.swift apple/Sources/Features/Squad/SquadView.swift apple/Sources/Features/Crews/CrewsView.swift
git commit -m "feat(app): reload feature screens when background sync completes"
```

---

## Task 2: Empty / error states (no more infinite spinners)

**Files:** Modify `apple/Sources/Features/Lineup/LineupEditorView.swift` (+ `RaceHeatLoader`), `apple/Sources/Features/Squad/PaddlerDetailView.swift`, `apple/Sources/Features/Crews/CrewDetailView.swift`.

**Interfaces:** none new — replace `ProgressView()`-forever fallbacks with a loaded-but-empty state distinct from still-loading.

- [ ] **Step 1: LineupEditorView + RaceHeatLoader empty state**

`LineupEditorView` currently shows `ProgressView()` whenever `model.lineup`/`roster`/`boat` is nil. Distinguish "still loading" from "loaded, nothing to show": add a `@State private var didLoad = false` set to `true` at the end of the `.task` (after `await model?.load()`). Render:
- while `!didLoad` → `ProgressView()`
- `didLoad` but `model?.lineup == nil` (no valid placement — e.g. the heat's race/crew is missing) → a `ScreenScaffold("Lineup", note: "This race has no crew assigned yet — set one on the crew before building a lineup.")` (or similar clear message).
- else → the editor content.

Likewise, in `RaceHeatLoader`, if resolving/creating the heat fails, show a short "Couldn't open the lineup." message instead of a perpetual `ProgressView`.

- [ ] **Step 2: PaddlerDetailView + CrewDetailView not-found state**

Both spin forever if the entity isn't found. Add the same `didLoad` pattern: after `.task`'s `await model?.load()`, if the paddler/crew is still nil, show `ScreenScaffold("Not found", note: "This record is no longer available.")` instead of `ProgressView()`.

- [ ] **Step 3: Build + verify** — iOS + macOS green, count unchanged.
- [ ] **Step 4: Commit** — `git commit -m "feat(app): empty/error states replace infinite spinners (editor, detail views)"`

---

## Task 3: Correctness fixes + coverage (swap guard, gender-rule test, heats test)

**Files:** Modify `apple/Sources/Features/Lineup/LineupViewModel.swift`, `apple/Sources/Features/Squad/SquadView.swift`; Tests `LineupSwapGuardTests.swift`, `CrewGenderRuleTests.swift`, `HeatsQueryTests.swift`.

- [ ] **Step 1: Write the failing tests**

```swift
// apple/Tests/PaddltirAppTests/LineupSwapGuardTests.swift
import Foundation
import PaddltirCore
import Testing
@testable import Paddltir

@MainActor @Suite struct LineupSwapGuardTests {
    private func vm() -> LineupViewModel {
        let db = try! AppDatabase.inMemory()
        let m = LineupViewModel(db: db)
        let paddlers = (1...4).map { i in
            Paddler(id: PaddlerID("p\(i)"), name: "P\(i)", weightKg: 70, ergM: 600,
                    side: .either, gender: .female, seatPref: .none, role: .paddler)
        }
        m._injectForTest(request: PlacementRequest(boat: .small, roster: Roster(paddlers),
                                                   candidates: paddlers.map(\.id), current: Lineup(boat: .small)),
                         heat: Heat(id: "h", raceId: "r", name: "H", sortOrder: 0, drummerId: nil, sweepId: nil, createdAt: Date(), updatedAt: nil))
        return m
    }
    @Test func swappingTwoEmptySeatsIsANoOpAndDoesNotEnableUndo() {
        let m = vm()
        m.tapSeat(Seat(bench: 1, side: .left))    // select empty seat
        m.tapSeat(Seat(bench: 2, side: .left))    // "swap" with another empty seat
        #expect(m.canUndo == false)               // nothing changed → no undo snapshot
    }
}
```

```swift
// apple/Tests/PaddltirAppTests/CrewGenderRuleTests.swift
import Foundation
import GRDB
import Testing
@testable import Paddltir

@MainActor @Suite struct CrewGenderRuleTests {
    private let t0 = Date(timeIntervalSince1970: 1_700_000_000)
    @Test func womenOnlyCrewWithAManViolates() async throws {
        let db = try AppDatabase.inMemory()
        try db.write { d in
            try Club(id: "c1", name: "C", inviteCode: "ABCD2345", createdBy: nil, createdAt: t0, updatedAt: nil).insert(d)
            try Crew(id: "cr1", clubId: "c1", name: "W", ageDivision: "Premier", category: .women, createdAt: t0, updatedAt: nil).insert(d)
            // women category, standard boat → max_men 0
            try CategoryRule(clubId: "c1", category: .women, boatSize: .standard, minWomen: nil, maxWomen: nil, minMen: nil, maxMen: 0, updatedAt: t0).insert(d)
            try PaddlerRow(id: "m1", clubId: "c1", profileId: nil, name: "Man", email: nil, weightKg: 80, preferredSide: .left, gender: .male, seatPreference: .none, boatRole: .paddler, archivedAt: nil, createdAt: t0, updatedAt: nil).insert(d)
            try CrewMember(crewId: "cr1", paddlerId: "m1", createdAt: t0).insert(d)
        }
        let model = CrewDetailModel(crewId: "cr1", db: db)
        await model.load()
        #expect(model.ruleVerdict != nil)   // a man in a women-only crew is a violation
    }
}
```

```swift
// apple/Tests/PaddltirAppTests/HeatsQueryTests.swift
import Foundation
import GRDB
import Testing
@testable import Paddltir

@Suite struct HeatsQueryTests {
    private let t0 = Date(timeIntervalSince1970: 1_700_000_000)
    @Test func heatsReturnedInSortOrder() async throws {
        let db = try AppDatabase.inMemory()
        try db.write { d in
            try Heat(id: "b", raceId: "r", name: "Heat 2", sortOrder: 1, drummerId: nil, sweepId: nil, createdAt: t0, updatedAt: nil).insert(d)
            try Heat(id: "a", raceId: "r", name: "Heat 1", sortOrder: 0, drummerId: nil, sweepId: nil, createdAt: t0, updatedAt: nil).insert(d)
            try Heat(id: "c", raceId: "other", name: "X", sortOrder: 0, drummerId: nil, sweepId: nil, createdAt: t0, updatedAt: nil).insert(d)
        }
        let heats = try await LineupRepository(db: db).heats(raceId: "r")
        #expect(heats.map(\.id) == ["a", "b"])   // sort_order, only race "r"
    }
}
```

- [ ] **Step 2: Run to verify they fail** — the swap-guard test fails (current code pushes undo for the empty swap); the others need `CrewDetailModel`/`heats` to be accessible (they exist) — run and confirm the swap-guard RED specifically.

- [ ] **Step 3: Implement the guard + clubId guard**

In `LineupViewModel.tapSeat`, the `.seat(let s)` case: only mutate if at least one of the two seats is occupied (a swap of two empties changes nothing). Change:
```swift
        case .seat(let s):
            if s == seat { selection = nil }
            else if lineup?.paddler(at: s) == nil && lineup?.paddler(at: seat) == nil { selection = nil }  // both empty → no-op
            else { mutate { $0.swap(s, seat) }; selection = nil }
```
In `SquadView`'s add-paddler `.sheet`, guard the empty clubId — only present the form when the club id is non-empty (e.g. `if !clubId.isEmpty { PaddlerFormView(...) } else { Text("No club").padding() }`), so a paddler can never be created with `clubId == ""`.

- [ ] **Step 4: Run to verify pass** — all three tests PASS; whole suite green.
- [ ] **Step 5: Commit** — `git commit -m "fix(app): guard empty-seat swap + empty clubId; cover gender-rule + heats query"`

---

## Task 4: `.dsMono` typography token + AuthView placeholder fix

**Files:** Modify `apple/Sources/DesignSystem/Typography.swift`, `apple/Sources/Features/Settings/SettingsView.swift`, `apple/Sources/App/AuthView.swift` (+ any invite-code/erg mono call sites).

- [ ] **Step 1: Add `.dsMono`** to `Typography.swift` (this is the ONE sanctioned `Font.system` — a DS token, not an ad-hoc call site):
```swift
    static let dsMono       = Font.system(size: 15, weight: .medium, design: .monospaced)  // invite codes, fixed-width IDs
```

- [ ] **Step 2: Use it** — in `SettingsView`, replace the invite-code `Text(code).font(.system(.body, design: .monospaced))` with `.font(.dsMono)`. (Grep `Font.system` under `apple/Sources/Features` and `apple/Sources/App` and route any remaining monospaced usages through `.dsMono`.)

- [ ] **Step 3: Fix the AuthView email placeholder** — the `TextField("you@club.com", text: $email)` renders its placeholder/text teal because `RootView`'s `.tint(DS.accent)` bleeds in. Make the field's text `DS.ink` and neutralize the tint locally so the placeholder is the muted default: add `.foregroundStyle(DS.ink)` and `.tint(DS.ink)` to the email `TextField` (and the DEBUG dev field if similarly affected). Verify visually in Step 5.

- [ ] **Step 4: Build + verify** — iOS + macOS green, zero warnings; `grep -rn "Font.system" apple/Sources/Features apple/Sources/App` returns only the DEBUG/none (mono routed through the token; the token itself lives in Typography.swift).

- [ ] **Step 5: Screenshot** (controller, or note for Task 6): re-capture AuthView; confirm the email placeholder is muted grey, not teal. Commit:
```bash
git commit -m "feat(app): .dsMono typography token; fix AuthView email placeholder tint"
```

---

## Task 5: Accessibility pass (hull + key labels)

**Files:** Modify `apple/Sources/Features/Lineup/HullGrid.swift` (and light labels where cheap).

- [ ] **Step 1: Empty-seat + occupied-seat accessibility labels** in `HullGrid`

The empty seat slot renders bare "L"/"R" with no context. Add an `.accessibilityLabel` to each seat cell so VoiceOver announces bench + side + occupancy, e.g.:
```swift
.accessibilityElement(children: .combine)
.accessibilityLabel("Bench \(seat.bench) \(seat.side == .left ? "left" : "right"), \(lineup.paddler(at: seat) == nil ? "empty" : (roster.byID[lineup.paddler(at: seat)!]?.name ?? "occupied"))")
.accessibilityHint("Double-tap to select")
```
(Apply to the seat cell button; keep the visible content unchanged.)

- [ ] **Step 2: Build + verify** — iOS + macOS green, count unchanged. (VoiceOver labels are verified by reading the code + the build; a full audit is a later pass — note the scope.)
- [ ] **Step 3: Commit** — `git commit -m "feat(app): accessibility labels on hull seats"`

---

## Task 6: Integration, verification & wrap

**Files:** none new — verification + docs.

- [ ] **Step 1: Full build gate (iOS + macOS), whole suite green** — regenerate; iOS test gate (all new tests: swap guard, gender rule, heats) + macOS build. Expect gated live tests skipped, ZERO Swift warnings.
- [ ] **Step 2: Gated live tests once** (controller): `ClubServiceLiveTests` + `SupabaseRemoteTests` still pass.
- [ ] **Step 3: Screenshots** (controller, via `PADDLTIR_DEBUG_AUTOSIGNIN=1` + tab/deep-link envs): now that sync-completion refresh (Task 1) lands, a **single** launch should populate Schedule/Squad/Crews (no two-launch trick needed). Re-capture `4g-schedule.png`, `4g-squad.png`, `4g-crews.png`, and `4g-auth.png` (verify the placeholder fix). Attempt the editor via the deep-link against a heat with a valid crew chain (or note the seed gap). Surface to Jun.
- [ ] **Step 4: Offline smoke** (controller, brief): confirm the app renders cached data with the stack stopped is out of scope to fully script; at minimum confirm the suite's offline unit tests (all non-gated tests use in-memory GRDB, no network) pass — that IS the offline correctness gate.
- [ ] **Step 5: Update PROGRESS.md + roadmap** (post-merge, on main): mark 4g merged and **Plan 4 (coach app) COMPLETE**; record the deferred "premium polish" list (drag, Optimise@go-live, multi-heat nav, Share, section bands, Mac inspector, redo, long-press menu, filter chips, availability notes, erg recordedBy, per-heat gender check, full a11y/Mac audit). Next up: Plan 5 (paddler PWA) + go-live.
- [ ] **Step 6: Commit** verification artifacts.

---

## Self-Review

**Spec coverage (§3 quality floor + roadmap 4g):**
- End-to-end against the merged backend / offline-first → Task 1 (sync-completion refresh makes pulled data appear) + Task 6 (gated live + offline unit gate). ✓
- No dead-end spinners → Task 2. ✓
- Accessibility pass → Task 5 (hull seats; broader audit noted as deferred). ✓ (partial, documented)
- Mac layout pass → LIGHT (builds + runs verified each task); full centred-hull+inspector redesign **deferred** (documented). ⚠️ (intentional)
- Cosmetic floor (mono, placeholder) → Task 4. ✓
- Correctness/coverage gaps → Task 3. ✓

**Placeholder scan:** no "TBD"/"handle errors" — each task has concrete code or a concrete edit. The empty-state copy strings are real. Task 4's placeholder-fix mechanism names the exact modifiers; if `.tint(DS.ink)` doesn't fully neutralize the placeholder on this SDK, the implementer states what they used.

**Type consistency:** `AppEnvironment.syncGeneration` read identically in the three views. `CrewDetailModel(crewId:db:)` / `LineupRepository.heats(raceId:)` / `LineupViewModel._injectForTest` match their real signatures. `Roster(paddlers)` (no label). `CategoryRule`/`Crew`/`Heat`/`PaddlerRow` initializers match the shipped models.

**Known deferrals (flag at merge):** the entire "premium polish" list in Global Constraints (drag, Optimise, multi-heat nav, Share, section bands, Mac inspector, redo, long-press menu, filter chips, availability notes, erg recordedBy, per-heat gender check, full a11y + Mac audit). These are additive and don't block a robust, correct app.

## Execution Handoff

**Plan complete and saved to `docs/superpowers/plans/2026-08-25-plan-4g-integration-polish.md`.** Executing via subagent-driven-development: fresh implementer per task, task review after each, final whole-branch review before merge. This completes Plan 4 (the coach app); next is Plan 5 (paddler PWA) and go-live.

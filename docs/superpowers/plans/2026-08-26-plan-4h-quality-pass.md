# Plan 4h — Coach App Quality Pass Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Raise the 4c–4g app layer from "correct and verified" to premium-grade: reactive data flow (screens observe the database and update themselves — no reload hacks), one clean view-model ownership pattern, real error surfaces that never discard cached data, deduplicated boilerplate, and the lineup editor's premium interactions (drag-and-drop with haptics + spring motion, long-press seat menu, redo, multi-heat switching, section bands, wide-screen inspector).

**Architecture:** Repositories gain `observe…()` methods returning GRDB `ValueObservation`s (built on the same fetch code as the existing one-shot reads — no duplicated queries). View-models expose `observe() async` that iterates `observation.values(in:)` inside the view's `.task` (SwiftUI cancels it on disappear), so every write — local or synced — flows to the UI automatically. `AppEnvironment.syncGeneration`, every `.onChange` reload, every `didLoad` flag, and every `await load()`-after-write disappear. Views construct their view-model eagerly in `init(db:)` via `State(initialValue:)` — no optional models, no lazy `.task` creation. Reads never clear state on failure; write failures surface as a `StatusBanner`. The lineup editor gains drag-and-drop (`.draggable`/`.dropDestination` with the paddler id as the payload), `.sensoryFeedback`, spring animation keyed on the `Lineup` value, a context menu, redo, a live multi-heat `HeatSwitcher`, section-band shading, `GenderBadge`, and a hull + inspector layout on wide screens. All lineup logic still delegates to `PaddltirCore.Lineup`.

**Tech Stack:** SwiftUI + Observation, GRDB 7.11.1 `ValueObservation` (`.tracking { db in … }.values(in:)` → `AsyncValueObservation`), `PaddltirCore`, the 4a DesignSystem, Swift 6 strict concurrency.

**Spec:** `docs/superpowers/specs/2026-08-22-paddltir-design.md` — §3 (offline-first: "pull on launch/foreground … Realtime when online"; the lineup editor's drag/swap/long-press/undo-redo/heat-switcher interactions; the quality floor). Visual direction: `docs/design/direction.md`. Baseline: the merged Plan 4g tree (see `PROGRESS.md` → "PLAN 4h CANDIDATE").

## Global Constraints

- **Rename:** any in-product "CrewCoach" → **Paddltir**.
- **Platforms:** iOS 26 + macOS 26; every change compiles + lays out on both; guard platform-only APIs with `#if os(...)`. `@Environment(\.horizontalSizeClass)` is iOS-only — on macOS treat the window as wide via `#if os(macOS)`.
- **Design system — REAL names only:** spacing `DS.Space.{xs,s,m,l,xl}`; radius `DS.R.{card,ctl,sm,tile}`; typography `.font(.dsX)` — `.dsLargeTitle/.dsTitle/.dsHeadline/.dsSubhead/.dsBody/.dsCallout/.dsFootnote/.dsCaption/.dsMicro/.dsMono`; colors `DS.bg/.surface/.surface2/.ink/.ink2/.ink3/.border/.border2/.accent/.good/.danger/.maleFill/.maleBorder/.femaleFill/.femaleBorder/.primary/.onPrimary`; components `HairlineCard(padding:content:)`, `MicroLabel(_)`, `Pill(_ , tint:, foreground:)`, `PrimaryButton`/`SecondaryButton`, `GlassBar(radius:content:)`/`GlassContainer`, `ScreenScaffold(_:note:)`, `SeatTile(name:side:weightKg:gender:violatesPref:lifted:)`, `TelemetryGrid(metrics:boat:)`, `BalanceBeam(imbalance:label:)`, `HeatSwitcher(names:selection:onAdd:)`, `GenderBadge(metrics:)` / `GenderBadge(women:men:)`, `AvailabilityRing`, and the NEW `StatusBanner` (Task 5). Never raw hex; `Font.system` only inside `Typography.swift`.
- **Light mode only.**
- **All lineup/domain logic stays in `PaddltirCore`** (`Lineup.place/.swap/.remove/.setLocked`, `Scoring.evaluate`, `Greedy`, `Suggestions`). Writes remain atomic (mutation + `Outbox.enqueue` in one `db.write`) — this plan does not touch the write paths' transactions.
- **Repositories + PaddltirCore stay UI-free** (`import Foundation`/`GRDB`/`PaddltirCore` only; snapshot structs are plain `Equatable, Sendable` values).
- **Reads never clear state on failure.** A failing observation keeps the last value and sets `lastError`. `try? … ?? []` on a read is forbidden after this plan.
- **Sendable discipline:** `ValueObservation.tracking`'s fetch closure is `@Sendable`; observed values must be `Sendable` (all row models, `PaddlerWithErg`, `GenderRule`, and the new snapshot structs are). Static fetch functions (`Self.fetchX(_ db: Database)`) are the shared, Sendable-safe way to reuse a read for both `read` and `tracking`.
- **Build gate:** `cd apple && xcodegen generate && xcodebuild -scheme Paddltir -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -derivedDataPath DerivedData test` — regenerate first. Also `xcodebuild -scheme Paddltir -destination 'platform=macOS' build`. Live Supabase tests stay gated + skipped by default. No secrets committed.
- **Explicitly OUT OF SCOPE:** Optimise (server MIP — go-live/Plan 6); Share snapshot; availability free-text note editing; erg `recordedBy`; the side/gender/role squad filter chips; per-heat boat-size gender check; heat rename/duplicate/delete (only add + switch ship here).

## Current-state facts (verified against the merged 4g tree)

- `AppDatabase { let dbQueue: DatabaseQueue; func read/write }` — `dbQueue` is a `DatabaseReader`, the `values(in:)` argument.
- GRDB: `ValueObservation.tracking(_ fetch: @escaping @Sendable (Database) throws -> Value) -> ValueObservation<ValueReducers.Fetch<Value>>`; `.values(in: any DatabaseReader, scheduling: some ValueObservationScheduler = .task) -> AsyncValueObservation<Value>` (an `AsyncSequence`; `for try await`); the first emission is the current value.
- Repositories (structs, `let db: AppDatabase`): `SquadRepository.paddlers()/paddler(id:)/ergHistory(paddlerId:)/upsert/archive/recordErg`; `CrewRepository.crews()/crew(id:)/racesForCrew/summaries(now:)/createCrew/setMembers` + nested `CrewSummary`; `ScheduleRepository.sessions()/session(id:)→(session, availability)/races(sessionId:)/createSession/setAvailability/createRace`; `LineupRepository.heat(id:)/saveSeats/placementRequest/createHeat/saveHeat/heats(raceId:)`.
- `PaddlerWithErg.join(rows:ergs:)`; `DomainMapping.genderRule(_ rule: CategoryRule?) -> GenderRule?`; `Headcount.compute(availability:squadSize:)`; `ScheduleGrouping.upNext/upcoming/past`; `GenderTally.of(_:)`.
- `AppEnvironment` (`@MainActor @Observable`): `client`, `db`, `isSyncing`, `lastSyncError`, `syncGeneration` (to be removed), `sync()`. `AppModel { environment, session }`. `RootView` `.ready` → `MainShell()` with `.task { sync }` + scenePhase resync; `MainShell` tabs: `ScheduleView()`, `CrewsView()`, `SquadView()`, `SettingsView()` (+ DEBUG `DesignSystemGallery`, `DebugFirstHeatEditor` cover).
- View-models: `ScheduleViewModel(db:now:)` (`load()`, `createTraining/RaceDay`, `headcount(for:)`, `clubId`), `SquadViewModel(db:)` (`filter`, `sort`, `all`, `visible`, `load()`), `CrewsViewModel(db:)` (`summaries`, `clubId`, `load()`, `createCrew`), `TrainingDetailModel(session:db:)`, `RaceDayModel(session:db:)`, `CrewDetailModel(crewId:db:)` (`ruleVerdict`, `toggle`), `PaddlerDetailModel(paddlerId:db:clubId:)`, `LineupViewModel(db:)` (`load(heatId:)`, `tapSeat`, `tapReserve`, `unseat`, `undo`, `mutate`, `reserves`, `metrics`, `beamImbalance`, `autoFill`, `suggestions`, `apply`, `save`, DEBUG `_injectForTest`).
- Views: `ScheduleView`, `SquadView`, `CrewsView`, `TrainingDetailView`, `RaceDayDetailView` (+ `RaceFormView`, `RaceHeatLoader`), `CrewDetailView`, `PaddlerDetailView`, `LineupEditorView` (+ private `SuggestionsSheet`), `HullGrid(lineup:roster:selection:onTapSeat:)`. All use the `@State private var model: X?` + `.task { if model == nil { model = X(db: app.environment.db) }; await model?.load(); didLoad = true }` pattern this plan removes.
- `PaddlerWithErg: Identifiable` (extension in TrainingDetailView.swift). `Lineup: Hashable` (so it can be an `.animation(value:)` / `.sensoryFeedback(trigger:)` key). `PaddlerID(rawValue)`, `.rawValue: String`.

## File Structure

New:
- `Sources/Features/Shared/Loadable.swift` — `enum Loadable<Value>`.
- `Sources/DesignSystem/Components/StatusBanner.swift` — the error banner.
- `Sources/Features/Lineup/HullActions.swift` — the hull's action bundle (drop/unseat/lock/drummer/sweep).
- Tests: `ObservationTests.swift`, `AppEnvironmentClubTests.swift`, `ReactiveViewModelTests.swift`, `LineupInteractionTests.swift`.

Modified: all four repositories (observe methods + snapshot structs); `AppEnvironment.swift`, `RootView.swift`; every view-model + view listed above; `HullGrid.swift`, `LineupEditorView.swift`, `RaceDayDetailView.swift` (RaceHeatLoader removed); `Typography.swift` untouched.

---

## Task 1: Observation foundation — repository `observe…()` + snapshot structs + `Loadable`

**Files:**
- Create: `apple/Sources/Features/Shared/Loadable.swift`
- Modify: `apple/Sources/Data/Repositories/SquadRepository.swift`, `CrewRepository.swift`, `ScheduleRepository.swift`, `LineupRepository.swift`
- Test: `apple/Tests/PaddltirAppTests/ObservationTests.swift`

**Interfaces (Produces):**
- `enum Loadable<Value: Equatable & Sendable>: Equatable, Sendable { case loading; case loaded(Value); case failed(String) ; var value: Value? }`
- `SquadRepository`: `static func fetchPaddlers(_ db: Database) throws -> [PaddlerWithErg]`; `func observePaddlers() -> ValueObservation<ValueReducers.Fetch<[PaddlerWithErg]>>`; `struct PaddlerDetail: Equatable, Sendable { var paddler: PaddlerWithErg?; var ergHistory: [ErgTest] }`; `func observePaddlerDetail(id: String) -> ValueObservation<ValueReducers.Fetch<PaddlerDetail>>`.
- `CrewRepository`: `func observeSummaries(now: Date) -> ValueObservation<ValueReducers.Fetch<[CrewSummary]>>`; `struct CrewDetail: Equatable, Sendable { var crew: Crew?; var members: [PaddlerWithErg]; var races: [Race]; var squad: [PaddlerWithErg]; var rule: GenderRule? }`; `func observeCrewDetail(id: String) -> ValueObservation<ValueReducers.Fetch<CrewDetail>>`.
- `ScheduleRepository`: `struct ScheduleSnapshot: Equatable, Sendable { var sessions: [SessionRow]; var squadSize: Int; var availabilityBySession: [String: [Availability]] }`; `func observeSchedule() -> ValueObservation<ValueReducers.Fetch<ScheduleSnapshot>>`; `func scheduleSnapshot() async throws -> ScheduleSnapshot`; `struct TrainingDetail: Equatable, Sendable { var paddlers: [PaddlerWithErg]; var availability: [Availability] }`; `func observeTrainingDetail(sessionId: String)`; `struct RaceDaySnapshot: Equatable, Sendable { var races: [Race]; var crews: [Crew]; var availability: [Availability]; var squadSize: Int }`; `func observeRaceDay(sessionId: String)`.
- `LineupRepository`: `func observeHeats(raceId: String) -> ValueObservation<ValueReducers.Fetch<[Heat]>>`.
- `CrewSummary` gains `Equatable` (it's already `Hashable` → fine) — confirm it's `Sendable` (it is).

- [ ] **Step 1: Write the failing tests**

```swift
// apple/Tests/PaddltirAppTests/ObservationTests.swift
import Foundation
import GRDB
import Testing
@testable import Paddltir

@Suite struct ObservationTests {
    private let t0 = Date(timeIntervalSince1970: 1_700_000_000)

    private func paddler(_ id: String, _ name: String) -> PaddlerRow {
        PaddlerRow(id: id, clubId: "c1", profileId: nil, name: name, email: nil, weightKg: 70,
                   preferredSide: .left, gender: .female, seatPreference: .none, boatRole: .paddler,
                   archivedAt: nil, createdAt: t0, updatedAt: nil)
    }

    @Test func observePaddlersEmitsInitialThenUpdate() async throws {
        let appDB = try AppDatabase.inMemory()
        var iterator = SquadRepository(db: appDB).observePaddlers().values(in: appDB.dbQueue).makeAsyncIterator()
        let first = try await iterator.next()
        #expect(first?.isEmpty == true)                       // initial value: empty squad
        try appDB.write { db in try paddler("p1", "Ava").insert(db) }
        let second = try await iterator.next()
        #expect(second?.map(\.row.name) == ["Ava"])            // change delivered without any reload call
    }

    @Test func observeScheduleSnapshotTracksSessionsAndSquad() async throws {
        let appDB = try AppDatabase.inMemory()
        var iterator = ScheduleRepository(db: appDB).observeSchedule().values(in: appDB.dbQueue).makeAsyncIterator()
        _ = try await iterator.next()
        try appDB.write { db in
            try paddler("p1", "Ava").insert(db)
            try SessionRow(id: "s1", clubId: "c1", kind: .training, title: "T", startsAt: t0, venue: nil, notes: nil, createdAt: t0, updatedAt: nil).insert(db)
            try Availability(sessionId: "s1", paddlerId: "p1", status: .in, note: nil, updatedAt: t0).insert(db)
        }
        let snap = try await iterator.next()
        #expect(snap?.sessions.map(\.id) == ["s1"])
        #expect(snap?.squadSize == 1)
        #expect(snap?.availabilityBySession["s1"]?.count == 1)
    }

    @Test func loadableValueAccessor() {
        #expect(Loadable<Int>.loading.value == nil)
        #expect(Loadable<Int>.loaded(3).value == 3)
        #expect(Loadable<Int>.failed("x").value == nil)
    }
}
```

- [ ] **Step 2: Run to verify they fail** — `cd apple && xcodegen generate && xcodebuild … test 2>&1 | grep -iE "ObservationTests|observePaddlers|error:"`. Expected: FAIL — `has no member 'observePaddlers'` / `cannot find 'Loadable'`.

- [ ] **Step 3: Implement**

`Loadable`:
```swift
// apple/Sources/Features/Shared/Loadable.swift
// Screen state for observed data: loading (no value yet), loaded, or failed
// (a read error — the UI keeps showing the last value if it had one and
// surfaces the message). Read failures never discard data.
import Foundation

enum Loadable<Value: Equatable & Sendable>: Equatable, Sendable {
    case loading
    case loaded(Value)
    case failed(String)

    var value: Value? { if case .loaded(let v) = self { return v } else { return nil } }
    var isLoading: Bool { if case .loading = self { return true } else { return false } }
}
```

`SquadRepository` — refactor the read into a shared static fetch and add observations:
```swift
    /// Shared fetch used by both the one-shot read and the observation
    /// (static + `@Sendable`-safe so GRDB's tracking closure can call it).
    static func fetchPaddlers(_ db: Database) throws -> [PaddlerWithErg] {
        let rows = try PaddlerRow.filter(Column("archived_at") == nil).order(Column("name")).fetchAll(db)
        let ergs = try ErgTest.filter(rows.map(\.id).contains(Column("paddler_id"))).fetchAll(db)
        return PaddlerWithErg.join(rows: rows, ergs: ergs)
    }
    func paddlers() async throws -> [PaddlerWithErg] { try db.read(Self.fetchPaddlers) }
    /// Emits the current squad, then again whenever paddlers/erg_tests change.
    func observePaddlers() -> ValueObservation<ValueReducers.Fetch<[PaddlerWithErg]>> {
        ValueObservation.tracking(Self.fetchPaddlers)
    }

    struct PaddlerDetail: Equatable, Sendable { var paddler: PaddlerWithErg?; var ergHistory: [ErgTest] }
    static func fetchPaddlerDetail(_ db: Database, id: String) throws -> PaddlerDetail {
        guard let row = try PaddlerRow.fetchOne(db, key: id) else { return PaddlerDetail(paddler: nil, ergHistory: []) }
        let ergs = try ErgTest.filter(Column("paddler_id") == id).order(Column("tested_at")).fetchAll(db)
        return PaddlerDetail(paddler: PaddlerWithErg.join(rows: [row], ergs: ergs).first, ergHistory: ergs)
    }
    func observePaddlerDetail(id: String) -> ValueObservation<ValueReducers.Fetch<PaddlerDetail>> {
        ValueObservation.tracking { db in try Self.fetchPaddlerDetail(db, id: id) }
    }
```
(Keep `paddler(id:)`/`ergHistory` as thin wrappers over the new static fetch where they overlap; do not duplicate query bodies.)

`CrewRepository`:
```swift
    static func fetchSummaries(_ db: Database, now: Date) throws -> [CrewSummary] { /* move the existing body of summaries(now:) here */ }
    func summaries(now: Date) async throws -> [CrewSummary] { try db.read { try Self.fetchSummaries($0, now: now) } }
    func observeSummaries(now: Date) -> ValueObservation<ValueReducers.Fetch<[CrewSummary]>> {
        ValueObservation.tracking { db in try Self.fetchSummaries(db, now: now) }
    }

    struct CrewDetail: Equatable, Sendable {
        var crew: Crew?; var members: [PaddlerWithErg]; var races: [Race]; var squad: [PaddlerWithErg]; var rule: GenderRule?
    }
    static func fetchCrewDetail(_ db: Database, id: String) throws -> CrewDetail {
        guard let crew = try Crew.fetchOne(db, key: id) else { return CrewDetail(crew: nil, members: [], races: [], squad: [], rule: nil) }
        let memberIds = try CrewMember.filter(Column("crew_id") == id).fetchAll(db).map(\.paddlerId)
        let rows = try PaddlerRow.filter(memberIds.contains(Column("id"))).order(Column("name")).fetchAll(db)
        let ergs = try ErgTest.filter(memberIds.contains(Column("paddler_id"))).fetchAll(db)
        let races = try Race.filter(Column("crew_id") == id).order(Column("sort_order")).fetchAll(db)
        let squad = try SquadRepository.fetchPaddlers(db)
        let key: [String: (any DatabaseValueConvertible)?] = ["club_id": crew.clubId, "category": crew.category.rawValue, "boat_size": BoatSize.standard.rawValue]
        let rule = DomainMapping.genderRule(try CategoryRule.fetchOne(db, key: key))
        return CrewDetail(crew: crew, members: PaddlerWithErg.join(rows: rows, ergs: ergs), races: races, squad: squad, rule: rule)
    }
    func observeCrewDetail(id: String) -> ValueObservation<ValueReducers.Fetch<CrewDetail>> {
        ValueObservation.tracking { db in try Self.fetchCrewDetail(db, id: id) }
    }
```
(`CrewRepository` must `import PaddltirCore` for `GenderRule`; it's a UI-free import.)

`ScheduleRepository`:
```swift
    struct ScheduleSnapshot: Equatable, Sendable {
        var sessions: [SessionRow]; var squadSize: Int; var availabilityBySession: [String: [Availability]]
    }
    static func fetchSchedule(_ db: Database) throws -> ScheduleSnapshot {
        let sessions = try SessionRow.order(Column("starts_at")).fetchAll(db)
        let squadSize = try PaddlerRow.filter(Column("archived_at") == nil).fetchCount(db)
        let availability = Dictionary(grouping: try Availability.fetchAll(db), by: \.sessionId)
        return ScheduleSnapshot(sessions: sessions, squadSize: squadSize, availabilityBySession: availability)
    }
    func scheduleSnapshot() async throws -> ScheduleSnapshot { try db.read(Self.fetchSchedule) }
    func observeSchedule() -> ValueObservation<ValueReducers.Fetch<ScheduleSnapshot>> { ValueObservation.tracking(Self.fetchSchedule) }

    struct TrainingDetail: Equatable, Sendable { var paddlers: [PaddlerWithErg]; var availability: [Availability] }
    func observeTrainingDetail(sessionId: String) -> ValueObservation<ValueReducers.Fetch<TrainingDetail>> {
        ValueObservation.tracking { db in
            TrainingDetail(paddlers: try SquadRepository.fetchPaddlers(db),
                           availability: try Availability.filter(Column("session_id") == sessionId).fetchAll(db))
        }
    }

    struct RaceDaySnapshot: Equatable, Sendable { var races: [Race]; var crews: [Crew]; var availability: [Availability]; var squadSize: Int }
    func observeRaceDay(sessionId: String) -> ValueObservation<ValueReducers.Fetch<RaceDaySnapshot>> {
        ValueObservation.tracking { db in
            RaceDaySnapshot(races: try Race.filter(Column("session_id") == sessionId).order(Column("sort_order")).fetchAll(db),
                            crews: try Crew.order(Column("name")).fetchAll(db),
                            availability: try Availability.filter(Column("session_id") == sessionId).fetchAll(db),
                            squadSize: try PaddlerRow.filter(Column("archived_at") == nil).fetchCount(db))
        }
    }
```

`LineupRepository`:
```swift
    func observeHeats(raceId: String) -> ValueObservation<ValueReducers.Fetch<[Heat]>> {
        ValueObservation.tracking { db in try Heat.filter(Column("race_id") == raceId).order(Column("sort_order")).fetchAll(db) }
    }
```

- [ ] **Step 4: Run to verify pass** — grep `ObservationTests|TEST SUCCEEDED`. Expected: 3 tests PASS; whole suite green (existing repository tests unchanged — the one-shot reads still work).
- [ ] **Step 5: Commit** — `git commit -m "feat(app): repository ValueObservations + snapshot structs + Loadable"`

---

## Task 2: `AppEnvironment` — observed `clubId`, drop `syncGeneration`

**Files:** Modify `apple/Sources/App/AppEnvironment.swift`, `apple/Sources/App/RootView.swift`; Test `apple/Tests/PaddltirAppTests/AppEnvironmentClubTests.swift`.

**Interfaces:** `AppEnvironment` gains `private(set) var clubId: String?` and `func observeClub() async` (long-lived; iterates `ValueObservation.tracking { try Club.fetchOne($0)?.id }`). `syncGeneration` is REMOVED (its only readers — the three tab views' `.onChange` — are removed in Task 3; to keep the build green across tasks, Task 2 removes the property AND the three `.onChange(of: app.environment.syncGeneration)` blocks in `ScheduleView`/`SquadView`/`CrewsView`).

- [ ] **Step 1: Write the failing test**

```swift
// apple/Tests/PaddltirAppTests/AppEnvironmentClubTests.swift
import Foundation
import GRDB
import Supabase
import Testing
@testable import Paddltir

@MainActor @Suite struct AppEnvironmentClubTests {
    @Test func clubIdFollowsTheLocalClubRow() async throws {
        let db = try AppDatabase.inMemory()
        let client = SupabaseClient(supabaseURL: URL(string: Secrets.supabaseURL)!, supabaseKey: Secrets.supabaseAnonKey)
        let env = AppEnvironment(client: client, db: db)
        let task = Task { await env.observeClub() }
        defer { task.cancel() }
        try db.write { d in try Club(id: "c1", name: "C", inviteCode: "ABCD2345", createdBy: nil, createdAt: Date(), updatedAt: nil).insert(d) }
        // Observation delivers asynchronously; poll briefly.
        for _ in 0..<50 where env.clubId != "c1" { try await Task.sleep(for: .milliseconds(40)) }
        #expect(env.clubId == "c1")
    }
}
```

- [ ] **Step 2: Run to verify it fails** — grep `AppEnvironmentClub|observeClub|error:`. Expected: FAIL — `has no member 'observeClub'`.

- [ ] **Step 3: Implement**

In `AppEnvironment`: delete `syncGeneration` (property + the `syncGeneration += 1` line + its doc comment); add `import GRDB`; add:
```swift
    /// The single club this install mirrors (nil until onboarding/sync lands
    /// a `clubs` row). Observed from GRDB so it's always current.
    private(set) var clubId: String?

    /// Long-lived: keeps `clubId` in step with the local `clubs` row. Run from
    /// RootView's `.task` — SwiftUI cancels it with the view.
    func observeClub() async {
        let observation = ValueObservation.tracking { db in try Club.fetchOne(db)?.id }
        do {
            for try await id in observation.values(in: db.dbQueue) { clubId = id }
        } catch { /* keep the last known club id */ }
    }
```
In `RootView`'s `.ready` branch add a second task: `.task { await environment.observeClub() }` (alongside the existing `.task { await environment.sync() }`).
In `ScheduleView`, `SquadView`, `CrewsView`: delete the `.onChange(of: app.environment.syncGeneration) { … }` block (Task 3 replaces reloads with observation).

- [ ] **Step 4: Run to verify pass** — grep `AppEnvironmentClubTests|TEST SUCCEEDED`; `grep -rn syncGeneration apple/Sources` is empty. Whole suite green.
- [ ] **Step 5: Commit** — `git commit -m "feat(app): AppEnvironment observes clubId; remove syncGeneration"`

---

## Task 3: Reactive tab view-models + eager view construction (Schedule / Squad / Crews)

**Files:** Modify `ScheduleViewModel.swift`, `ScheduleView.swift`, `SquadViewModel.swift`, `SquadView.swift`, `CrewsView.swift` (VM + view), `RootView.swift` (MainShell passes `db:`); Test `ReactiveViewModelTests.swift` (+ update `ScheduleViewModelTests`/`SquadViewModelTests` where noted).

**Interfaces:**
- `ScheduleViewModel(db:now:)`: `private(set) var isLoaded = false`, `private(set) var lastError: String?`, `func observe() async`, `func load() async` (single snapshot; tests/previews), `func createTraining(clubId: String, title:startsAt:venue:notes:) async`, `createRaceDay(clubId:…)`. `clubId` and `headcount(for:)` are REMOVED (headcount comes from the snapshot; club id from `AppEnvironment.clubId`).
- `SquadViewModel(db:)`: adds `isLoaded`, `lastError`, `observe()`; keeps `load()`, `filter`, `sort`, `all`, `visible`.
- `CrewsViewModel(db:)`: `summaries`, `isLoaded`, `lastError`, `observe()`, `load()`, `createCrew(clubId:name:division:category:)` (no reload; `clubId` property removed).
- Views: `ScheduleView(db: AppDatabase)`, `SquadView(db:)`, `CrewsView(db:)` — `@State private var model` (non-optional) via `State(initialValue:)`; `.task { await model.observe() }`; club id read from `app.environment.clubId`.

- [ ] **Step 1: Write the failing test**

```swift
// apple/Tests/PaddltirAppTests/ReactiveViewModelTests.swift
import Foundation
import GRDB
import Testing
@testable import Paddltir

@MainActor @Suite struct ReactiveViewModelTests {
    private let now = Date(timeIntervalSince1970: 1_700_000_000)

    @Test func squadViewModelObservesInserts() async throws {
        let db = try AppDatabase.inMemory()
        let vm = SquadViewModel(db: db)
        let task = Task { await vm.observe() }
        defer { task.cancel() }
        for _ in 0..<50 where !vm.isLoaded { try await Task.sleep(for: .milliseconds(40)) }
        #expect(vm.isLoaded && vm.all.isEmpty)
        try db.write { d in
            try PaddlerRow(id: "p1", clubId: "c", profileId: nil, name: "Ava", email: nil, weightKg: 60, preferredSide: .left,
                           gender: .female, seatPreference: .none, boatRole: .paddler, archivedAt: nil, createdAt: now, updatedAt: nil).insert(d)
        }
        for _ in 0..<50 where vm.all.isEmpty { try await Task.sleep(for: .milliseconds(40)) }
        #expect(vm.all.map(\.row.name) == ["Ava"])       // no load() call — the observation delivered it
    }

    @Test func scheduleCreateFlowsBackThroughObservation() async throws {
        let db = try AppDatabase.inMemory()
        let vm = ScheduleViewModel(db: db, now: { self.now })
        let task = Task { await vm.observe() }
        defer { task.cancel() }
        for _ in 0..<50 where !vm.isLoaded { try await Task.sleep(for: .milliseconds(40)) }
        await vm.createTraining(clubId: "c1", title: "New paddle", startsAt: now.addingTimeInterval(3600), venue: nil, notes: nil)
        for _ in 0..<50 where vm.upNext == nil { try await Task.sleep(for: .milliseconds(40)) }
        #expect(vm.upNext?.title == "New paddle")
    }
}
```

- [ ] **Step 2: Run to verify it fails** — grep `ReactiveViewModel|observe\(\)|error:`. Expected: FAIL — `has no member 'observe'` / `isLoaded`.

- [ ] **Step 3: Implement**

`ScheduleViewModel` (full replacement of the load/create logic):
```swift
@MainActor @Observable
final class ScheduleViewModel {
    private(set) var upNext: SessionRow?
    private(set) var upNextHeadcount: Headcount?
    private(set) var upcoming: [DaySection] = []
    private(set) var past: [DaySection] = []
    private(set) var squadSize = 0
    private(set) var isLoaded = false
    private(set) var lastError: String?

    private let schedule: ScheduleRepository
    private let db: AppDatabase
    private let now: () -> Date

    init(db: AppDatabase, now: @escaping () -> Date = Date.init) {
        self.db = db; self.schedule = ScheduleRepository(db: db); self.now = now
    }

    /// Long-lived: run from the view's `.task`. Every DB change re-emits.
    func observe() async {
        do {
            for try await snapshot in schedule.observeSchedule().values(in: db.dbQueue) { apply(snapshot) }
        } catch { lastError = error.localizedDescription }   // keep the last good state
    }

    /// One-shot (tests / previews).
    func load() async {
        do { apply(try await schedule.scheduleSnapshot()) } catch { lastError = error.localizedDescription }
    }

    private func apply(_ s: ScheduleRepository.ScheduleSnapshot) {
        let n = now()
        squadSize = s.squadSize
        upNext = ScheduleGrouping.upNext(s.sessions, now: n)
        upcoming = ScheduleGrouping.upcoming(s.sessions.filter { $0.id != upNext?.id }, now: n)
        past = ScheduleGrouping.past(s.sessions, now: n)
        upNextHeadcount = upNext.map { Headcount.compute(availability: s.availabilityBySession[$0.id] ?? [], squadSize: s.squadSize) }
        isLoaded = true
        lastError = nil
    }

    func createTraining(clubId: String, title: String, startsAt: Date, venue: String?, notes: String?) async {
        await create(clubId: clubId, kind: .training, title: title, startsAt: startsAt, venue: venue, notes: notes)
    }
    func createRaceDay(clubId: String, title: String, startsAt: Date, venue: String?, notes: String?) async {
        await create(clubId: clubId, kind: .raceDay, title: title, startsAt: startsAt, venue: venue, notes: notes)
    }
    private func create(clubId: String, kind: SessionKind, title: String, startsAt: Date, venue: String?, notes: String?) async {
        do { _ = try await schedule.createSession(clubId: clubId, kind: kind, title: title, startsAt: startsAt, venue: venue, notes: notes) }
        catch { lastError = error.localizedDescription }
        // No reload: the observation delivers the new session.
    }
}
```
Update `ScheduleViewModelTests`: `loadComposesGroupingsAndClub` drops the `vm.clubId` assertion (club id no longer lives here) and `createTrainingWritesThenReloads` calls `createTraining(clubId: "club-1", …)` then `await vm.load()` explicitly (the one-shot path doesn't observe).

`SquadViewModel`:
```swift
@MainActor @Observable
final class SquadViewModel {
    var filter = SquadFilter()
    var sort: SquadSort = .name
    private(set) var all: [PaddlerWithErg] = []
    private(set) var isLoaded = false
    private(set) var lastError: String?
    private let squad: SquadRepository
    private let db: AppDatabase
    init(db: AppDatabase) { self.db = db; self.squad = SquadRepository(db: db) }
    var visible: [PaddlerWithErg] { SquadQuery.apply(all, filter: filter, sort: sort) }
    func observe() async {
        do { for try await rows in squad.observePaddlers().values(in: db.dbQueue) { all = rows; isLoaded = true; lastError = nil } }
        catch { lastError = error.localizedDescription }
    }
    func load() async { do { all = try await squad.paddlers(); isLoaded = true } catch { lastError = error.localizedDescription } }
    func add(_ row: PaddlerRow) async { do { try await squad.upsert(row) } catch { lastError = error.localizedDescription } }
}
```

`CrewsViewModel` (same shape): `observe()` over `crews.observeSummaries(now: Date())`, `load()`, `createCrew(clubId:name:division:category:)` with do/catch → `lastError`, no reload.

Views — the ownership pattern (apply to all three):
```swift
struct SquadView: View {
    @Environment(AppModel.self) private var app
    @State private var model: SquadViewModel
    @State private var adding = false

    init(db: AppDatabase) { _model = State(initialValue: SquadViewModel(db: db)) }

    var body: some View {
        NavigationStack {
            content
                .navigationTitle("Squad")
                .background(DS.bg)
                .toolbar { ToolbarItem(placement: .primaryAction) { Button { adding = true } label: { Image(systemName: "plus") } }.disabled(app.environment.clubId == nil) }
                .navigationDestination(for: PaddlerWithErg.self) { pw in PaddlerDetailView(paddlerId: pw.row.id, db: app.environment.db) }
                .sheet(isPresented: $adding) {
                    if let clubId = app.environment.clubId {
                        PaddlerFormView(clubId: clubId, existing: nil) { row in await model.add(row) }
                    }
                }
        }
        .task { await model.observe() }
    }
    // content: uses `model` directly (no `if let`); shows ProgressView only while !model.isLoaded && model.all.isEmpty
}
```
`ScheduleView(db:)` and `CrewsView(db:)` follow the same shape (`createTraining(clubId: clubId, …)` via `if let clubId = app.environment.clubId`). `MainShell` (RootView) passes `app.environment.db`: it needs `@Environment(AppModel.self) private var app` and renders `ScheduleView(db: app.environment.db)` etc. at all call sites (iOS tabs + macOS `macDetail`). `PaddlerDetailView(paddlerId:db:)` exists after Task 4 — to keep Task 3 building, Task 3 passes `db:` only if Task 4 landed; **execute Task 4 before Task 3's view edits if needed** (see Pre-flight ordering note) — simplest: Task 3 leaves navigation destinations calling the CURRENT detail-view initializers, and Task 4 updates those call sites when it changes the detail inits.

- [ ] **Step 4: Run to verify pass** — grep `ReactiveViewModelTests|ScheduleViewModelTests|SquadViewModelTests|TEST SUCCEEDED`; whole suite green; iOS + macOS build.
- [ ] **Step 5: Commit** — `git commit -m "feat(app): reactive tab view-models; eager view construction; no reload hacks"`

---

## Task 4: Reactive detail models + call-site cleanup

**Files:** Modify `TrainingDetailView.swift`, `RaceDayDetailView.swift`, `CrewDetailView.swift`, `PaddlerDetailView.swift`, `LineupEditorView.swift`, `RootView.swift` (DebugFirstHeatEditor), and the three tab views' `navigationDestination` call sites.

**Interfaces:**
- `TrainingDetailModel(session:db:)`: `paddlers`, `availability: [String: Availability]`, `headcount`, `isLoaded`, `lastError`, `observe()`, `setStatus`, `recordErg` (no reload after writes).
- `RaceDayModel(session:db:)`: `races`, `crews`, `crewNames`, `headcount`, `isLoaded`, `lastError`, `observe()`, `addRace`.
- `CrewDetailModel(crewId:db:)`: `crew`, `members`, `races`, `squad`, `ruleVerdict`, `tally`, `memberIds`, `isLoaded`, `lastError`, `observe()`, `toggle`. (Keeps `load()` for `CrewGenderRuleTests`.)
- `PaddlerDetailModel(paddlerId:db:)`: `paddler`, `ergHistory`, `isLoaded`, `lastError`, `observe()`, `save`, `archive`. (`clubId` param REMOVED — the edit form gets `app.environment.clubId`.)
- Views: `TrainingDetailView(session:db:)`, `RaceDayDetailView(session:db:)`, `CrewDetailView(crewId:db:)`, `PaddlerDetailView(paddlerId:db:)`, `RaceHeatLoader(race:db:)`, `LineupEditorView(heatId:raceName:db:)` — all eager `State(initialValue:)`; `didLoad` removed everywhere (use `model.isLoaded`).

- [ ] **Step 1: Implement one detail model in full — `CrewDetailModel`** (the others follow the identical shape):

```swift
@MainActor @Observable
final class CrewDetailModel {
    let crewId: String
    private(set) var crew: Crew?
    private(set) var members: [PaddlerWithErg] = []
    private(set) var races: [Race] = []
    private(set) var squad: [PaddlerWithErg] = []
    private(set) var ruleVerdict: String?
    private(set) var tally = GenderTally(women: 0, men: 0)
    private(set) var isLoaded = false
    private(set) var lastError: String?
    private let crews: CrewRepository
    private let db: AppDatabase

    init(crewId: String, db: AppDatabase) { self.crewId = crewId; self.db = db; self.crews = CrewRepository(db: db) }

    var memberIds: Set<String> { Set(members.map(\.row.id)) }

    func observe() async {
        do { for try await detail in crews.observeCrewDetail(id: crewId).values(in: db.dbQueue) { apply(detail) } }
        catch { lastError = error.localizedDescription }
    }
    func load() async {
        do { apply(try db.read { try CrewRepository.fetchCrewDetail($0, id: crewId) }) } catch { lastError = error.localizedDescription }
    }
    private func apply(_ d: CrewRepository.CrewDetail) {
        crew = d.crew; members = d.members; races = d.races; squad = d.squad
        tally = GenderTally.of(d.members)
        ruleVerdict = d.rule?.violation(women: tally.women, men: tally.men)
        isLoaded = true; lastError = nil
    }
    func toggle(_ paddlerId: String) async {
        var ids = memberIds
        if ids.contains(paddlerId) { ids.remove(paddlerId) } else { ids.insert(paddlerId) }
        do { try await crews.setMembers(crewId: crewId, paddlerIds: Array(ids)) } catch { lastError = error.localizedDescription }
    }
}
```
`CrewDetailView`: `init(crewId: String, db: AppDatabase) { self.crewId = crewId; _model = State(initialValue: CrewDetailModel(crewId: crewId, db: db)) }`; body: `if model.crew != nil { content } else if model.isLoaded { ScreenScaffold("Not found", …) } else { ProgressView() }`; `.task { await model.observe() }`. `CrewGenderRuleTests` keeps using `load()` (unchanged assertion).

- [ ] **Step 2: Apply the same shape** to `TrainingDetailModel` (`observeTrainingDetail(sessionId:)` → `paddlers` + `availability` dict; `setStatus`/`recordErg` do/catch, no reload), `RaceDayModel` (`observeRaceDay(sessionId:)` → `races`, `crews`, `crewNames`, `headcount`; `addRace` no reload), `PaddlerDetailModel` (`observePaddlerDetail(id:)`; `save`/`archive` no reload — `archive` still dismisses from the view). `RaceHeatLoader(race:db:)` keeps its resolve-or-create `.task` (a write) with `isResolved`/`failed` state instead of `didLoad`. `LineupEditorView(heatId:raceName:db:)` constructs `LineupViewModel(db:)` eagerly; keeps `load(heatId:)` (the editor edits a local `Lineup` value) with `model.isLoaded` replacing `didLoad` (add `private(set) var isLoaded = false` to `LineupViewModel.load`). `DebugFirstHeatEditor` passes `db: app.environment.db`. Update every `navigationDestination` call site to the new inits. `grep -rn "didLoad" apple/Sources` → empty; `grep -rn "model: .*?$" apple/Sources/Features` → no optional view-models remain.

- [ ] **Step 3: Build + verify** — iOS gate (suite green — 100+ tests) + macOS build; the two greps above empty.
- [ ] **Step 4: Commit** — `git commit -m "feat(app): reactive detail models; eager construction; didLoad + reload-after-write removed"`

---

## Task 5: Error surfaces — `StatusBanner` + sync banner + write-error banners

**Files:** Create `apple/Sources/DesignSystem/Components/StatusBanner.swift`; Modify `RootView.swift` (MainShell), the tab + detail views.

**Interfaces:** `public struct StatusBanner: View { public init(_ message: String, actionTitle: String? = nil, action: (() -> Void)? = nil) }`.

- [ ] **Step 1: The component**

```swift
// apple/Sources/DesignSystem/Components/StatusBanner.swift
// Non-blocking status strip (hairline card, danger glyph) for "couldn't sync"
// and write failures. Optional trailing action (e.g. Retry). Never covers
// content — callers place it at the top of a screen.
import SwiftUI

public struct StatusBanner: View {
    let message: String
    var actionTitle: String?
    var action: (() -> Void)?

    public init(_ message: String, actionTitle: String? = nil, action: (() -> Void)? = nil) {
        self.message = message; self.actionTitle = actionTitle; self.action = action
    }

    public var body: some View {
        HStack(spacing: DS.Space.s) {
            Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(DS.danger)
            Text(message).font(.dsCaption).foregroundStyle(DS.ink).lineLimit(2)
            Spacer(minLength: DS.Space.s)
            if let actionTitle, let action {
                Button(actionTitle, action: action).font(.dsCaption.weight(.semibold)).foregroundStyle(DS.accent).buttonStyle(.plain)
            }
        }
        .padding(DS.Space.m)
        .background(DS.surface, in: .rect(cornerRadius: DS.R.ctl))
        .overlay(RoundedRectangle(cornerRadius: DS.R.ctl).stroke(DS.border))
        .accessibilityElement(children: .combine)
    }
}
```

- [ ] **Step 2: Wire it** — `MainShell` gets `@Environment(AppEnvironment.self) private var environment` and, on the iOS `TabView` and macOS `NavigationSplitView`, a `.safeAreaInset(edge: .top)` showing `StatusBanner("Couldn't sync — showing saved data.", actionTitle: "Retry") { Task { await environment.sync() } }` when `environment.lastSyncError != nil`. Each tab/detail view shows `if let e = model.lastError { StatusBanner(e) }` at the top of its content (padding `DS.Space.l` horizontal). Add a `StatusBanner` sample to `DesignSystemGallery` (DEBUG) so it's screenshot-verifiable.
- [ ] **Step 3: Build + verify** — iOS + macOS green.
- [ ] **Step 4: Commit** — `git commit -m "feat(app): StatusBanner; sync + write-error surfaces (cached data never discarded)"`

---

## Task 6: Lineup editor interactions — drag & drop, context menu, redo (VM + tests + views)

**Files:** Modify `LineupViewModel.swift`, `HullGrid.swift`, `LineupEditorView.swift`; Create `apple/Sources/Features/Lineup/HullActions.swift`; Test `LineupInteractionTests.swift`.

**Interfaces:**
- `LineupViewModel` adds: `private(set) var canRedo = false`; `func dragDrop(_ id: PaddlerID, onto seat: Seat)`; `func dropOnTray(_ id: PaddlerID)`; `func toggleLock(_ seat: Seat)`; `func setDrummer(_ id: PaddlerID?)`; `func setSweep(_ id: PaddlerID?)`; `func redo()`. `mutate` now clears the redo stack; `undo` pushes onto it.
- `struct HullActions { var tap: (Seat) -> Void; var drop: (PaddlerID, Seat) -> Void; var unseat: (Seat) -> Void; var toggleLock: (Seat) -> Void; var setDrummer: (PaddlerID) -> Void; var setSweep: (PaddlerID) -> Void }`; `HullGrid(lineup:roster:selection:actions:)` (replaces `onTapSeat:`).

- [ ] **Step 1: Write the failing tests**

```swift
// apple/Tests/PaddltirAppTests/LineupInteractionTests.swift
import Foundation
import PaddltirCore
import Testing
@testable import Paddltir

@MainActor @Suite struct LineupInteractionTests {
    private func vm() -> LineupViewModel {
        let db = try! AppDatabase.inMemory()
        let m = LineupViewModel(db: db)
        let paddlers = (1...4).map { i in
            Paddler(id: PaddlerID("p\(i)"), name: "P\(i)", weightKg: 70, ergM: 600, side: .either,
                    gender: i % 2 == 0 ? .male : .female, seatPref: .none, role: .paddler)
        }
        m._injectForTest(request: PlacementRequest(boat: .small, roster: Roster(paddlers), candidates: paddlers.map(\.id), current: Lineup(boat: .small)),
                         heat: Heat(id: "h", raceId: "r", name: "H", sortOrder: 0, drummerId: nil, sweepId: nil, createdAt: Date(), updatedAt: nil))
        return m
    }
    private let a = Seat(bench: 1, side: .left), b = Seat(bench: 1, side: .right), c = Seat(bench: 2, side: .left)

    @Test func dragReserveOntoEmptySeatPlaces() {
        let m = vm(); m.dragDrop(PaddlerID("p1"), onto: a)
        #expect(m.lineup?.paddler(at: a) == PaddlerID("p1"))
    }
    @Test func dragSeatedOntoOccupiedSwaps() {
        let m = vm(); m.dragDrop(PaddlerID("p1"), onto: a); m.dragDrop(PaddlerID("p2"), onto: b)
        m.dragDrop(PaddlerID("p1"), onto: b)
        #expect(m.lineup?.paddler(at: b) == PaddlerID("p1")); #expect(m.lineup?.paddler(at: a) == PaddlerID("p2"))
    }
    @Test func dragSeatedOntoEmptyMoves() {
        let m = vm(); m.dragDrop(PaddlerID("p1"), onto: a); m.dragDrop(PaddlerID("p1"), onto: c)
        #expect(m.lineup?.paddler(at: a) == nil); #expect(m.lineup?.paddler(at: c) == PaddlerID("p1"))
    }
    @Test func dropOnTrayUnseats() {
        let m = vm(); m.dragDrop(PaddlerID("p1"), onto: a); m.dropOnTray(PaddlerID("p1"))
        #expect(m.lineup?.seatedIDs.isEmpty == true); #expect(m.reserves.contains(PaddlerID("p1")))
    }
    @Test func lockTogglesAndDrummerLeavesTheSeats() {
        let m = vm(); m.dragDrop(PaddlerID("p1"), onto: a)
        m.toggleLock(a); #expect(m.lineup?.isLocked(a) == true)
        m.setDrummer(PaddlerID("p1"))
        #expect(m.lineup?.drummerId == PaddlerID("p1")); #expect(m.lineup?.paddler(at: a) == nil)
        #expect(m.reserves.contains(PaddlerID("p1")) == false)   // drummer isn't a reserve
    }
    @Test func undoThenRedoRoundTrips() {
        let m = vm(); m.dragDrop(PaddlerID("p1"), onto: a)
        m.undo(); #expect(m.lineup?.paddler(at: a) == nil); #expect(m.canRedo)
        m.redo(); #expect(m.lineup?.paddler(at: a) == PaddlerID("p1")); #expect(m.canRedo == false)
        m.dragDrop(PaddlerID("p2"), onto: b)   // a new mutation clears redo
        m.undo(); m.undo(); #expect(m.canRedo)
        m.dragDrop(PaddlerID("p3"), onto: c); #expect(m.canRedo == false)
    }
}
```

- [ ] **Step 2: Run to verify they fail** — grep `LineupInteraction|dragDrop|error:`. Expected: FAIL — `has no member 'dragDrop'`.

- [ ] **Step 3: Implement the VM**

In `LineupViewModel`: add `private var redoStack: [Lineup] = []` and `private(set) var canRedo = false`. Change `mutate` to also `redoStack.removeAll(); canRedo = false`. Change `undo` to push the current lineup onto `redoStack` before restoring (`canRedo = true`). Add:
```swift
    func redo() {
        guard let next = redoStack.popLast(), let current = lineup else { return }
        undoStack.append(current); canUndo = true
        lineup = next; canRedo = !redoStack.isEmpty; selection = nil
    }

    /// Drag-and-drop: a reserve or a seated paddler dropped onto a seat.
    /// Seated → occupied = swap; seated → empty = move; reserve → any = place
    /// (an evicted occupant returns to the reserves). All via Lineup.
    func dragDrop(_ id: PaddlerID, onto seat: Seat) {
        guard let current = lineup else { return }
        if let from = current.seat(of: id) {
            guard from != seat else { return }
            if current.paddler(at: seat) != nil { mutate { $0.swap(from, seat) } } else { mutate { $0.place(id, at: seat) } }
        } else {
            mutate { $0.place(id, at: seat) }
        }
        selection = nil
    }

    func dropOnTray(_ id: PaddlerID) {
        guard lineup?.seat(of: id) != nil else { return }
        mutate { $0.remove(id) }; selection = nil
    }

    func toggleLock(_ seat: Seat) {
        guard let current = lineup, current.paddler(at: seat) != nil else { return }
        mutate { $0.setLocked(!current.isLocked(seat), at: seat) }
    }

    /// Drummer/sweep can't also hold a bench seat; assigning removes them from the hull.
    func setDrummer(_ id: PaddlerID?) {
        mutate { l in if let id { l.remove(id); if l.sweepId == id { l.sweepId = nil } }; l.drummerId = id }
    }
    func setSweep(_ id: PaddlerID?) {
        mutate { l in if let id { l.remove(id); if l.drummerId == id { l.drummerId = nil } }; l.sweepId = id }
    }
```

- [ ] **Step 4: Run to verify pass** — grep `LineupInteractionTests|LineupViewModelTests|LineupSwapGuardTests|TEST SUCCEEDED` (existing tests must still pass; `undo` behavior unchanged for them).

- [ ] **Step 5: Views — `HullActions` + drag/drop + context menu + feedback**

```swift
// apple/Sources/Features/Lineup/HullActions.swift
// The hull's outbound actions, bundled so HullGrid's init stays readable.
import PaddltirCore

struct HullActions {
    var tap: (Seat) -> Void
    var drop: (PaddlerID, Seat) -> Void
    var unseat: (Seat) -> Void
    var toggleLock: (Seat) -> Void
    var setDrummer: (PaddlerID) -> Void
    var setSweep: (PaddlerID) -> Void
}
```
`HullGrid`: replace `onTapSeat` with `let actions: HullActions`. In `seatCell`:
- occupied cell: `.draggable(pid.rawValue)` (String is `Transferable`; the payload is the paddler id) and `.contextMenu { Button("Unseat") { actions.unseat(seat) }; Button(lineup.isLocked(seat) ? "Unlock seat" : "Lock seat") { actions.toggleLock(seat) }; Button("Set as drummer") { actions.setDrummer(pid) }; Button("Set as sweep") { actions.setSweep(pid) } }`;
- every cell: `.dropDestination(for: String.self) { items, _ in guard let raw = items.first else { return false }; actions.drop(PaddlerID(raw), seat); return true }`;
- locked seats show a small `Image(systemName: "lock.fill")` badge (`DS.ink3`, top-trailing overlay).
`LineupEditorView`: build `HullActions` from the model (each action → the VM call + `Task { await model.save() }`); reserves chips `.draggable(id.rawValue)`; the reserves container `.dropDestination(for: String.self) { items, _ in … model.dropOnTray(PaddlerID(raw)); save; return true }`; a "Redo" tool button (`arrow.uturn.forward`, disabled when `!model.canRedo`); on the hull: `.animation(.spring(response: 0.3, dampingFraction: 0.8), value: model.lineup)` and `.sensoryFeedback(.impact(weight: .light), trigger: model.lineup)`.

- [ ] **Step 6: Build + verify** — iOS + macOS green (drag/drop + contextMenu + sensoryFeedback compile on both).
- [ ] **Step 7: Commit** — `git commit -m "feat(app): lineup drag-and-drop, context menu, redo, haptics + spring motion"`

---

## Task 7: Editor structure — multi-heat switcher, section bands, GenderBadge, wide-screen inspector

**Files:** Modify `LineupViewModel.swift`, `LineupEditorView.swift`, `HullGrid.swift`, `RaceDayDetailView.swift` (delete `RaceHeatLoader`), `RootView.swift` (DebugFirstHeatEditor).

**Interfaces:**
- `LineupViewModel` adds `private(set) var heats: [Heat] = []`, `var selectedHeatIndex = 0`, `func observeHeats(raceId: String) async` (observation; auto-creates "Heat 1" if a race has none; loads the selected heat when the index changes), `func addHeat(raceId: String) async`.
- `LineupEditorView(race: Race, db: AppDatabase)` (replaces `heatId:raceName:`); `RaceDayDetailView`'s `navigationDestination(for: Race.self)` → `LineupEditorView(race: race, db: app.environment.db)`; `RaceHeatLoader` DELETED.

- [ ] **Step 1: VM** — add:
```swift
    private(set) var heats: [Heat] = []
    var selectedHeatIndex = 0 { didSet { if let h = heats[safe: selectedHeatIndex], h.id != heat?.id { Task { await load(heatId: h.id) } } } }

    /// Long-lived: mirrors the race's heats; creates "Heat 1" for a race with none.
    func observeHeats(raceId: String) async {
        do {
            for try await list in repo.observeHeats(raceId: raceId).values(in: db.dbQueue) {
                if list.isEmpty { _ = try await repo.createHeat(raceId: raceId, name: "Heat 1"); continue }
                heats = list
                if heat == nil, let first = list.first { await load(heatId: first.id) }
            }
        } catch { lastError = error.localizedDescription }
    }
    func addHeat(raceId: String) async {
        do { let h = try await repo.createHeat(raceId: raceId, name: "Heat \(heats.count + 1)"); selectedHeatIndex = heats.count; await load(heatId: h.id) }
        catch { lastError = error.localizedDescription }
    }
```
(Add a tiny `extension Array { subscript(safe i: Int) -> Element? }` in `Shared/`.) Add `private(set) var lastError: String?` to the VM if not present.

- [ ] **Step 2: View** — `LineupEditorView(race:db:)`: `.task { await model.observeHeats(raceId: race.id) }`; `HeatSwitcher(names: model.heats.map(\.name), selection: $model.selectedHeatIndex, onAdd: { Task { await model.addHeat(raceId: race.id) } })` (use `@Bindable`); `GenderBadge(metrics: metrics)` replaces the hand-rolled W/M row; section bands in `HullGrid`: each bench row's background = `sectionFill(bench)` where stroke/sprint rows use `DS.surface2` and pace/engine `DS.surface` (a subtle band; label unchanged). Wide layout: `private var isWide: Bool { #if os(macOS) true #else sizeClass == .regular #endif }` with `@Environment(\.horizontalSizeClass)` guarded `#if os(iOS)`; when wide, `HStack(alignment: .top, spacing: DS.Space.l) { hullColumn; inspector.frame(width: 360) }` where the inspector holds the Balance HUD + reserves + toolbar; otherwise the existing vertical stack. Delete `RaceHeatLoader`; `RaceDayDetailView` pushes `LineupEditorView(race:db:)`; `DebugFirstHeatEditor` fetches the first `Race` (`Race.order(Column("sort_order")).fetchOne`) and shows `LineupEditorView(race:db:)`.
- [ ] **Step 3: Build + verify** — iOS + macOS green; `grep -rn RaceHeatLoader apple/Sources` empty; `grep -rn "W \\\\(metrics.women)" apple/Sources` empty.
- [ ] **Step 4: Commit** — `git commit -m "feat(app): multi-heat switcher, section bands, GenderBadge, wide-screen inspector"`

---

## Task 8: Integration, verification & wrap (controller)

- [ ] **Step 1:** Full gates — iOS suite (expect ≥ 104 tests: 95 + 3 + 1 + 2 + 6 − 0; count whatever the run reports) with gated live tests skipped, zero warnings; macOS build.
- [ ] **Step 2:** Gated live tests once against the local stack.
- [ ] **Step 3:** Screenshots via the DEBUG env hooks — a **fresh install + single launch** per tab (the reactive flow must populate without any reload); the editor via `PADDLTIR_DEBUG_OPEN_FIRST_HEAT=1 PADDLTIR_DEBUG_AUTOFILL=1` (the editor now auto-creates a heat and shows the multi-heat switcher; if the seed's first race still lacks a crew, the "no crew assigned" state renders — that is a valid screenshot of Task 4/4g's empty state). Save as `apple/screenshots/4h-*.png`; surface to Jun.
- [ ] **Step 4:** Update `PROGRESS.md` + roadmap: mark 4h merged; record what's still deferred (Optimise@go-live, Share, filter chips, availability notes, erg recordedBy, per-heat gender check, heat rename/delete, full a11y audit).
- [ ] **Step 5:** Commit docs.

---

## Self-Review

**Spec coverage:** offline-first "pull … Realtime when online" → the reactive observation layer (T1–T4) makes every screen live-updating from the local mirror, which is what sync feeds. ✓ Editor spec: drag (T6), tap-tap (exists), long-press menu lock/reserve/drummer/sweep (T6 — "Mark reserve" = Unseat), undo/redo (T6), heat switcher with `+` (T7), balance HUD with gender badge (T7), Mac/iPad hull + inspector (T7). ✓ Quality floor: no dead-end spinners, error surfaces (T5), a11y kept from 4g. ✓

**Placeholder scan:** every task has real code; T4's "same shape" instruction is anchored by a full `CrewDetailModel` implementation and the exact per-model observation names from T1; T2 names the exact `.onChange` blocks to delete; T7 names the exact `Array[safe:]` helper. No TBDs.

**Type consistency:** `observeX()` names match between T1 (defs) and T3/T4/T7 (uses); snapshot struct field names (`sessions/squadSize/availabilityBySession`, `paddlers/availability`, `races/crews/availability/squadSize`, `crew/members/races/squad/rule`, `paddler/ergHistory`) consistent; `HullActions` field names match `HullGrid` uses and the editor's construction; `Loadable` defined in T1 (used optionally — VMs use `isLoaded` + `lastError`, which is the simpler surface; `Loadable` is available for any screen that wants a single state value — if unused after T4, delete it in T8 to avoid dead code and note it).

**Execution ordering note (controller):** T3 and T4 touch the same navigation call sites; execute T3 then T4 exactly as written (T3 leaves detail-view initializers as-is; T4 changes them + the call sites). T2 must precede T3 (it removes `syncGeneration` readers). T6 before T7 (T7 builds on `HullActions`).

## Execution Handoff

**Plan complete and saved to `docs/superpowers/plans/2026-08-26-plan-4h-quality-pass.md`.** Executing via subagent-driven-development after Plan 4g merges: fresh implementer per task, task review after each, final whole-branch review before merge.

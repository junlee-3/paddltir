# Plan 4f — Lineup Editor (the hero) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build the lineup editor — a legible hull grid where the coach assigns paddlers to seats (tap-to-select, tap-to-place/swap), a live Balance HUD driven by `PaddltirCore` on every change, a reserves tray of unseated crew, a heat switcher, and offline **Auto-fill** (greedy) + **Suggest** (top swaps) — with undo. Wired in from the race-day detail's lineup stub.

**Architecture:** A `@MainActor @Observable LineupViewModel` loads a heat's `PlacementRequest` + `Heat`/`SeatRow`s (Plan 4b `LineupRepository`), holds a `PaddltirCore.Lineup` value + a `selection` + an undo stack, and resolves taps into `Lineup.place`/`.swap`/`.remove`. Balance is `PaddltirCore.Scoring.evaluate(lineup, roster:)` → `Metrics`, rendered by the ready-made 4a `TelemetryGrid`/`BalanceBeam`; seats render with 4a `SeatTile`; the switcher is 4a `HeatSwitcher`. Auto-fill is `Greedy.autoFill`, Suggest is `Suggestions.swaps`. Saving writes seats (`saveSeats`) and the heat's drummer/sweep/name (new `saveHeat`). The engine (repo + view-model) is TDD; the views are screenshot-verified.

**Tech Stack:** SwiftUI + Observation, `PaddltirCore` (`Lineup`/`Boat`/`Metrics`/`Greedy`/`Suggestions`/`Scoring`), GRDB (Plan 4b `LineupRepository`/`Outbox`), the 4a DesignSystem (`SeatTile`/`TelemetryGrid`/`BalanceBeam`/`HeatSwitcher`/`GlassBar`), the Plan 4c `AppModel` shell.

**Spec:** `docs/superpowers/specs/2026-08-22-paddltir-design.md` — §3 "Lineup editor — the hero screen". Visual direction: `docs/design/direction.md`.

## Global Constraints

- **Rename:** any in-product "CrewCoach" → **Paddltir**.
- **Platforms:** one target, iOS 26 + macOS 26; every view compiles + lays out on both; guard platform-only APIs with `#if os(...)`.
- **Design system — REAL names only** (do NOT invent): spacing `DS.Space.{xs,s,m,l,xl}`; radius `DS.R.{card,ctl,sm,tile}`; typography `.font(.dsX)` (`.dsLargeTitle/.dsTitle/.dsHeadline/.dsSubhead/.dsBody/.dsCallout/.dsCaption/.dsFootnote/.dsMicro`); colors `DS.bg/.surface/.surface2/.ink/.ink2/.ink3/.border/.border2/.accent/.good/.danger/.maleFill/.maleBorder/.femaleFill/.femaleBorder/.primary/.onPrimary`; components `HairlineCard(padding:content:)`, `MicroLabel(_)`, `Pill(_ , tint:, foreground:)` (the param is **`tint:`**, NOT `fill:`), `PrimaryButton`/`SecondaryButton`, `GlassBar(radius:content:)`/`GlassContainer(radius:content:)`, `SeatTile(name:side:weightKg:gender:violatesPref:lifted:)` (gender is `PaddltirCore.Gender`), `TelemetryGrid(metrics:boat:thresholds:)`, `BalanceBeam(imbalance:label:)`, `HeatSwitcher(names:selection:onAdd:)`. Never raw hex or `Font.system` (mono via `.font(.system(.body, design: .monospaced))`).
- **Light mode only.** Style through DS tokens/components.
- **All lineup logic lives in `PaddltirCore`** — the view-model only orchestrates. Mutate seats via `Lineup.place/.swap/.remove(at:)` (value type; keeps assignments canonical). Balance via `Scoring.evaluate`. Auto-fill via `Greedy.autoFill`. Suggest via `Suggestions.swaps`. Do NOT reimplement any of these.
- **Writes = GRDB mutation + `Outbox.enqueue` in ONE `db.write`** (mirrors `CrewRepository.setMembers` / the 4d/4e writes): payload via `PostgREST.encoder`, `pk` via `syncPrimaryKey`, `op` `"insert"`/`"update"`. `saveSeats` already exists (diff-based, enqueues seat deletes/updates); add `saveHeat`/`createHeat`.
- **Repositories + PaddltirCore stay UI-free.** Live Supabase tests gated + skipped by default. No secrets committed.
- **Club-id read gotcha:** `try? db.read { db in try Club.fetchOne(db)?.id }` yields `String??`; flatten (`?? nil`, or read with `try` in a do/catch). (This editor loads by heatId, so it rarely needs club-id — but if any view reads it, flatten it.)
- **Build gate:** `cd apple && xcodegen generate && xcodebuild -scheme Paddltir -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -derivedDataPath DerivedData test` — regenerate first. Also `xcodebuild -scheme Paddltir -destination 'platform=macOS' build`.
- **Scope / deferrals (explicit):** ships tap-to-select + tap-to-place/swap + unseat + undo + Auto-fill + Suggest + heat switch/create + Balance HUD + reserves. **DEFERRED:** drag-and-drop + haptics + swap animations; **Optimise** (server MIP — the solver isn't deployed until go-live/Plan 6); Share image snapshot; per-reserve "unavailable today" dimming; heat rename/duplicate/delete. Note these in the editor (an Optimise button may be present but disabled with a "coming soon" hint, or omitted) — do not half-build the server round-trip.

## Data facts (verified — use these exactly)
- `LineupRepository` (Plan 4b): `heat(id:) -> (heat: Heat, seats: [SeatRow], reserves: [HeatReserve])?`; `saveSeats(heatId:seats: [SeatRow])`; `placementRequest(heatId:) -> PlacementRequest?` (assembles boat/roster/candidates/drummer/sweep/locked/rule/current).
- `Heat`: `id, raceId, name, sortOrder, drummerId?, sweepId?, createdAt, updatedAt?`. `SeatRow`: `heatId, bench, side (BoatSide: left/right), paddlerId, locked, updatedAt?`.
- `PlacementRequest`: `boat: Boat, roster: Roster, candidates: [PaddlerID], drummerId: PaddlerID?, sweepId: PaddlerID?, locked: [SeatAssignment], rule: GenderRule?, current: Lineup?`.
- `PaddltirCore.Lineup(boat:drummerId:sweepId:assignments:)`: mutating `place(_ id: PaddlerID, at: Seat)`, `remove(at: Seat)`, `remove(_ id: PaddlerID)`, `swap(_ s1: Seat, _ s2: Seat)`, `setLocked(_:at:)`; `paddler(at: Seat) -> PaddlerID?`, `seat(of: PaddlerID) -> Seat?`, `seatedIDs: Set<PaddlerID>`, `isLocked(_:)`, `assignments: [SeatAssignment]` (each `{bench, side: Side, paddlerId, locked}`), `boat`, `drummerId`, `sweepId`. `Seat(bench: Int, side: Side)`. `Boat`: `benches`, `benchRange` (1...benches), `capacity`, `allSeats`, `section(ofBench:) -> Section`, `arm(ofBench:)`.
- `Scoring.evaluate(_ lineup: Lineup, roster: Roster, reference: Lineup? = nil) -> Metrics`. `Metrics`: `seated`, `totalPower`, `weightLeft/Right`, `powerLeft/Right`, `sideMismatches`, `seatMismatches`, `trimMoment`, `women`, `men`; computed `weightDelta`, `powerDelta`, `totalWeight`, `sidePreferenceFraction`, `trimDeltaKg(boat:)`, `warnings(boat:thresholds:) -> Set<Metrics.Warning>`.
- `Greedy.autoFill(_ req: PlacementRequest) -> PlacementResult` (`.lineup`, `.metrics`, `.ruleSatisfied`, `.unseated`).
- `Suggestions.swaps(in: Lineup, roster: Roster, reference: Lineup? = nil, limit: Int = 3) -> [SwapSuggestion]`. `SwapSuggestion` — inspect its fields (Task 3 reads them; e.g. the two seats/paddlers + delta); apply by `lineup.swap(a, b)`.
- `Roster`: `byID: [PaddlerID: Paddler]`. `Paddler`: `id, name, weightKg, ergM, side (SidePreference), gender (Gender), seatPref (SeatPreference), role (BoatRole)`.
- `DomainMapping.boatSide(BoatSide) -> Side` and `.boat(size:)`. Reverse (Side → BoatSide) for saving: `left↔left`, `right↔right`.

## File Structure

New (under `apple/`):
- `Sources/Features/Lineup/LineupViewModel.swift` — `@MainActor @Observable`; load / tap-resolution / undo / reserves / save (Tasks 2) + balance / auto-fill / suggest (Task 3).
- `Sources/Features/Lineup/HullGrid.swift` — the hull (drummer, bench rows, sweep) via `SeatTile`, with tap targets + section bands.
- `Sources/Features/Lineup/LineupEditorView.swift` — assembles hull + Balance HUD + reserves tray + heat switcher + toolbar; replaces `LineupEditorPlaceholder`.
- Tests: `Tests/PaddltirAppTests/LineupRepositoryHeatTests.swift`, `LineupViewModelTests.swift`, `LineupBalanceTests.swift`.

Modified:
- `Sources/Data/Repositories/LineupRepository.swift` — add `saveHeat(heatId:name:drummerId:sweepId:)`, `createHeat(raceId:name:)`.
- `Sources/Features/Schedule/RaceDayDetailView.swift` — replace `LineupEditorPlaceholder(race:)` usage so a race pushes the real `LineupEditorView` (it needs a heat: see Task 5/6 note — the placeholder currently takes a `Race`; the editor takes a `heatId`, so the race→heat resolution happens where the nav is wired).

---

## Task 1: `LineupRepository` — `saveHeat` + `createHeat`

**Files:** Modify `apple/Sources/Data/Repositories/LineupRepository.swift`; Test `apple/Tests/PaddltirAppTests/LineupRepositoryHeatTests.swift`.

**Interfaces:**
- `func saveHeat(heatId: String, name: String, drummerId: String?, sweepId: String?) async throws` — updates the heat's name/drummer/sweep (loads the row, mutates, upserts) + outbox.
- `func createHeat(raceId: String, name: String) async throws -> Heat` — inserts a heat (sortOrder = current count) + outbox.

- [ ] **Step 1: Write the failing test**

```swift
// apple/Tests/PaddltirAppTests/LineupRepositoryHeatTests.swift
import Foundation
import GRDB
import Testing
@testable import Paddltir

@Suite struct LineupRepositoryHeatTests {
    private let t0 = Date(timeIntervalSince1970: 1_700_000_000)

    @Test func createHeatWritesRowAndOutbox() async throws {
        let appDB = try AppDatabase.inMemory()
        let repo = LineupRepository(db: appDB)
        let h1 = try await repo.createHeat(raceId: "r-1", name: "Heat 1")
        let h2 = try await repo.createHeat(raceId: "r-1", name: "Heat 2")
        #expect(h1.sortOrder == 0)
        #expect(h2.sortOrder == 1)
        let stored = try appDB.read { db in try Heat.fetchOne(db, key: h1.id) }
        #expect(stored?.name == "Heat 1")
        let entries = try appDB.read { db in try OutboxEntry.filter(Column("table_name") == "heats").fetchAll(db) }
        #expect(entries.count == 2)
        #expect(entries.allSatisfy { $0.op == "insert" })
    }

    @Test func saveHeatUpdatesDrummerSweepAndEnqueues() async throws {
        let appDB = try AppDatabase.inMemory()
        try appDB.write { db in
            try Heat(id: "h-1", raceId: "r-1", name: "Heat 1", sortOrder: 0, drummerId: nil, sweepId: nil, createdAt: t0, updatedAt: nil).insert(db)
        }
        let repo = LineupRepository(db: appDB)
        try await repo.saveHeat(heatId: "h-1", name: "Final", drummerId: "p-drum", sweepId: "p-sweep")
        let stored = try appDB.read { db in try Heat.fetchOne(db, key: "h-1") }
        #expect(stored?.name == "Final")
        #expect(stored?.drummerId == "p-drum")
        #expect(stored?.sweepId == "p-sweep")
        let entries = try appDB.read { db in try OutboxEntry.filter(Column("table_name") == "heats").fetchAll(db) }
        #expect(entries.count == 1)
        #expect(entries.first?.op == "update")
        #expect(entries.first?.pk == "h-1")
    }
}
```

- [ ] **Step 2: Run test to verify it fails** — `cd apple && xcodegen generate && xcodebuild ... test 2>&1 | grep -iE "LineupRepositoryHeat|createHeat|error:"`. Expected: FAIL — `has no member 'createHeat'`.

- [ ] **Step 3: Write the implementation** (append to `LineupRepository`)

```swift
    /// Adds a heat to a race; `sort_order` is the next free slot.
    func createHeat(raceId: String, name: String) async throws -> Heat {
        try db.write { db in
            let order = try Heat.filter(Column("race_id") == raceId).fetchCount(db)
            let row = Heat(id: UUID().uuidString, raceId: raceId, name: name, sortOrder: order,
                           drummerId: nil, sweepId: nil, createdAt: Date(), updatedAt: nil)
            try row.insert(db)
            try Outbox.enqueue(db: db, table: Heat.databaseTableName, pk: row.syncPrimaryKey,
                               op: "insert", payload: try PostgREST.encoder.encode(row))
            return row
        }
    }

    /// Updates a heat's name + drummer/sweep (the lineup editor's non-seat state).
    func saveHeat(heatId: String, name: String, drummerId: String?, sweepId: String?) async throws {
        try db.write { db in
            guard var row = try Heat.fetchOne(db, key: heatId) else { return }
            row.name = name; row.drummerId = drummerId; row.sweepId = sweepId; row.updatedAt = Date()
            try row.update(db)
            try Outbox.enqueue(db: db, table: Heat.databaseTableName, pk: row.syncPrimaryKey,
                               op: "update", payload: try PostgREST.encoder.encode(row))
        }
    }
```

- [ ] **Step 4: Run tests to verify they pass** — grep `LineupRepositoryHeatTests|TEST SUCCEEDED`. Expected: 2 tests PASS.
- [ ] **Step 5: Commit** — `git commit -m "feat(app): LineupRepository saveHeat/createHeat (drummer/sweep persistence)"`

---

## Task 2: `LineupViewModel` — load, tap-resolution, unseat, undo, reserves, save

**Files:** Create `apple/Sources/Features/Lineup/LineupViewModel.swift`; Test `apple/Tests/PaddltirAppTests/LineupViewModelTests.swift`.

**Interfaces:**
- `@MainActor @Observable final class LineupViewModel` with:
  - `init(db: AppDatabase)`
  - `enum Selection: Equatable { case reserve(PaddlerID); case seat(Seat) }`
  - `private(set) var lineup: Lineup?`, `private(set) var request: PlacementRequest?`, `var selection: Selection?`, `private(set) var heat: Heat?`, `private(set) var canUndo: Bool`
  - `func load(heatId: String) async`
  - `func tapSeat(_ seat: Seat)`, `func tapReserve(_ id: PaddlerID)`, `func unseat(_ seat: Seat)`, `func undo()`
  - `var reserves: [PaddlerID]` (candidates − seated − drummer − sweep, strongest erg first)
  - `func save() async`

- [ ] **Step 1: Write the failing test**

```swift
// apple/Tests/PaddltirAppTests/LineupViewModelTests.swift
import Foundation
import GRDB
import PaddltirCore
import Testing
@testable import Paddltir

@MainActor @Suite struct LineupViewModelTests {
    // Builds an in-memory VM around a hand-made lineup context (no GRDB needed for the
    // pure tap/undo/reserve logic — we inject the request directly via a test hook).
    private func vm(seatsFilled: Bool = false) -> LineupViewModel {
        let db = try! AppDatabase.inMemory()
        let m = LineupViewModel(db: db)
        // roster of 4 paddlers p1..p4, small boat (5 benches → 10 seats)
        let paddlers = (1...4).map { i in
            Paddler(id: PaddlerID("p\(i)"), name: "P\(i)", weightKg: 70, ergM: Double(600 + i),
                    side: .either, gender: i % 2 == 0 ? .male : .female, seatPref: .none, role: .paddler)
        }
        let roster = Roster(paddlers: paddlers)
        let req = PlacementRequest(boat: .small, roster: roster, candidates: paddlers.map(\.id),
                                   current: Lineup(boat: .small))
        m._injectForTest(request: req, heat: Heat(id: "h", raceId: "r", name: "Heat 1", sortOrder: 0, drummerId: nil, sweepId: nil, createdAt: Date(), updatedAt: nil))
        return m
    }

    @Test func tapReserveThenSeatPlaces() {
        let m = vm()
        m.tapReserve(PaddlerID("p1"))
        #expect(m.selection == .reserve(PaddlerID("p1")))
        m.tapSeat(Seat(bench: 1, side: .left))
        #expect(m.lineup?.paddler(at: Seat(bench: 1, side: .left)) == PaddlerID("p1"))
        #expect(m.selection == nil)
        #expect(m.reserves.contains(PaddlerID("p1")) == false)   // now seated
    }

    @Test func tapTwoSeatsSwaps() {
        let m = vm()
        m.tapReserve(PaddlerID("p1")); m.tapSeat(Seat(bench: 1, side: .left))
        m.tapReserve(PaddlerID("p2")); m.tapSeat(Seat(bench: 1, side: .right))
        m.tapSeat(Seat(bench: 1, side: .left)); m.tapSeat(Seat(bench: 1, side: .right)) // swap
        #expect(m.lineup?.paddler(at: Seat(bench: 1, side: .left)) == PaddlerID("p2"))
        #expect(m.lineup?.paddler(at: Seat(bench: 1, side: .right)) == PaddlerID("p1"))
    }

    @Test func unseatAndUndo() {
        let m = vm()
        m.tapReserve(PaddlerID("p1")); m.tapSeat(Seat(bench: 1, side: .left))
        #expect(m.canUndo)
        m.unseat(Seat(bench: 1, side: .left))
        #expect(m.lineup?.paddler(at: Seat(bench: 1, side: .left)) == nil)
        m.undo() // undo the unseat
        #expect(m.lineup?.paddler(at: Seat(bench: 1, side: .left)) == PaddlerID("p1"))
    }

    @Test func reservesSortedByErgDescending() {
        let m = vm()
        #expect(m.reserves == [PaddlerID("p4"), PaddlerID("p3"), PaddlerID("p2"), PaddlerID("p1")]) // erg 604>603>602>601
    }
}
```

- [ ] **Step 2: Run test to verify it fails** — grep `LineupViewModel|error:`. Expected: FAIL — `cannot find 'LineupViewModel'`.

- [ ] **Step 3: Write the implementation**

```swift
// apple/Sources/Features/Lineup/LineupViewModel.swift
// Orchestrates the lineup editor over PaddltirCore. Holds the live `Lineup`
// value, a tap `selection`, and an undo stack; every seat mutation goes
// through Lineup.place/.swap/.remove (which keep assignments canonical). No
// lineup logic lives here — balance/auto-fill/suggest are added in the next
// task and all delegate to PaddltirCore.
import Foundation
import GRDB
import PaddltirCore

@MainActor @Observable
final class LineupViewModel {
    enum Selection: Equatable { case reserve(PaddlerID); case seat(Seat) }

    private(set) var request: PlacementRequest?
    private(set) var lineup: Lineup?
    private(set) var heat: Heat?
    var selection: Selection?
    private(set) var canUndo = false
    private(set) var isSaving = false

    private let db: AppDatabase
    private let repo: LineupRepository
    private var undoStack: [Lineup] = []
    private var original: Lineup?   // reference for the `moves` metric

    init(db: AppDatabase) { self.db = db; self.repo = LineupRepository(db: db) }

    var roster: Roster? { request?.roster }
    var boat: Boat? { request?.boat }

    func load(heatId: String) async {
        guard let req = try? await repo.placementRequest(heatId: heatId) else { return }
        let (h, _, _) = (try? await repo.heat(id: heatId)) ?? (nil, [], [])
        request = req
        heat = h
        lineup = req.current ?? Lineup(boat: req.boat, drummerId: req.drummerId, sweepId: req.sweepId)
        original = lineup
        undoStack = []; canUndo = false; selection = nil
    }

    /// Candidates not seated / drummer / sweep, strongest erg first.
    var reserves: [PaddlerID] {
        guard let request, let lineup, let roster else { return [] }
        var used = lineup.seatedIDs
        if let d = lineup.drummerId { used.insert(d) }
        if let s = lineup.sweepId { used.insert(s) }
        return request.candidates.filter { !used.contains($0) }
            .sorted { (roster.byID[$0]?.ergM ?? 0) > (roster.byID[$1]?.ergM ?? 0) }
    }

    func tapSeat(_ seat: Seat) {
        guard lineup != nil else { return }
        switch selection {
        case .reserve(let id):
            mutate { $0.place(id, at: seat) }; selection = nil
        case .seat(let s):
            if s == seat { selection = nil } else { mutate { $0.swap(s, seat) }; selection = nil }
        case nil:
            selection = .seat(seat)   // pick a source (occupied or empty) to swap/fill
        }
    }

    func tapReserve(_ id: PaddlerID) {
        guard lineup != nil else { return }
        if case .seat(let s) = selection { mutate { $0.place(id, at: s) }; selection = nil }
        else { selection = (selection == .reserve(id)) ? nil : .reserve(id) }
    }

    func unseat(_ seat: Seat) { mutate { $0.remove(at: seat) }; selection = nil }

    func undo() {
        guard let prev = undoStack.popLast() else { return }
        lineup = prev; canUndo = !undoStack.isEmpty; selection = nil
    }

    /// Applies a mutation to `lineup`, snapshotting the prior value for undo.
    func mutate(_ change: (inout Lineup) -> Void) {
        guard var l = lineup else { return }
        undoStack.append(l); canUndo = true
        change(&l); lineup = l
    }

    func save() async {
        guard let lineup, let heat else { return }
        isSaving = true; defer { isSaving = false }
        let seats = lineup.assignments.map { a in
            SeatRow(heatId: heat.id, bench: a.bench, side: a.side == .left ? .left : .right,
                    paddlerId: a.paddlerId.rawValue, locked: a.locked, updatedAt: Date())
        }
        try? await repo.saveSeats(heatId: heat.id, seats: seats)
        try? await repo.saveHeat(heatId: heat.id, name: heat.name,
                                 drummerId: lineup.drummerId?.rawValue, sweepId: lineup.sweepId?.rawValue)
    }

    #if DEBUG
    /// Test hook: inject a request + heat without a live DB round-trip.
    func _injectForTest(request: PlacementRequest, heat: Heat) {
        self.request = request; self.heat = heat
        self.lineup = request.current ?? Lineup(boat: request.boat)
        self.original = self.lineup
    }
    #endif
}
```

- [ ] **Step 4: Run tests to verify they pass** — grep `LineupViewModelTests|TEST SUCCEEDED`. Expected: 4 tests PASS.
- [ ] **Step 5: Commit** — `git commit -m "feat(app): LineupViewModel — tap-to-place/swap, unseat, undo, reserves, save"`

---

## Task 3: `LineupViewModel` — balance, Auto-fill, Suggest

**Files:** Modify `apple/Sources/Features/Lineup/LineupViewModel.swift`; Test `apple/Tests/PaddltirAppTests/LineupBalanceTests.swift`.

**Interfaces (added):**
- `var metrics: Metrics?` (computed via `Scoring.evaluate(lineup, roster:, reference: original)`)
- `var beamImbalance: Double` (weight list, −1…1, right-heavy positive)
- `func autoFill()` (Greedy over the current context; snapshots undo)
- `func suggestions() -> [SwapSuggestion]`; `func apply(_ suggestion: SwapSuggestion)`

- [ ] **Step 1: Write the failing test**

```swift
// apple/Tests/PaddltirAppTests/LineupBalanceTests.swift
import Foundation
import GRDB
import PaddltirCore
import Testing
@testable import Paddltir

@MainActor @Suite struct LineupBalanceTests {
    private func vm() -> LineupViewModel {
        let db = try! AppDatabase.inMemory()
        let m = LineupViewModel(db: db)
        let paddlers = (1...10).map { i in
            Paddler(id: PaddlerID("p\(i)"), name: "P\(i)", weightKg: Double(60 + i), ergM: Double(600 + i),
                    side: .either, gender: i % 2 == 0 ? .male : .female, seatPref: .none, role: .paddler)
        }
        let roster = Roster(paddlers: paddlers)
        let req = PlacementRequest(boat: .small, roster: roster, candidates: paddlers.map(\.id), current: Lineup(boat: .small))
        m._injectForTest(request: req, heat: Heat(id: "h", raceId: "r", name: "Heat 1", sortOrder: 0, drummerId: nil, sweepId: nil, createdAt: Date(), updatedAt: nil))
        return m
    }

    @Test func metricsReflectSeatedCount() {
        let m = vm()
        #expect(m.metrics?.seated == 0)
        m.tapReserve(PaddlerID("p1")); m.tapSeat(Seat(bench: 1, side: .left))
        #expect(m.metrics?.seated == 1)
    }

    @Test func autoFillSeatsTheBoat() {
        let m = vm()
        m.autoFill()
        // small boat = 10 seats, 10 candidates → full
        #expect(m.metrics?.seated == 10)
        #expect(m.canUndo)   // auto-fill is undoable
    }
}
```

- [ ] **Step 2: Run test to verify it fails** — grep `LineupBalance|autoFill|error:`. Expected: FAIL — `has no member 'autoFill'` / `metrics`.

- [ ] **Step 3: Write the implementation** (append to `LineupViewModel`)

```swift
    var metrics: Metrics? {
        guard let lineup, let roster else { return nil }
        return Scoring.evaluate(lineup, roster: roster, reference: original)
    }

    /// Weight list for the balance beam: right-heavy positive, clamped to ±1.
    var beamImbalance: Double {
        guard let m = metrics else { return 0 }
        let half = max(1, m.totalWeight / 2)
        return max(-1, min(1, (m.weightRight - m.weightLeft) / half))
    }

    func autoFill() {
        guard let request, let lineup else { return }
        let req = PlacementRequest(boat: request.boat, roster: request.roster, candidates: request.candidates,
                                   drummerId: lineup.drummerId, sweepId: lineup.sweepId,
                                   locked: lineup.assignments.filter(\.locked), rule: request.rule, current: lineup)
        let result = Greedy.autoFill(req)
        mutate { $0 = result.lineup }
    }

    func suggestions() -> [SwapSuggestion] {
        guard let lineup, let roster else { return [] }
        return Suggestions.swaps(in: lineup, roster: roster, reference: original, limit: 3)
    }

    func apply(_ suggestion: SwapSuggestion) {
        // A SwapSuggestion names two seats to exchange; inspect its real fields
        // (Task-3 implementer: read Suggestions.swift for the property names) and
        // call `lineup.swap(seatA, seatB)` via `mutate`.
        mutate { $0.swap(suggestion.a, suggestion.b) }
    }
```

Note: `SwapSuggestion`'s exact property names must be read from `packages/PaddltirCore/Sources/PaddltirCore/Placement/Suggestions.swift` — the `apply` body above assumes `.a`/`.b: Seat`; if they differ (e.g. `seatA`/`seatB`, or paddler-based), adapt to the real fields and keep the "exchange the two seats" semantics. Verify against the file before writing.

- [ ] **Step 4: Run tests to verify they pass** — grep `LineupBalanceTests|TEST SUCCEEDED`. Expected: 2 tests PASS.
- [ ] **Step 5: Commit** — `git commit -m "feat(app): LineupViewModel — live balance metrics, Auto-fill, Suggest"`

---

## Task 4: `HullGrid` view

**Files:** Create `apple/Sources/Features/Lineup/HullGrid.swift`.

**Interfaces:** `struct HullGrid: View` with `init(lineup: Lineup, roster: Roster, selection: LineupViewModel.Selection?, onTapSeat: @escaping (Seat) -> Void)`.

- [ ] **Step 1: Write the view** (drummer, bench rows `L | # · section | R`, sweep; `SeatTile` for occupants, empty tappable slots; selected seat highlighted)

```swift
// apple/Sources/Features/Lineup/HullGrid.swift
// The boat hull — a solid, legible grid: Drummer at the bow, `n` bench rows
// (Left seat | bench# · section | Right seat), Sweep at the stern. Occupied
// seats render with the 4a SeatTile (gender-coloured); empty seats are tappable
// slots. The currently-selected seat gets an accent ring.
import SwiftUI
import PaddltirCore

struct HullGrid: View {
    let lineup: Lineup
    let roster: Roster
    let selection: LineupViewModel.Selection?
    let onTapSeat: (Seat) -> Void

    var body: some View {
        VStack(spacing: DS.Space.xs) {
            capRow("Drummer", id: lineup.drummerId)
            ForEach(lineup.boat.benchRange, id: \.self) { bench in
                HStack(spacing: DS.Space.xs) {
                    seatCell(Seat(bench: bench, side: .left))
                    VStack(spacing: 0) {
                        Text("\(bench)").font(.dsCaption.weight(.bold)).foregroundStyle(DS.ink3).monospacedDigit()
                        Text(section(bench)).font(.dsMicro).foregroundStyle(DS.ink3)
                    }
                    .frame(width: 56)
                    seatCell(Seat(bench: bench, side: .right))
                }
            }
            capRow("Sweep", id: lineup.sweepId)
        }
        .padding(DS.Space.m)
        .background(DS.surface, in: .rect(cornerRadius: DS.R.card))
        .overlay(RoundedRectangle(cornerRadius: DS.R.card).stroke(DS.border))
    }

    private func section(_ bench: Int) -> String {
        switch lineup.boat.section(ofBench: bench) {
        case .stroke: "STROKE"; case .pace: "PACE"; case .engine: "ENGINE"; case .sprint: "SPRINT"
        }
    }

    @ViewBuilder private func seatCell(_ seat: Seat) -> some View {
        let selected = selection == .seat(seat)
        Button { onTapSeat(seat) } label: {
            Group {
                if let pid = lineup.paddler(at: seat), let p = roster.byID[pid] {
                    SeatTile(name: p.name, side: seat.side == .left ? "L" : "R", weightKg: p.weightKg,
                             gender: p.gender, violatesPref: !p.side.matches(seat.side))
                } else {
                    Text(seat.side == .left ? "L" : "R")
                        .font(.dsCaption).foregroundStyle(DS.ink3)
                        .frame(maxWidth: .infinity, minHeight: 40)
                        .background(DS.surface2, in: .rect(cornerRadius: DS.R.tile))
                        .overlay(RoundedRectangle(cornerRadius: DS.R.tile).stroke(DS.border, style: .init(dash: [3])))
                }
            }
            .overlay(RoundedRectangle(cornerRadius: DS.R.tile).stroke(DS.accent, lineWidth: selected ? 2 : 0))
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity)
    }

    private func capRow(_ label: String, id: PaddlerID?) -> some View {
        HStack {
            MicroLabel(label)
            Spacer()
            Text(id.flatMap { roster.byID[$0]?.name } ?? "—").font(.dsCaption).foregroundStyle(DS.ink2)
        }
        .padding(.horizontal, DS.Space.s).padding(.vertical, DS.Space.xs)
        .frame(maxWidth: .infinity)
        .background(DS.surface2, in: .rect(cornerRadius: DS.R.sm))
    }
}
```

- [ ] **Step 2: Build + verify** — iOS gate + macOS build green (`SeatTile`/`Seat`/`Section` resolve; count unchanged).
- [ ] **Step 3: Commit** — `git commit -m "feat(app): HullGrid — bench rows, seat tiles, section bands, tap"`

---

## Task 5: `LineupEditorView` — assemble + wire in

**Files:** Create `apple/Sources/Features/Lineup/LineupEditorView.swift`; Modify `apple/Sources/Features/Schedule/RaceDayDetailView.swift`.

**Interfaces:** `struct LineupEditorView: View` with `init(heatId: String, raceName: String)`; assembles `HeatSwitcher` (glass) + `HullGrid` + a glass Balance HUD (`GlassBar { BalanceBeam + TelemetryGrid + gender badge }`) + reserves chips + a glass toolbar (Suggest / Auto-fill / Undo). Save on change (or a Save/Done action).

- [ ] **Step 1: Write `LineupEditorView`**

```swift
// apple/Sources/Features/Lineup/LineupEditorView.swift
// The hero screen. Glass heat-switcher header, the solid HullGrid, a glass
// Balance HUD (beam + telemetry + gender badge) driven by PaddltirCore on every
// change, a reserves strip, and a glass toolbar (Suggest / Auto-fill / Undo).
// Optimise (server MIP) is out of scope until the solver is deployed (go-live).
import SwiftUI
import PaddltirCore

struct LineupEditorView: View {
    let heatId: String
    let raceName: String
    @Environment(AppModel.self) private var app
    @State private var model: LineupViewModel?
    @State private var heatSelection = 0

    var body: some View {
        Group {
            if let model, let lineup = model.lineup, let roster = model.roster, let boat = model.boat {
                content(model, lineup: lineup, roster: roster, boat: boat)
            } else { ProgressView() }
        }
        .navigationTitle(raceName)
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .background(DS.bg)
        .task {
            if model == nil { model = LineupViewModel(db: app.environment.db) }
            await model?.load(heatId: heatId)
        }
    }

    @ViewBuilder private func content(_ model: LineupViewModel, lineup: Lineup, roster: Roster, boat: Boat) -> some View {
        ScrollView {
            VStack(spacing: DS.Space.m) {
                HeatSwitcher(names: [model.heat?.name ?? "Heat"], selection: $heatSelection)   // single heat for now; multi-heat nav is a later pass

                HullGrid(lineup: lineup, roster: roster, selection: model.selection) { seat in
                    model.tapSeat(seat); Task { await model.save() }
                }

                if let metrics = model.metrics {
                    GlassBar {
                        VStack(alignment: .leading, spacing: DS.Space.s) {
                            BalanceBeam(imbalance: model.beamImbalance, label: "Trim").frame(height: 20)
                            TelemetryGrid(metrics: metrics, boat: boat)
                            HStack {
                                MicroLabel("GENDER")
                                Spacer()
                                Text("W \(metrics.women) · M \(metrics.men)").font(.dsCaption.weight(.bold)).foregroundStyle(DS.ink)
                            }
                        }
                        .padding(DS.Space.m)
                    }
                }

                reserves(model, roster: roster)
                toolbar(model)
            }
            .padding(DS.Space.l)
        }
    }

    @ViewBuilder private func reserves(_ model: LineupViewModel, roster: Roster) -> some View {
        if !model.reserves.isEmpty {
            VStack(alignment: .leading, spacing: DS.Space.s) {
                MicroLabel("RESERVES")
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 96))], spacing: DS.Space.s) {
                    ForEach(model.reserves, id: \.self) { id in
                        let p = roster.byID[id]
                        Button { model.tapReserve(id) } label: {
                            Text(p?.name ?? id.rawValue)
                                .font(.dsCaption).foregroundStyle(DS.ink)
                                .padding(.horizontal, DS.Space.s).padding(.vertical, DS.Space.xs)
                                .background(model.selection == .reserve(id) ? DS.accent.opacity(0.18) : DS.surface2, in: Capsule())
                                .overlay(Capsule().stroke(model.selection == .reserve(id) ? DS.accent : DS.border))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private func toolbar(_ model: LineupViewModel) -> some View {
        GlassBar {
            HStack(spacing: DS.Space.l) {
                toolButton("Suggest", "wand.and.stars") { /* Suggest sheet — Task-5: present model.suggestions(); apply on tap */ }
                toolButton("Auto-fill", "sparkles") { model.autoFill(); Task { await model.save() } }
                toolButton("Undo", "arrow.uturn.backward") { model.undo(); Task { await model.save() } }
                    .disabled(!model.canUndo)
            }
            .padding(DS.Space.m)
        }
    }

    private func toolButton(_ label: String, _ icon: String, _ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 2) { Image(systemName: icon); Text(label).font(.dsMicro) }
                .foregroundStyle(DS.accent)
        }
        .buttonStyle(.plain)
    }
}
```

Note: the Suggest action is stubbed to a comment — implement a minimal sheet listing `model.suggestions()` (show each swap's before→after by name; tap → `model.apply(suggestion)` + save), OR, to keep Task 5 tight, wire Suggest to apply the top suggestion directly and leave the ranked sheet for polish (state which you did in the report). Do not leave it inert.

- [ ] **Step 2: Wire the race → editor** in `RaceDayDetailView.swift`: the race-day detail lists races; each race needs a heat to edit. Simplest correct wiring: when a race is tapped, resolve-or-create its first heat and push `LineupEditorView(heatId:raceName:)`. Replace the `LineupEditorPlaceholder(race:)` destination — on navigation to a `Race`, load the race's heats (add a tiny `LineupRepository.heats(raceId:)` read if none exists, or reuse existing heat loading) and either open the first heat or `createHeat(raceId:name:"Heat 1")` then open it. Keep the change minimal and note in the report exactly how the race→heat resolution was done.

- [ ] **Step 3: Build + verify** — iOS + macOS green; `grep -rn LineupEditorPlaceholder apple/Sources` returns nothing (replaced).
- [ ] **Step 4: Commit** — `git commit -m "feat(app): LineupEditorView — hull + Balance HUD + reserves + toolbar; wired from race day"`

---

## Task 6: Integration & verification

**Files:** none new — verification + docs.

- [ ] **Step 1: Full build gate (iOS + macOS), whole suite green** — regenerate; run the iOS test gate (all new tests: heat writes, VM interaction, VM balance/auto-fill) + macOS build. Expect gated live tests skipped, ZERO Swift warnings.
- [ ] **Step 2: Gated live tests once** (controller): the existing `ClubServiceLiveTests` + `SupabaseRemoteTests` still pass against the local stack.
- [ ] **Step 3: Screenshot** (controller, via `PADDLTIR_DEBUG_AUTOSIGNIN=1` + navigating to a race's heat): capture the lineup editor against the seed (the seed has a crew + heats). If reaching the editor needs taps `simctl` can't do, capture what's reachable and note the rest. Save `apple/screenshots/4f-lineup.png`; surface to Jun.
- [ ] **Step 4: Update PROGRESS.md + roadmap** (post-merge, on main): mark 4f merged; record deferrals (drag/haptics, Optimise server MIP → go-live/Plan 6, Share snapshot, multi-heat switcher nav, "unavailable today" reserve dimming).
- [ ] **Step 5: Commit** verification artifacts.

---

## Self-Review

**Spec coverage (§3 Lineup editor):**
- Hull grid (drummer, bench rows L|#·section|R, sweep; section bands) → Task 4. ✓
- Seat card (name, weight, side/section tags; amber when violated) → 4a `SeatTile` via Task 4 (`violatesPref` = side-pref mismatch). ✓
- Live Balance HUD (Weight Δ, Power Δ, Trim, Prefs, gender badge; green/amber/red) → Task 5 (`TelemetryGrid` + `BalanceBeam` + gender line, driven by `Scoring.evaluate`). ✓
- Reserves tray (unseated crew as chips) → Task 5. ✓ ("unavailable today" dimming **deferred**.)
- Interaction: tap-tap swap for one-handed use → Tasks 2/4. ✓ **Drag + haptics + swap animation deferred** (documented).
- Long-press menu (lock/reserve/drummer/sweep) → **partially deferred**: unseat + place/swap ship; lock/set-drummer/sweep via menu is a follow-up (the VM/`Lineup` already support `setLocked`/drummer/sweep — UI menu deferred). Flag it.
- Toolbar: Suggest, Auto-fill → Task 5. **Optimise deferred** (solver not deployed until go-live). **Share deferred.**
- Undo/redo → Task 2 (undo ships; redo deferred). Heat switcher → Task 5 (single-heat shown; multi-heat switch/create nav deferred to a follow-up — `createHeat` exists).

**Placeholder scan:** no "TBD"/"handle errors". The Suggest action + the race→heat wiring are the two spots that say "implement minimally, state what you did" — those are real implementation choices for the implementer, not skipped code; each has a concrete fallback. The `SwapSuggestion` field-name note is a required lookup (read Suggestions.swift), like the Pill lesson.

**Type consistency:** `LineupViewModel.Selection`/`lineup`/`reserves`/`metrics`/`autoFill`/`suggestions` used consistently (Tasks 2–5). `Lineup`/`Seat`/`Boat`/`Metrics`/`Roster`/`Paddler` from PaddltirCore used per the verified Data-facts signatures. `SeatRow`/`Heat` fields match Task 1. DS component signatures (`SeatTile`/`TelemetryGrid`/`BalanceBeam`/`HeatSwitcher`) copied verbatim from the shipped components.

**Known deferrals (flag at merge):** drag-and-drop + haptics + animations; **Optimise server MIP (go-live/Plan 6)**; Share snapshot; multi-heat switcher nav (create/rename/duplicate/delete — `createHeat` exists); redo; long-press lock/drummer/sweep menu; "unavailable today" reserve dimming; the standing 4c/4e polish + the sync-completion refresh (4g).

## Execution Handoff

**Plan complete and saved to `docs/superpowers/plans/2026-08-25-plan-4f-lineup-editor.md`.** Executing via subagent-driven-development: fresh implementer per task, task review after each, final whole-branch review before merge. The engine (Tasks 1–3) is TDD; the views (Tasks 4–5) are screenshot-verified against ready-made 4a components; Task 6 verifies.

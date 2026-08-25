# Plan 4e — Crews & Squad Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build the **Squad** tab (searchable, sortable, filterable paddler roster; paddler detail with edit/erg-sparkline/invite-status/archive; add paddler) and the **Crews** tab (crew cards; crew detail with members, the IDBF gender-rule check, add/remove-from-squad, and races history; create crew) — offline-first over GRDB.

**Architecture:** Add read/write methods to the existing `SquadRepository` (erg history) and `CrewRepository` (create crew, races-for-crew, crew summaries). Pure, unit-tested helpers do the squad filter/sort and the women/men tally; the gender-rule verdict reuses `PaddltirCore.GenderRule.violation` via `DomainMapping.genderRule`. `@MainActor @Observable` view-models compose repositories + helpers for the screens. SwiftUI feature views render through the 4a design system inside `NavigationStack`s, replacing `SquadPlaceholder`/`CrewsPlaceholder`. Detail/form views are built before their tab views so the tabs' navigation/sheets resolve.

**Tech Stack:** SwiftUI + Observation + Swift Charts (erg sparkline), GRDB (via the Plan 4b `AppDatabase`/repositories/`Outbox`), `PaddltirCore` (`GenderRule`), the 4a DesignSystem, the Plan 4c `AppModel` shell.

**Spec:** `docs/superpowers/specs/2026-08-22-paddltir-design.md` — §3 "Crews" and "Squad". Visual direction: `docs/design/direction.md`.

## Global Constraints

- **Rename:** any in-product "CrewCoach" → **Paddltir**.
- **Platforms:** one target, iOS 26 + macOS 26. Every view compiles and lays out on both; guard platform-only APIs with `#if os(...)`.
- **Design system — use the REAL token names** (these exist; do NOT invent `DS.Font.*`, `DS.Space.lg/md`, `DS.R.control`):
  - Spacing `DS.Space.xs`(4)/`.s`(8)/`.m`(12)/`.l`(16)/`.xl`(24); Radius `DS.R.card`(12)/`.ctl`(8)/`.sm`(6)/`.tile`(8).
  - Typography is a `Font` extension used as `.font(.dsX)`: `.dsLargeTitle`/`.dsTitle`/`.dsHeadline`/`.dsSubhead`/`.dsBody`/`.dsCallout`/`.dsCaption`/`.dsFootnote`/`.dsMicro` (NO `DS.Font` namespace; monospace via `.font(.system(.body, design: .monospaced))`).
  - Colors `DS.bg`/`.surface`/`.surface2`/`.ink`/`.ink2`/`.ink3`/`.border`/`.accent`/`.good`/`.danger`/`.maleFill`/`.maleBorder`/`.femaleFill`/`.femaleBorder`/`.primary`/`.onPrimary`.
  - Components `ScreenScaffold(_ title, note:, content:)`, `HairlineCard(padding:content:)`, `Pill(...)`, `MicroLabel(_)`, `PrimaryButton(_ , action:)`, `SecondaryButton(_ , action:)`, `AvailabilityRing(count:total:...)`. Never raw hex or `Font.system` (mono exception aside).
- **Light mode only.** Style through DS tokens/components — never raw hex/fonts in a view.
- **Writes = GRDB mutation + `Outbox.enqueue` in ONE `db.write { }` transaction**, mirroring `CrewRepository.setMembers`/the 4d writes: payload via `PostgREST.encoder`, `pk` via the row's `syncPrimaryKey`, `op` `"insert"`/`"update"`.
- **Repositories stay UI-free** (no SwiftUI import); **PaddltirCore stays UI-free** (filter/sort/tally are app-layer helpers; the gender-rule *verdict* reuses `PaddltirCore.GenderRule`).
- **Build gate:** `cd apple && xcodegen generate && xcodebuild -scheme Paddltir -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -derivedDataPath DerivedData test` — regenerate first. Also `xcodebuild -scheme Paddltir -destination 'platform=macOS' build`.
- **Secrets:** `Sources/App/Secrets.swift` git-ignored; never commit keys.
- **Data facts:** `PaddlerRow` fields: `id, clubId, profileId?, name, email?, weightKg (Double), preferredSide (SidePref: left/right/either), gender (RowGender: female/male), seatPreference (SeatPref: stroke/pace/engine/sprint/none), boatRole (RowBoatRole: paddler/drummer/sweep), archivedAt?, createdAt, updatedAt?`. **Linked** = `profileId != nil`; **invitable** = `email != nil`. `SquadRepository.paddlers()` already excludes archived; `paddler(id:)` returns archived-or-not. `Crew`: `id, clubId, name, ageDivision (String: 16U/18U/24U/Premier/Senior A–C), category (CrewCategory: open/women/mixed), createdAt, updatedAt?`. `PaddlerWithErg` is already `Identifiable` (id = row.id, added in 4d). The gender rule for a crew's category comes from `CategoryRule` via `DomainMapping.genderRule(_:) -> GenderRule?`; the crew-detail check uses the **standard-boat** rule `(crew.clubId, crew.category, .standard)` (per-heat boat-size-specific checks live in the 4f lineup editor). `GenderRule.violation(women:men:) -> String?` returns nil when OK.

## File Structure

New (under `apple/`):
- `Sources/Features/Squad/SquadModels.swift` — pure `SquadFilter`/`SquadSort`/`SquadQuery` + `GenderTally`.
- `Sources/Features/Squad/SquadViewModel.swift`, `SquadView.swift`, `PaddlerDetailView.swift`, `PaddlerFormView.swift`.
- `Sources/Features/Crews/CrewsView.swift` (+ `CrewsViewModel`), `CrewDetailView.swift`, `CrewFormView.swift`.
- Tests: `Tests/PaddltirAppTests/ErgHistoryTests.swift`, `CrewRepositoryWriteTests.swift`, `SquadModelsTests.swift`, `SquadViewModelTests.swift`.

Modified:
- `Sources/Data/Repositories/SquadRepository.swift` — add `ergHistory(paddlerId:)`.
- `Sources/Data/Repositories/CrewRepository.swift` — add `createCrew`, `racesForCrew`, `summaries(now:)` + a `CrewSummary` type.
- `Sources/App/RootView.swift` — replace `SquadPlaceholder()`/`CrewsPlaceholder()` at both call sites (iOS tabs 2/1 + macOS `macDetail` `.squad`/`.crews`).
- Delete `Sources/Features/SquadPlaceholder.swift`, `Sources/Features/CrewsPlaceholder.swift`.

---

## Task 1: `SquadRepository.ergHistory`

**Files:** Modify `apple/Sources/Data/Repositories/SquadRepository.swift`; Test `apple/Tests/PaddltirAppTests/ErgHistoryTests.swift`.

**Interfaces:** Produces `func ergHistory(paddlerId: String) async throws -> [ErgTest]` (all of a paddler's erg tests, oldest-first by `testedAt`).

- [ ] **Step 1: Write the failing test**

```swift
// apple/Tests/PaddltirAppTests/ErgHistoryTests.swift
import Foundation
import GRDB
import Testing
@testable import Paddltir

@Suite struct ErgHistoryTests {
    private let t0 = Date(timeIntervalSince1970: 1_700_000_000)

    @Test func ergHistoryReturnsAllTestsOldestFirst() async throws {
        let appDB = try AppDatabase.inMemory()
        try appDB.write { db in
            try ErgTest(id: "e2", paddlerId: "p-1", testedAt: t0.addingTimeInterval(100), metres: 640, source: .coach, recordedBy: nil, createdAt: t0).insert(db)
            try ErgTest(id: "e1", paddlerId: "p-1", testedAt: t0, metres: 600, source: .coach, recordedBy: nil, createdAt: t0).insert(db)
            try ErgTest(id: "e3", paddlerId: "p-2", testedAt: t0, metres: 500, source: .coach, recordedBy: nil, createdAt: t0).insert(db)
        }
        let history = try await SquadRepository(db: appDB).ergHistory(paddlerId: "p-1")
        #expect(history.map(\.id) == ["e1", "e2"])   // oldest-first, only p-1
        #expect(history.map(\.metres) == [600, 640])
    }
}
```

- [ ] **Step 2: Run test to verify it fails** — `cd apple && xcodegen generate && xcodebuild ... test 2>&1 | grep -iE "ErgHistory|error:"`. Expected: FAIL — `has no member 'ergHistory'`.

- [ ] **Step 3: Write the implementation** (append to `SquadRepository`)

```swift
    /// Every erg test for a paddler, oldest-first — the erg-history sparkline.
    func ergHistory(paddlerId: String) async throws -> [ErgTest] {
        try db.read { db in
            try ErgTest
                .filter(Column("paddler_id") == paddlerId)
                .order(Column("tested_at"))
                .fetchAll(db)
        }
    }
```

- [ ] **Step 4: Run test to verify it passes** — grep `ErgHistoryTests|TEST SUCCEEDED`. Expected: PASS.
- [ ] **Step 5: Commit** — `git commit -m "feat(app): SquadRepository.ergHistory"`

---

## Task 2: `CrewRepository` — createCrew, racesForCrew, summaries

**Files:** Modify `apple/Sources/Data/Repositories/CrewRepository.swift`; Test `apple/Tests/PaddltirAppTests/CrewRepositoryWriteTests.swift`.

**Interfaces:**
- Produces:
  - `struct CrewSummary: Identifiable, Hashable, Sendable { let crew: Crew; let memberCount: Int; let nextRaceName: String?; var id: String { crew.id } }`
  - `func createCrew(clubId: String, name: String, ageDivision: String, category: CrewCategory) async throws -> Crew`
  - `func racesForCrew(crewId: String) async throws -> [Race]` (by sort_order)
  - `func summaries(now: Date) async throws -> [CrewSummary]` (all crews alphabetical; member count; the name of the crew's race in the soonest future session, else nil)

- [ ] **Step 1: Write the failing test**

```swift
// apple/Tests/PaddltirAppTests/CrewRepositoryWriteTests.swift
import Foundation
import GRDB
import Testing
@testable import Paddltir

@Suite struct CrewRepositoryWriteTests {
    private let t0 = Date(timeIntervalSince1970: 1_700_000_000)

    @Test func createCrewWritesRowAndOutbox() async throws {
        let appDB = try AppDatabase.inMemory()
        let repo = CrewRepository(db: appDB)
        let crew = try await repo.createCrew(clubId: "club-1", name: "A Crew", ageDivision: "Premier", category: .mixed)
        #expect(crew.name == "A Crew")
        #expect(crew.category == .mixed)
        let stored = try appDB.read { db in try Crew.fetchOne(db, key: crew.id) }
        #expect(stored?.ageDivision == "Premier")
        let entries = try appDB.read { db in try OutboxEntry.filter(Column("table_name") == "crews").fetchAll(db) }
        #expect(entries.count == 1)
        #expect(entries.first?.op == "insert")
    }

    @Test func summariesCountMembersAndFindNextRace() async throws {
        let appDB = try AppDatabase.inMemory()
        try appDB.write { db in
            try Crew(id: "c-1", clubId: "club-1", name: "Alpha", ageDivision: "Premier", category: .mixed, createdAt: t0, updatedAt: nil).insert(db)
            try CrewMember(crewId: "c-1", paddlerId: "p-1", createdAt: t0).insert(db)
            try CrewMember(crewId: "c-1", paddlerId: "p-2", createdAt: t0).insert(db)
            // a future session with a race for this crew
            try SessionRow(id: "s-1", clubId: "club-1", kind: .raceDay, title: "Regatta", startsAt: t0.addingTimeInterval(86_400), venue: nil, notes: nil, createdAt: t0, updatedAt: nil).insert(db)
            try Race(id: "r-1", sessionId: "s-1", crewId: "c-1", name: "Heat A", boatSize: .standard, distanceM: 500, sortOrder: 0, createdAt: t0, updatedAt: nil).insert(db)
        }
        let summaries = try await CrewRepository(db: appDB).summaries(now: t0)
        #expect(summaries.count == 1)
        #expect(summaries[0].memberCount == 2)
        #expect(summaries[0].nextRaceName == "Heat A")
    }
}
```

- [ ] **Step 2: Run test to verify it fails** — grep `CrewRepositoryWrite|createCrew|error:`. Expected: FAIL — `has no member 'createCrew'`.

- [ ] **Step 3: Write the implementation** (append to `CrewRepository`; add `import` nothing new)

```swift
    struct CrewSummary: Identifiable, Hashable, Sendable {
        let crew: Crew
        let memberCount: Int
        let nextRaceName: String?
        var id: String { crew.id }
    }

    /// Creates a crew for `clubId`.
    func createCrew(clubId: String, name: String, ageDivision: String, category: CrewCategory) async throws -> Crew {
        let row = Crew(id: UUID().uuidString, clubId: clubId, name: name, ageDivision: ageDivision,
                       category: category, createdAt: Date(), updatedAt: nil)
        try db.write { db in
            try row.insert(db)
            try Outbox.enqueue(db: db, table: Crew.databaseTableName, pk: row.syncPrimaryKey,
                               op: "insert", payload: try PostgREST.encoder.encode(row))
        }
        return row
    }

    /// A crew's races, in configured order.
    func racesForCrew(crewId: String) async throws -> [Race] {
        try db.read { db in
            try Race.filter(Column("crew_id") == crewId).order(Column("sort_order")).fetchAll(db)
        }
    }

    /// Every crew (alphabetical) with its member count and the name of its
    /// race in the soonest future session (or nil).
    func summaries(now: Date) async throws -> [CrewSummary] {
        try db.read { db in
            let crews = try Crew.order(Column("name")).fetchAll(db)
            return try crews.map { crew in
                let count = try CrewMember.filter(Column("crew_id") == crew.id).fetchCount(db)
                let races = try Race.filter(Column("crew_id") == crew.id).fetchAll(db)
                // soonest future session among this crew's races
                var best: (Date, String)?
                for race in races {
                    guard let s = try SessionRow.fetchOne(db, key: race.sessionId), s.startsAt >= now else { continue }
                    if best == nil || s.startsAt < best!.0 { best = (s.startsAt, race.name) }
                }
                return CrewSummary(crew: crew, memberCount: count, nextRaceName: best?.1)
            }
        }
    }
```

- [ ] **Step 4: Run test to verify it passes** — grep `CrewRepositoryWriteTests|TEST SUCCEEDED`. Expected: 2 tests PASS.
- [ ] **Step 5: Commit** — `git commit -m "feat(app): CrewRepository createCrew/racesForCrew/summaries"`

---

## Task 3: Pure squad logic — `SquadQuery` + `GenderTally`

**Files:** Create `apple/Sources/Features/Squad/SquadModels.swift`; Test `apple/Tests/PaddltirAppTests/SquadModelsTests.swift`.

**Interfaces:**
- `enum SquadSort: String, CaseIterable, Identifiable { case name, weight, erg; var id: String { rawValue } }`
- `struct SquadFilter: Equatable { var search = ""; var side: SidePref? = nil; var gender: RowGender? = nil; var role: RowBoatRole? = nil; var linkedOnly = false }`
- `enum SquadQuery { static func apply(_ paddlers: [PaddlerWithErg], filter: SquadFilter, sort: SquadSort) -> [PaddlerWithErg] }`
- `struct GenderTally: Equatable { let women: Int; let men: Int; static func of(_ members: [PaddlerWithErg]) -> GenderTally }`

- [ ] **Step 1: Write the failing test**

```swift
// apple/Tests/PaddltirAppTests/SquadModelsTests.swift
import Foundation
import Testing
@testable import Paddltir

@Suite struct SquadModelsTests {
    private func p(_ id: String, _ name: String, weight: Double, side: SidePref, gender: RowGender,
                  role: RowBoatRole = .paddler, linked: Bool = false, erg: Int? = nil) -> PaddlerWithErg {
        let row = PaddlerRow(id: id, clubId: "c", profileId: linked ? "u-\(id)" : nil, name: name, email: nil,
                             weightKg: weight, preferredSide: side, gender: gender, seatPreference: .engine,
                             boatRole: role, archivedAt: nil, createdAt: Date(), updatedAt: nil)
        let e = erg.map { ErgTest(id: "e-\(id)", paddlerId: id, testedAt: Date(), metres: $0, source: .coach, recordedBy: nil, createdAt: Date()) }
        return PaddlerWithErg(row: row, latestErg: e)
    }
    private lazy var squad: [PaddlerWithErg] = [
        p("1", "Alice", weight: 62, side: .left, gender: .female, linked: true, erg: 600),
        p("2", "Bob", weight: 80, side: .right, gender: .male, erg: 640),
        p("3", "Cara", weight: 58, side: .left, gender: .female, role: .drummer),
    ]

    @Test func searchMatchesNameCaseInsensitive() {
        let out = SquadQuery.apply(squad, filter: SquadFilter(search: "ali"), sort: .name)
        #expect(out.map(\.row.id) == ["1"])
    }
    @Test func filtersCombine() {
        var f = SquadFilter(); f.side = .left; f.gender = .female
        #expect(SquadQuery.apply(squad, filter: f, sort: .name).map(\.row.id) == ["1", "3"])
        var g = SquadFilter(); g.linkedOnly = true
        #expect(SquadQuery.apply(squad, filter: g, sort: .name).map(\.row.id) == ["1"])
        var r = SquadFilter(); r.role = .drummer
        #expect(SquadQuery.apply(squad, filter: r, sort: .name).map(\.row.id) == ["3"])
    }
    @Test func sortByWeightAscAndErgDescNilLast() {
        #expect(SquadQuery.apply(squad, filter: SquadFilter(), sort: .weight).map(\.row.id) == ["3", "1", "2"])
        // erg desc: 640, 600, then nil last
        #expect(SquadQuery.apply(squad, filter: SquadFilter(), sort: .erg).map(\.row.id) == ["2", "1", "3"])
    }
    @Test func genderTallyCounts() {
        #expect(GenderTally.of(squad) == GenderTally(women: 2, men: 1))
    }
}
```

- [ ] **Step 2: Run test to verify it fails** — grep `SquadModels|SquadQuery|error:`. Expected: FAIL — `cannot find 'SquadQuery'`.

- [ ] **Step 3: Write the implementation**

```swift
// apple/Sources/Features/Squad/SquadModels.swift
// Pure, UI-free squad filtering/sorting + a women/men tally. No SwiftUI, no
// GRDB — operates on already-loaded PaddlerWithErg values so it's trivially
// unit-testable.
import Foundation

enum SquadSort: String, CaseIterable, Identifiable {
    case name, weight, erg
    var id: String { rawValue }
    var label: String { rawValue.capitalized }
}

struct SquadFilter: Equatable {
    var search = ""
    var side: SidePref?
    var gender: RowGender?
    var role: RowBoatRole?
    var linkedOnly = false
}

enum SquadQuery {
    static func apply(_ paddlers: [PaddlerWithErg], filter f: SquadFilter, sort: SquadSort) -> [PaddlerWithErg] {
        let needle = f.search.trimmingCharacters(in: .whitespaces).lowercased()
        let filtered = paddlers.filter { pw in
            let r = pw.row
            if !needle.isEmpty, !r.name.lowercased().contains(needle) { return false }
            if let s = f.side, r.preferredSide != s { return false }
            if let g = f.gender, r.gender != g { return false }
            if let role = f.role, r.boatRole != role { return false }
            if f.linkedOnly, r.profileId == nil { return false }
            return true
        }
        switch sort {
        case .name:   return filtered.sorted { $0.row.name.localizedCaseInsensitiveCompare($1.row.name) == .orderedAscending }
        case .weight: return filtered.sorted { $0.row.weightKg < $1.row.weightKg }
        case .erg:    return filtered.sorted { ($0.latestErg?.metres ?? Int.min) > ($1.latestErg?.metres ?? Int.min) }
        }
    }
}

struct GenderTally: Equatable {
    let women: Int
    let men: Int
    static func of(_ members: [PaddlerWithErg]) -> GenderTally {
        GenderTally(women: members.filter { $0.row.gender == .female }.count,
                    men: members.filter { $0.row.gender == .male }.count)
    }
}
```

- [ ] **Step 4: Run test to verify it passes** — grep `SquadModelsTests|TEST SUCCEEDED`. Expected: 4 tests PASS.
- [ ] **Step 5: Commit** — `git commit -m "feat(app): pure SquadQuery filter/sort + GenderTally"`

---

## Task 4: `SquadViewModel`

**Files:** Create `apple/Sources/Features/Squad/SquadViewModel.swift`; Test `apple/Tests/PaddltirAppTests/SquadViewModelTests.swift`.

**Interfaces:** `@MainActor @Observable final class SquadViewModel` with `init(db: AppDatabase)`; `var filter: SquadFilter`; `var sort: SquadSort`; `private(set) var all: [PaddlerWithErg]`; `var visible: [PaddlerWithErg]` (derived via `SquadQuery`); `func load() async`.

- [ ] **Step 1: Write the failing test**

```swift
// apple/Tests/PaddltirAppTests/SquadViewModelTests.swift
import Foundation
import GRDB
import Testing
@testable import Paddltir

@MainActor @Suite struct SquadViewModelTests {
    private func seed(_ appDB: AppDatabase) throws {
        try appDB.write { db in
            for (id, name, g) in [("1","Alice",RowGender.female), ("2","Bob",.male)] {
                try PaddlerRow(id: id, clubId: "c", profileId: nil, name: name, email: nil, weightKg: 70,
                               preferredSide: .left, gender: g, seatPreference: .engine, boatRole: .paddler,
                               archivedAt: nil, createdAt: Date(), updatedAt: nil).insert(db)
            }
        }
    }
    @Test func loadThenFilterNarrowsVisible() async throws {
        let appDB = try AppDatabase.inMemory()
        try seed(appDB)
        let vm = SquadViewModel(db: appDB)
        await vm.load()
        #expect(vm.all.count == 2)
        #expect(vm.visible.count == 2)
        vm.filter.gender = .female
        #expect(vm.visible.map(\.row.id) == ["1"])
    }
}
```

- [ ] **Step 2: Run test to verify it fails** — grep `SquadViewModel|error:`. Expected: FAIL — `cannot find 'SquadViewModel'`.

- [ ] **Step 3: Write the implementation**

```swift
// apple/Sources/Features/Squad/SquadViewModel.swift
import Foundation
import GRDB

@MainActor @Observable
final class SquadViewModel {
    var filter = SquadFilter()
    var sort: SquadSort = .name
    private(set) var all: [PaddlerWithErg] = []

    private let squad: SquadRepository
    init(db: AppDatabase) { self.squad = SquadRepository(db: db) }

    var visible: [PaddlerWithErg] { SquadQuery.apply(all, filter: filter, sort: sort) }

    func load() async { all = (try? await squad.paddlers()) ?? [] }
}
```

- [ ] **Step 4: Run test to verify it passes** — grep `SquadViewModelTests|TEST SUCCEEDED`. Expected: PASS.
- [ ] **Step 5: Commit** — `git commit -m "feat(app): SquadViewModel over SquadQuery"`

---

## Task 5: `PaddlerDetailView` + `PaddlerFormView`

**Files:** Create `apple/Sources/Features/Squad/PaddlerDetailView.swift`, `apple/Sources/Features/Squad/PaddlerFormView.swift`.

**Interfaces:**
- `struct PaddlerFormView: View` with `init(clubId: String, existing: PaddlerRow?, onSave: @escaping (PaddlerRow) async -> Void)` (create when `existing == nil`, else edit).
- `struct PaddlerDetailView: View` with `init(paddlerId: String)`; an internal `@MainActor @Observable PaddlerDetailModel` (loads the paddler + erg history; archive).

- [ ] **Step 1: Write `PaddlerFormView`**

```swift
// apple/Sources/Features/Squad/PaddlerFormView.swift
// Create or edit a paddler. Hands a fully-formed PaddlerRow back through
// onSave (the caller's repository does the upsert), then dismisses.
import SwiftUI

struct PaddlerFormView: View {
    let clubId: String
    let existing: PaddlerRow?
    let onSave: (PaddlerRow) async -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var name: String
    @State private var weight: String
    @State private var side: SidePref
    @State private var gender: RowGender
    @State private var seat: SeatPref
    @State private var role: RowBoatRole
    @State private var email: String

    init(clubId: String, existing: PaddlerRow?, onSave: @escaping (PaddlerRow) async -> Void) {
        self.clubId = clubId; self.existing = existing; self.onSave = onSave
        _name = State(initialValue: existing?.name ?? "")
        _weight = State(initialValue: existing.map { String($0.weightKg) } ?? "")
        _side = State(initialValue: existing?.preferredSide ?? .either)
        _gender = State(initialValue: existing?.gender ?? .female)
        _seat = State(initialValue: existing?.seatPreference ?? .none)
        _role = State(initialValue: existing?.boatRole ?? .paddler)
        _email = State(initialValue: existing?.email ?? "")
    }

    private var canSave: Bool { !name.trimmingCharacters(in: .whitespaces).isEmpty && Double(weight) != nil }

    var body: some View {
        NavigationStack {
            Form {
                Section { TextField("Name", text: $name); TextField("Weight (kg)", text: $weight)
                    #if os(iOS)
                    .keyboardType(.decimalPad)
                    #endif
                } header: { MicroLabel("PADDLER") }
                Section {
                    Picker("Side", selection: $side) { Text("Left").tag(SidePref.left); Text("Right").tag(SidePref.right); Text("Either").tag(SidePref.either) }
                    Picker("Gender", selection: $gender) { Text("Female").tag(RowGender.female); Text("Male").tag(RowGender.male) }
                    Picker("Seat", selection: $seat) { ForEach([SeatPref.stroke,.pace,.engine,.sprint,.none], id: \.self) { Text($0.rawValue.capitalized).tag($0) } }
                    Picker("Role", selection: $role) { ForEach([RowBoatRole.paddler,.drummer,.sweep], id: \.self) { Text($0.rawValue.capitalized).tag($0) } }
                }
                Section { TextField("Email (for invite)", text: $email)
                    #if os(iOS)
                    .textInputAutocapitalization(.never).keyboardType(.emailAddress)
                    #endif
                } header: { MicroLabel("LINK") }
            }
            .navigationTitle(existing == nil ? "New paddler" : "Edit paddler")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { Task { await onSave(makeRow()); dismiss() } }.disabled(!canSave)
                }
            }
        }
    }

    private func makeRow() -> PaddlerRow {
        PaddlerRow(id: existing?.id ?? UUID().uuidString, clubId: clubId,
                   profileId: existing?.profileId, name: name.trimmingCharacters(in: .whitespaces),
                   email: email.isEmpty ? nil : email.lowercased(), weightKg: Double(weight) ?? 0,
                   preferredSide: side, gender: gender, seatPreference: seat, boatRole: role,
                   archivedAt: existing?.archivedAt, createdAt: existing?.createdAt ?? Date(),
                   updatedAt: Date())
    }
}
```

- [ ] **Step 2: Write `PaddlerDetailView`** (with the erg sparkline)

```swift
// apple/Sources/Features/Squad/PaddlerDetailView.swift
// Paddler detail: fields, an erg-history sparkline (Swift Charts), invite/link
// status, edit, and archive (never delete).
import SwiftUI
import Charts

@MainActor @Observable
final class PaddlerDetailModel {
    let paddlerId: String
    private(set) var paddler: PaddlerWithErg?
    private(set) var ergHistory: [ErgTest] = []
    private let squad: SquadRepository
    let clubId: String

    init(paddlerId: String, db: AppDatabase, clubId: String) {
        self.paddlerId = paddlerId; self.squad = SquadRepository(db: db); self.clubId = clubId
    }
    func load() async {
        paddler = try? await squad.paddler(id: paddlerId)
        ergHistory = (try? await squad.ergHistory(paddlerId: paddlerId)) ?? []
    }
    func save(_ row: PaddlerRow) async { _ = try? await squad.upsert(row); await load() }
    func archive() async { try? await squad.archive(id: paddlerId); await load() }
}

struct PaddlerDetailView: View {
    let paddlerId: String
    @Environment(AppModel.self) private var app
    @Environment(\.dismiss) private var dismiss
    @State private var model: PaddlerDetailModel?
    @State private var editing = false

    var body: some View {
        Group { if let model, let pw = model.paddler { content(model, pw) } else { ProgressView() } }
            .navigationTitle(model?.paddler?.row.name ?? "Paddler")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .background(DS.bg)
            .task {
                if model == nil {
                    let clubId = (try? app.environment.db.read { db in try Club.fetchOne(db)?.id }) ?? ""
                    model = PaddlerDetailModel(paddlerId: paddlerId, db: app.environment.db, clubId: clubId ?? "")
                }
                await model?.load()
            }
    }

    @ViewBuilder private func content(_ model: PaddlerDetailModel, _ pw: PaddlerWithErg) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DS.Space.m) {
                HairlineCard {
                    VStack(alignment: .leading, spacing: DS.Space.s) {
                        HStack {
                            Pill(pw.row.gender == .female ? "Female" : "Male",
                                 fill: pw.row.gender == .female ? DS.femaleFill : DS.maleFill)
                            Pill(pw.row.preferredSide.rawValue.capitalized)
                            Pill(pw.row.seatPreference.rawValue.capitalized)
                            Pill(pw.row.boatRole.rawValue.capitalized)
                        }
                        Text("\(pw.row.weightKg, specifier: "%.0f") kg").font(.dsHeadline).foregroundStyle(DS.ink)
                        Text(pw.row.profileId != nil ? "Linked" : (pw.row.email != nil ? "Invitable" : "No email"))
                            .font(.dsCaption).foregroundStyle(pw.row.profileId != nil ? DS.good : DS.ink3)
                    }
                }
                if !model.ergHistory.isEmpty {
                    MicroLabel("ERG HISTORY")
                    HairlineCard {
                        Chart(model.ergHistory, id: \.id) { e in
                            LineMark(x: .value("Date", e.testedAt), y: .value("Metres", e.metres))
                                .foregroundStyle(DS.accent)
                        }
                        .frame(height: 120)
                    }
                }
                Button("Edit") { editing = true }.foregroundStyle(DS.accent)
                Button("Archive", role: .destructive) { Task { await model.archive(); dismiss() } }
            }
            .padding(DS.Space.l)
        }
        .sheet(isPresented: $editing) {
            PaddlerFormView(clubId: model.clubId, existing: pw.row) { row in await model.save(row) }
        }
    }
}
```

Note: verify `Pill`'s init signature against `Sources/DesignSystem/Components/Pill.swift` — it takes a label and (from 4a) a `fill:`/`foreground:` param; adapt the calls to the real signature (use the default tinted pill if the exact params differ). `weightKg` is a `Double`; `Text("\(x, specifier:)")` is fine.

- [ ] **Step 3: Build + verify** — iOS gate + macOS build green (`import Charts` resolves; count unchanged at +5 from Tasks 1-4 tests).
- [ ] **Step 4: Commit** — `git commit -m "feat(app): PaddlerDetailView (erg sparkline, archive) + PaddlerFormView"`

---

## Task 6: `SquadView` + wire into the shell

**Files:** Create `apple/Sources/Features/Squad/SquadView.swift`; Modify `apple/Sources/App/RootView.swift`; Delete `apple/Sources/Features/SquadPlaceholder.swift`.

**Interfaces:** `struct SquadView: View` (owns a `NavigationStack` + `SquadViewModel`; searchable, sortable, filterable list; `+` → `PaddlerFormView`; row → `PaddlerDetailView`).

- [ ] **Step 1: Write `SquadView`**

```swift
// apple/Sources/Features/Squad/SquadView.swift
import SwiftUI

struct SquadView: View {
    @Environment(AppModel.self) private var app
    @State private var model: SquadViewModel?
    @State private var adding = false

    var body: some View {
        NavigationStack {
            Group { if let model { content(model) } else { ProgressView() } }
                .navigationTitle("Squad")
                .background(DS.bg)
                .toolbar {
                    ToolbarItem(placement: .primaryAction) { Button { adding = true } label: { Image(systemName: "plus") } }
                }
                .navigationDestination(for: PaddlerWithErg.self) { pw in PaddlerDetailView(paddlerId: pw.row.id) }
                .sheet(isPresented: $adding) {
                    let clubId = (try? app.environment.db.read { db in try Club.fetchOne(db)?.id }) ?? ""
                    PaddlerFormView(clubId: clubId ?? "", existing: nil) { row in
                        _ = try? await SquadRepository(db: app.environment.db).upsert(row)
                        await model?.load()
                    }
                }
        }
        .task {
            if model == nil { model = SquadViewModel(db: app.environment.db) }
            await model?.load()
        }
    }

    @ViewBuilder private func content(_ model: SquadViewModel) -> some View {
        @Bindable var model = model
        List {
            Section {
                Picker("Sort", selection: $model.sort) { ForEach(SquadSort.allCases) { Text($0.label).tag($0) } }
                    .pickerStyle(.segmented)
                Toggle("Linked only", isOn: $model.filter.linkedOnly)
            }
            ForEach(model.visible) { pw in
                NavigationLink(value: pw) { row(pw) }
            }
        }
        .searchable(text: $model.filter.search)
    }

    private func row(_ pw: PaddlerWithErg) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(pw.row.name).font(.dsBody).foregroundStyle(DS.ink)
                Text("\(pw.row.weightKg, specifier: "%.0f") kg · \(pw.row.preferredSide.rawValue) · \(pw.row.seatPreference.rawValue)")
                    .font(.dsCaption).foregroundStyle(DS.ink3)
            }
            Spacer()
            if let m = pw.latestErg?.metres { Text("\(m) m").font(.dsCaption).foregroundStyle(DS.ink2).monospacedDigit() }
        }
    }
}
```

- [ ] **Step 2: Wire the shell + delete the placeholder** — in `RootView.swift` replace `SquadPlaceholder()` with `SquadView()` at BOTH sites (iOS tab tag 2 + macOS `macDetail` `.squad`). `git rm apple/Sources/Features/SquadPlaceholder.swift`. `grep -rn SquadPlaceholder apple/Sources` → empty.
- [ ] **Step 3: Build + verify** — iOS + macOS green.
- [ ] **Step 4: Commit** — `git commit -m "feat(app): Squad tab — searchable/sortable roster"` (use `git rm` for the deleted file)

---

## Task 7: `CrewDetailView` + `CrewFormView`

**Files:** Create `apple/Sources/Features/Crews/CrewDetailView.swift`, `apple/Sources/Features/Crews/CrewFormView.swift`.

**Interfaces:**
- `struct CrewFormView: View` with `init(clubId: String, onCreate: @escaping (_ name: String, _ ageDivision: String, _ category: CrewCategory) async -> Void)`.
- `struct CrewDetailView: View` with `init(crewId: String)`; an internal `@MainActor @Observable CrewDetailModel` (loads crew + members + races + the gender-rule verdict; add/remove members).

- [ ] **Step 1: Write `CrewFormView`**

```swift
// apple/Sources/Features/Crews/CrewFormView.swift
import SwiftUI

struct CrewFormView: View {
    let clubId: String
    let onCreate: (_ name: String, _ ageDivision: String, _ category: CrewCategory) async -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var division = "Premier"
    @State private var category: CrewCategory = .mixed
    private let divisions = ["16U", "18U", "24U", "Premier", "Senior A", "Senior B", "Senior C"]

    var body: some View {
        NavigationStack {
            Form {
                TextField("Crew name", text: $name)
                Picker("Division", selection: $division) { ForEach(divisions, id: \.self) { Text($0).tag($0) } }
                Picker("Category", selection: $category) {
                    Text("Open").tag(CrewCategory.open); Text("Women").tag(CrewCategory.women); Text("Mixed").tag(CrewCategory.mixed)
                }
            }
            .navigationTitle("New crew")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") { Task { await onCreate(name.trimmingCharacters(in: .whitespaces), division, category); dismiss() } }
                        .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }
}
```

- [ ] **Step 2: Write `CrewDetailView`** (members, gender-rule check, add/remove, races)

```swift
// apple/Sources/Features/Crews/CrewDetailView.swift
// Crew detail: members (gender/side/weight/erg chips), the IDBF gender-rule
// check (women/men vs the crew's standard-boat rule, via PaddltirCore's
// GenderRule), add/remove from the squad, and the crew's races.
import SwiftUI
import PaddltirCore

@MainActor @Observable
final class CrewDetailModel {
    let crewId: String
    private(set) var crew: Crew?
    private(set) var members: [PaddlerWithErg] = []
    private(set) var races: [Race] = []
    private(set) var squad: [PaddlerWithErg] = []
    private(set) var ruleVerdict: String?    // nil = OK or no rule
    private(set) var tally = GenderTally(women: 0, men: 0)

    private let crews: CrewRepository
    private let squadRepo: SquadRepository
    private let db: AppDatabase
    init(crewId: String, db: AppDatabase) {
        self.crewId = crewId; self.db = db
        self.crews = CrewRepository(db: db); self.squadRepo = SquadRepository(db: db)
    }

    var memberIds: Set<String> { Set(members.map(\.row.id)) }

    func load() async {
        let loaded = try? await crews.crew(id: crewId)
        crew = loaded?.crew
        members = loaded?.members ?? []
        races = (try? await crews.racesForCrew(crewId: crewId)) ?? []
        squad = (try? await squadRepo.paddlers()) ?? []
        tally = GenderTally.of(members)
        if let crew {
            let rule = try? db.read { db -> GenderRule? in
                let key: [String: (any DatabaseValueConvertible)?] = ["club_id": crew.clubId, "category": crew.category.rawValue, "boat_size": BoatSize.standard.rawValue]
                return DomainMapping.genderRule(try CategoryRule.fetchOne(db, key: key))
            } ?? nil
            ruleVerdict = rule?.violation(women: tally.women, men: tally.men)
        }
    }

    func toggle(_ paddlerId: String) async {
        var ids = memberIds
        if ids.contains(paddlerId) { ids.remove(paddlerId) } else { ids.insert(paddlerId) }
        try? await crews.setMembers(crewId: crewId, paddlerIds: Array(ids))
        await load()
    }
}

struct CrewDetailView: View {
    let crewId: String
    @Environment(AppModel.self) private var app
    @State private var model: CrewDetailModel?
    @State private var addingMembers = false

    var body: some View {
        Group { if let model, model.crew != nil { content(model) } else { ProgressView() } }
            .navigationTitle(model?.crew?.name ?? "Crew")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .background(DS.bg)
            .task {
                if model == nil { model = CrewDetailModel(crewId: crewId, db: app.environment.db) }
                await model?.load()
            }
            .sheet(isPresented: $addingMembers) { if let model { memberPicker(model) } }
    }

    @ViewBuilder private func content(_ model: CrewDetailModel) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DS.Space.m) {
                HairlineCard {
                    HStack {
                        Text("W \(model.tally.women) · M \(model.tally.men)").font(.dsHeadline).foregroundStyle(DS.ink)
                        Spacer()
                        if let why = model.ruleVerdict {
                            Text(why).font(.dsCaption).foregroundStyle(DS.danger)
                        } else {
                            Text("Within rule").font(.dsCaption).foregroundStyle(DS.good)
                        }
                    }
                }
                HStack { MicroLabel("MEMBERS"); Spacer(); Button("Edit") { addingMembers = true }.font(.dsCaption).foregroundStyle(DS.accent) }
                ForEach(model.members) { pw in memberRow(pw) }
                if !model.races.isEmpty {
                    MicroLabel("RACES")
                    ForEach(model.races, id: \.id) { race in
                        HairlineCard { Text("\(race.name) · \(race.boatSize == .standard ? "Standard" : "Small")").font(.dsCallout).foregroundStyle(DS.ink2) }
                    }
                }
            }
            .padding(DS.Space.l)
        }
    }

    private func memberRow(_ pw: PaddlerWithErg) -> some View {
        HairlineCard {
            HStack {
                Text(pw.row.name).font(.dsBody).foregroundStyle(DS.ink)
                Spacer()
                Pill(pw.row.gender == .female ? "F" : "M", fill: pw.row.gender == .female ? DS.femaleFill : DS.maleFill)
                Text("\(pw.row.weightKg, specifier: "%.0f")kg").font(.dsCaption).foregroundStyle(DS.ink3)
                if let m = pw.latestErg?.metres { Text("\(m)m").font(.dsCaption).foregroundStyle(DS.ink3).monospacedDigit() }
            }
        }
    }

    private func memberPicker(_ model: CrewDetailModel) -> some View {
        NavigationStack {
            List(model.squad) { pw in
                Button { Task { await model.toggle(pw.row.id) } } label: {
                    HStack {
                        Text(pw.row.name).foregroundStyle(DS.ink)
                        Spacer()
                        if model.memberIds.contains(pw.row.id) { Image(systemName: "checkmark").foregroundStyle(DS.accent) }
                    }
                }
                .buttonStyle(.plain)
            }
            .navigationTitle("Members")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
        }
    }
}
```

Note: verify `Pill`'s init (label + `fill:`) against the shipped `Pill.swift`; adapt if the param names differ. `DatabaseValueConvertible` comes from `import GRDB` — add it to the imports if the compiler needs it (this file imports SwiftUI + PaddltirCore; add `import GRDB` for the `CategoryRule.fetchOne` key type). The composite-key `fetchOne(db, key:)` dictionary form mirrors `LineupRepository.placementRequest`.

- [ ] **Step 3: Build + verify** — iOS + macOS green.
- [ ] **Step 4: Commit** — `git commit -m "feat(app): CrewDetailView (members, gender-rule, races) + CrewFormView"`

---

## Task 8: `CrewsView` (+ `CrewsViewModel`) + wire into the shell

**Files:** Create `apple/Sources/Features/Crews/CrewsView.swift`; Modify `apple/Sources/App/RootView.swift`; Delete `apple/Sources/Features/CrewsPlaceholder.swift`.

**Interfaces:** `@MainActor @Observable final class CrewsViewModel` (`init(db:)`, `private(set) var summaries: [CrewRepository.CrewSummary]`, `var clubId: String?`, `func load() async`, `func createCrew(name:division:category:) async`); `struct CrewsView: View` (NavigationStack; crew cards; `+` → `CrewFormView`; card → `CrewDetailView`).

- [ ] **Step 1: Write `CrewsViewModel` + `CrewsView`**

```swift
// apple/Sources/Features/Crews/CrewsView.swift
import SwiftUI

@MainActor @Observable
final class CrewsViewModel {
    private(set) var summaries: [CrewRepository.CrewSummary] = []
    private(set) var clubId: String?
    private let crews: CrewRepository
    private let db: AppDatabase
    init(db: AppDatabase) { self.db = db; self.crews = CrewRepository(db: db) }

    func load() async {
        clubId = try? db.read { db in try Club.fetchOne(db)?.id }
        summaries = (try? await crews.summaries(now: Date())) ?? []
    }
    func createCrew(name: String, division: String, category: CrewCategory) async {
        guard let clubId else { return }
        _ = try? await crews.createCrew(clubId: clubId, name: name, ageDivision: division, category: category)
        await load()
    }
}

struct CrewsView: View {
    @Environment(AppModel.self) private var app
    @State private var model: CrewsViewModel?
    @State private var adding = false

    var body: some View {
        NavigationStack {
            Group { if let model { content(model) } else { ProgressView() } }
                .navigationTitle("Crews")
                .background(DS.bg)
                .toolbar { ToolbarItem(placement: .primaryAction) { Button { adding = true } label: { Image(systemName: "plus") } } }
                .navigationDestination(for: CrewRepository.CrewSummary.self) { s in CrewDetailView(crewId: s.crew.id) }
                .sheet(isPresented: $adding) {
                    if let model, let clubId = model.clubId {
                        CrewFormView(clubId: clubId) { name, div, cat in await model.createCrew(name: name, division: div, category: cat) }
                    }
                }
        }
        .task {
            if model == nil { model = CrewsViewModel(db: app.environment.db) }
            await model?.load()
        }
    }

    @ViewBuilder private func content(_ model: CrewsViewModel) -> some View {
        ScrollView {
            VStack(spacing: DS.Space.m) {
                if model.summaries.isEmpty {
                    Text("No crews yet — tap + to add one.").font(.dsCaption).foregroundStyle(DS.ink3).padding(.top, DS.Space.xl)
                }
                ForEach(model.summaries) { s in
                    NavigationLink(value: s) {
                        HairlineCard {
                            VStack(alignment: .leading, spacing: DS.Space.xs) {
                                Text(s.crew.name).font(.dsHeadline).foregroundStyle(DS.ink)
                                HStack(spacing: DS.Space.s) {
                                    Pill(s.crew.ageDivision)
                                    Pill(s.crew.category.rawValue.capitalized)
                                    Text("\(s.memberCount) paddlers").font(.dsCaption).foregroundStyle(DS.ink3)
                                }
                                if let next = s.nextRaceName { Text("Next: \(next)").font(.dsCaption).foregroundStyle(DS.accent) }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(DS.Space.l)
        }
    }
}
```

- [ ] **Step 2: Wire the shell + delete the placeholder** — in `RootView.swift` replace `CrewsPlaceholder()` with `CrewsView()` at BOTH sites (iOS tab tag 1 + macOS `macDetail` `.crews`). `git rm apple/Sources/Features/CrewsPlaceholder.swift`. `grep -rn CrewsPlaceholder apple/Sources` → empty.

Note: `CrewRepository.CrewSummary` must be `Hashable` for `navigationDestination(for:)` — it is (declared `Hashable` in Task 2).

- [ ] **Step 3: Build + verify** — iOS + macOS green; both placeholders gone.
- [ ] **Step 4: Commit** — `git commit -m "feat(app): Crews tab — cards, create, detail nav"` (use `git rm`)

---

## Task 9: Integration & verification

**Files:** none new — verification + docs.

- [ ] **Step 1: Full build gate (iOS + macOS), whole suite green**

```bash
cd apple && xcodegen generate
xcodebuild -scheme Paddltir -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -derivedDataPath DerivedData test 2>&1 | grep -iE "Test run with .* tests|skipped|TEST SUCCEEDED|error:|warning:.*\.swift"
xcodebuild -scheme Paddltir -destination 'platform=macOS' build 2>&1 | tail -3
```
Expected: all new unit tests pass (ergHistory, crew writes, SquadModels, SquadViewModel), gated live tests **skipped**, ZERO Swift warnings, macOS builds.

- [ ] **Step 2: Run the gated live tests once** (controller, local stack up): `TEST_RUNNER_PADDLTIR_LIVE_SUPABASE=1 xcodebuild ... test -only-testing:PaddltirAppTests/ClubServiceLiveTests -only-testing:PaddltirAppTests/SupabaseRemoteTests` — expect both PASS.

- [ ] **Step 3: Screenshots** (controller, via the DEBUG auto-sign-in + in-memory storage from 4d): capture the Squad and Crews tabs against the seed. Two-launch (sync then render); pass the tab via a fresh launch and tap is not needed for Squad/Crews if they're seeded. Save `apple/screenshots/4e-squad.png`, `4e-crews.png`; surface to Jun.

- [ ] **Step 4: Update PROGRESS.md + roadmap** (post-merge, on main — mark 4e merged; record deferrals: availability-history on paddler detail, crew rename/delete, boat-size-specific gender check in 4f).

- [ ] **Step 5: Commit** any doc/verification artifacts.

---

## Self-Review

**Spec coverage (§3 Crews + Squad):**
- Squad: searchable/sortable table (name, weight, erg, side, section, role) + filters (side, gender, role, linked) → Tasks 3+4+6. ✓ (Filter UI in Task 6 exposes sort + linked-only + search; side/gender/role filters are in `SquadFilter` and driven by the same picker pattern — the view wires the ones shown; **note:** if Jun wants all filter chips surfaced, extend the Task 6 filter section.)
- Paddler detail: fields, erg history sparkline, invite/link status, **Archive** → Task 5. ✓ (Availability history: **deferred** — needs an availability-by-paddler join; flag for 4g.)
- Add/edit paddler → Task 5 (`PaddlerFormView` via `upsert`). ✓
- Crews cards (name, division, category, members, next race) → Tasks 2+8. ✓
- Crew detail: members with side/weight/erg chips, add/remove from squad (search), races, gender-rule check → Task 7 (reuses `PaddltirCore.GenderRule.violation`). ✓
- Create crew → Tasks 2+7/8. ✓

**Placeholder scan:** no "TBD"/"handle errors"/"similar to"; every view/repo has full code. Two explicit "verify `Pill` init signature against the shipped component" notes are lookups, not gaps.

**Type consistency:** `SquadQuery`/`SquadFilter`/`SquadSort`/`GenderTally` names consistent (Tasks 3/4/6/7). `CrewRepository.CrewSummary` used identically (Tasks 2/8). Repo method names match between Task 1/2 definitions and Tasks 4/5/7/8 call sites (`ergHistory`, `createCrew`, `racesForCrew`, `summaries`, `paddlers`, `upsert`, `archive`, `setMembers`, `crew`). `PaddlerWithErg`/`Crew`/`CrewSummary` Hashable used for navigation.

**Known deferrals (flag at merge):** availability-history on paddler detail; surfacing every squad filter chip (side/gender/role) in the UI (the model supports them); crew rename/delete; the boat-size-specific gender-rule check (4f); plus the standing 4g items (sync-completion refresh, NavigationStack-wrapped tabs — now moot since these tabs own their own NavigationStack).

## Execution Handoff

**Plan complete and saved to `docs/superpowers/plans/2026-08-25-plan-4e-crews-squad.md`.** Executing via subagent-driven-development (the project's established mode): fresh implementer per task, task review after each, final whole-branch review before merge. Tasks are ordered so detail/form views precede their tab views (no forward references).

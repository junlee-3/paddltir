# Plan 4d — Schedule & Availability Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build the Schedule tab — a day-grouped timeline with an "Up next" hero, session creation (training / race day), a training-session detail with an availability list + coach override + a record-erg quick action, and a race-day detail with its races + day headcount + add-race — all offline-first over GRDB with outbox writes.

**Architecture:** Add the write half to `ScheduleRepository` (session/availability/race) and a `recordErg` to `SquadRepository`, each mutation + its `Outbox.enqueue` in one GRDB transaction (the exact pattern `CrewRepository.setMembers` already uses). Pure, unit-tested helpers (`Headcount`, `ScheduleGrouping`) do the day-bucketing and in/out/maybe/no-reply math. A `@MainActor @Observable ScheduleViewModel` composes repositories + helpers for the screens. SwiftUI feature views (`ScheduleView`, `SessionFormView`, `TrainingDetailView`, `RaceDayDetailView`) render through the 4a design system inside a `NavigationStack`, replacing `SchedulePlaceholder`.

**Tech Stack:** SwiftUI + Observation, GRDB (via the Plan 4b `AppDatabase`/repositories/`Outbox`), the 4a DesignSystem, the Plan 4c `AppModel`/`SessionController` shell.

**Spec:** `docs/superpowers/specs/2026-08-22-paddltir-design.md` — §3 "Schedule" (the timeline, Up-next hero, training/race-day detail, availability + coach override, record-erg). Visual direction: `docs/design/direction.md`.

## Global Constraints

- **Rename:** any in-product "CrewCoach" → **Paddltir**.
- **Platforms:** one target, iOS 26 + macOS 26 (`supportedDestinations: [iOS, macOS]`). Every view compiles and lays out on both; guard platform-only APIs with `#if os(...)`.
- **Design system — use the REAL token names** (do NOT invent `DS.Font.*`, `DS.Space.lg/md`, `DS.R.control` — those do not exist):
  - Spacing: `DS.Space.xs`(4) / `.s`(8) / `.m`(12) / `.l`(16) / `.xl`(24).
  - Radius: `DS.R.card`(12) / `.ctl`(8) / `.sm`(6) / `.tile`(8).
  - Typography is a SwiftUI `Font` extension used as `.font(.dsX)`: `.dsLargeTitle`, `.dsTitle`, `.dsHeadline`, `.dsSubhead`, `.dsBody`, `.dsCallout`, `.dsCaption`, `.dsFootnote`, `.dsMicro`. (No `DS.Font` namespace, no monospace token — use `.font(.system(.body, design: .monospaced))` if ever needed.)
  - Colors: `DS.bg`, `DS.surface`, `DS.surface2`, `DS.ink`, `DS.ink2`, `DS.ink3`, `DS.border`, `DS.accent`, `DS.good`, `DS.danger`, `DS.maleFill`/`DS.maleBorder`, `DS.femaleFill`/`DS.femaleBorder`, `DS.primary`, `DS.onPrimary`.
  - Components: `ScreenScaffold(_ title, note:, content:)`, `HairlineCard(padding:content:)`, `AvailabilityRing(count:total:diameter:lineWidth:)`, `GlassContainer(radius:content:)`, `GlassBar(radius:content:)`, `PrimaryButton(_ , action:)`, `SecondaryButton(_ , action:)`, `Pill(...)`, `MicroLabel(_)`. Never raw hex or `Font.system` (the monospace exception aside).
- **Light mode only.** Style through DS tokens/components — never raw hex/fonts in a view.
- **Writes = GRDB mutation + `Outbox.enqueue` in ONE `db.write { }` transaction**, mirroring `CrewRepository.setMembers` (`apple/Sources/Data/Repositories/CrewRepository.swift`). Payloads encode via `PostgREST.encoder`; the outbox `pk` uses the row's `syncPrimaryKey` (bare `id` for sessions/races/erg_tests; `"\(sessionId)|\(paddlerId)"` for availability — see `apple/Sources/Data/Sync/SyncableTable.swift`); `op` is `"insert"` for new rows, `"update"` for an availability upsert.
- **Repositories stay UI-free** (no SwiftUI import); **PaddltirCore stays UI-free** (day-grouping/headcount are app-layer display helpers, NOT PaddltirCore).
- **Build gate:** `cd apple && xcodegen generate && xcodebuild -scheme Paddltir -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -derivedDataPath DerivedData test` — regenerate first (new files aren't in the project until you do). Also compile macOS: `xcodebuild -scheme Paddltir -destination 'platform=macOS' build`.
- **Secrets:** `Sources/App/Secrets.swift` is git-ignored; never commit keys.
- **Data facts:** `SessionKind` = `.training` / `.raceDay`(`"race_day"`). `AvailabilityStatus` = `.in` / `.out` / `.maybe`; **"no reply" is the ABSENCE of an availability row** (a squad paddler with no row). `ErgSource` = `.coach` / `.selfReported`(`"self"`). `ErgTest.metres` is an `Int`. A session belongs to a club (`SessionRow.clubId`); the app mirrors exactly one club locally (`Club.fetchOne`).

## File Structure

New (under `apple/`):
- `Sources/Features/Schedule/ScheduleModels.swift` — pure `Headcount` + `ScheduleGrouping` (day sections, upcoming/past, up-next).
- `Sources/Features/Schedule/ScheduleViewModel.swift` — `@MainActor @Observable`, composes repos + helpers.
- `Sources/Features/Schedule/ScheduleView.swift` — the tab (NavigationStack, Up-next hero, sections, `+` menu).
- `Sources/Features/Schedule/SessionFormView.swift` — create training / race-day session.
- `Sources/Features/Schedule/TrainingDetailView.swift` — availability list + coach override + record-erg.
- `Sources/Features/Schedule/RaceDayDetailView.swift` — races + day headcount + add-race (+ a `LineupEditorPlaceholder` nav stub until 4f).
- Tests: `Tests/PaddltirAppTests/ScheduleRepositoryWriteTests.swift`, `RecordErgTests.swift`, `ScheduleModelsTests.swift`, `ScheduleViewModelTests.swift`.

Modified:
- `Sources/Data/Repositories/ScheduleRepository.swift` — rename `upcomingSessions()`→`sessions()`; add `createSession`, `setAvailability`, `createRace`.
- `Sources/Data/Repositories/SquadRepository.swift` — add `recordErg`.
- `Sources/App/RootView.swift` — replace `SchedulePlaceholder()` with `ScheduleView()` at both call sites (iOS tab tag 0 + macOS `macDetail` `.schedule`).
- Delete `Sources/Features/SchedulePlaceholder.swift`.

---

## Task 1: `ScheduleRepository` writes + `sessions()` rename

**Files:**
- Modify: `apple/Sources/Data/Repositories/ScheduleRepository.swift`
- Test: `apple/Tests/PaddltirAppTests/ScheduleRepositoryWriteTests.swift`

**Interfaces:**
- Consumes: `AppDatabase`, `Outbox`, `PostgREST.encoder`, `SessionRow`/`Availability`/`Race` models + their `syncPrimaryKey`.
- Produces (added to `ScheduleRepository`):
  - `func sessions() async throws -> [SessionRow]` (rename of `upcomingSessions()`; body unchanged).
  - `func createSession(clubId: String, kind: SessionKind, title: String, startsAt: Date, venue: String?, notes: String?) async throws -> SessionRow`
  - `func setAvailability(sessionId: String, paddlerId: String, status: AvailabilityStatus, note: String?) async throws`
  - `func createRace(sessionId: String, crewId: String, name: String, boatSize: BoatSize, distanceM: Int?) async throws -> Race`

- [ ] **Step 1: Write the failing test**

```swift
// apple/Tests/PaddltirAppTests/ScheduleRepositoryWriteTests.swift
import Foundation
import GRDB
import Testing
@testable import Paddltir

@Suite struct ScheduleRepositoryWriteTests {
    private let t0 = Date(timeIntervalSince1970: 1_700_000_000)

    private func makeClubRow(_ db: Database, id: String) throws {
        try Club(id: id, name: "C", inviteCode: "ABCD2345", createdBy: nil, createdAt: Date(), updatedAt: nil).insert(db)
    }

    @Test func createSessionWritesRowAndOutbox() async throws {
        let appDB = try AppDatabase.inMemory()
        let repo = ScheduleRepository(db: appDB)
        let session = try await repo.createSession(
            clubId: "club-1", kind: .training, title: "Tuesday paddle",
            startsAt: t0, venue: "Iron Cove", notes: nil)

        #expect(session.title == "Tuesday paddle")
        #expect(session.kind == .training)
        let stored = try appDB.read { db in try SessionRow.fetchOne(db, key: session.id) }
        #expect(stored?.title == "Tuesday paddle")
        // one insert queued for the sessions table
        let entries = try appDB.read { db in try OutboxEntry.filter(Column("table_name") == "sessions").fetchAll(db) }
        #expect(entries.count == 1)
        #expect(entries.first?.op == "insert")
        #expect(entries.first?.pk == session.id)
    }

    @Test func setAvailabilityUpsertsAndEnqueues() async throws {
        let appDB = try AppDatabase.inMemory()
        let repo = ScheduleRepository(db: appDB)
        try await repo.setAvailability(sessionId: "s-1", paddlerId: "p-1", status: .in, note: "driving")
        try await repo.setAvailability(sessionId: "s-1", paddlerId: "p-1", status: .out, note: nil) // override

        let rows = try appDB.read { db in try Availability.filter(Column("session_id") == "s-1").fetchAll(db) }
        #expect(rows.count == 1)                 // upsert, not duplicate
        #expect(rows.first?.status == .out)
        let entries = try appDB.read { db in try OutboxEntry.filter(Column("table_name") == "availability").fetchAll(db) }
        #expect(entries.count == 2)              // both writes queued
        #expect(entries.allSatisfy { $0.pk == "s-1|p-1" })
    }

    @Test func createRaceWritesRowAndOutbox() async throws {
        let appDB = try AppDatabase.inMemory()
        let repo = ScheduleRepository(db: appDB)
        let race = try await repo.createRace(sessionId: "s-1", crewId: "c-1", name: "Heat A", boatSize: .standard, distanceM: 500)
        #expect(race.name == "Heat A")
        #expect(race.sortOrder == 0)             // first race → order 0
        let race2 = try await repo.createRace(sessionId: "s-1", crewId: "c-1", name: "Heat B", boatSize: .standard, distanceM: 200)
        #expect(race2.sortOrder == 1)            // next → order 1
        let entries = try appDB.read { db in try OutboxEntry.filter(Column("table_name") == "races").fetchAll(db) }
        #expect(entries.count == 2)
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd apple && xcodegen generate && xcodebuild -scheme Paddltir -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -derivedDataPath DerivedData test 2>&1 | grep -iE "ScheduleRepositoryWrite|createSession|error:"`
Expected: FAIL — `value of type 'ScheduleRepository' has no member 'createSession'`.

- [ ] **Step 3: Write the implementation** (edit `ScheduleRepository.swift`)

Rename `upcomingSessions()` to `sessions()` (keep the body + doc). Add the writes. Add `import` nothing new (already `Foundation`, `GRDB`). Append inside the struct:

```swift
    // MARK: - Writes (each mutation + its outbox entry in one transaction)

    /// Creates a training or race-day session for `clubId`.
    func createSession(clubId: String, kind: SessionKind, title: String,
                       startsAt: Date, venue: String?, notes: String?) async throws -> SessionRow {
        let row = SessionRow(id: UUID().uuidString, clubId: clubId, kind: kind, title: title,
                             startsAt: startsAt, venue: venue, notes: notes,
                             createdAt: Date(), updatedAt: nil)
        try db.write { db in
            try row.insert(db)
            try Outbox.enqueue(db: db, table: SessionRow.databaseTableName, pk: row.syncPrimaryKey,
                               op: "insert", payload: try PostgREST.encoder.encode(row))
        }
        return row
    }

    /// Coach override (or first capture) of a paddler's availability for a
    /// session — upserts on (session_id, paddler_id).
    func setAvailability(sessionId: String, paddlerId: String,
                         status: AvailabilityStatus, note: String?) async throws {
        let row = Availability(sessionId: sessionId, paddlerId: paddlerId,
                               status: status, note: note, updatedAt: Date())
        try db.write { db in
            try row.upsert(db)
            try Outbox.enqueue(db: db, table: Availability.databaseTableName, pk: row.syncPrimaryKey,
                               op: "update", payload: try PostgREST.encoder.encode(row))
        }
    }

    /// Adds a race to a race-day session; `sort_order` is the next free slot.
    func createRace(sessionId: String, crewId: String, name: String,
                    boatSize: BoatSize, distanceM: Int?) async throws -> Race {
        try db.write { db in
            let order = try Race.filter(Column("session_id") == sessionId).fetchCount(db)
            let row = Race(id: UUID().uuidString, sessionId: sessionId, crewId: crewId, name: name,
                           boatSize: boatSize, distanceM: distanceM, sortOrder: order,
                           createdAt: Date(), updatedAt: nil)
            try row.insert(db)
            try Outbox.enqueue(db: db, table: Race.databaseTableName, pk: row.syncPrimaryKey,
                               op: "insert", payload: try PostgREST.encoder.encode(row))
            return row
        }
    }
```

Update the file header's "No writes yet" sentence to note writes now exist.

- [ ] **Step 4: Run tests to verify they pass**

Run: same as Step 2 (grep `ScheduleRepositoryWriteTests|TEST SUCCEEDED`). Expected: 3 tests PASS. Also `grep -rn "upcomingSessions" apple/Sources apple/Tests` returns nothing (rename complete).

- [ ] **Step 5: Commit**

```bash
git add apple/Sources/Data/Repositories/ScheduleRepository.swift apple/Tests/PaddltirAppTests/ScheduleRepositoryWriteTests.swift
git commit -m "feat(app): ScheduleRepository writes (session/availability/race) + sessions() rename"
```

---

## Task 2: `SquadRepository.recordErg`

**Files:**
- Modify: `apple/Sources/Data/Repositories/SquadRepository.swift`
- Test: `apple/Tests/PaddltirAppTests/RecordErgTests.swift`

**Interfaces:**
- Produces: `func recordErg(paddlerId: String, metres: Int, testedAt: Date, recordedBy: String?) async throws -> ErgTest` (source `.coach`), appended to `SquadRepository`.

- [ ] **Step 1: Write the failing test**

```swift
// apple/Tests/PaddltirAppTests/RecordErgTests.swift
import Foundation
import GRDB
import Testing
@testable import Paddltir

@Suite struct RecordErgTests {
    private let t0 = Date(timeIntervalSince1970: 1_700_000_000)

    @Test func recordErgWritesRowAndOutbox() async throws {
        let appDB = try AppDatabase.inMemory()
        let repo = SquadRepository(db: appDB)
        let erg = try await repo.recordErg(paddlerId: "p-1", metres: 620, testedAt: t0, recordedBy: nil)

        #expect(erg.metres == 620)
        #expect(erg.source == .coach)
        let stored = try appDB.read { db in try ErgTest.fetchOne(db, key: erg.id) }
        #expect(stored?.metres == 620)
        let entries = try appDB.read { db in try OutboxEntry.filter(Column("table_name") == "erg_tests").fetchAll(db) }
        #expect(entries.count == 1)
        #expect(entries.first?.op == "insert")
        #expect(entries.first?.pk == erg.id)
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd apple && xcodegen generate && xcodebuild ... test 2>&1 | grep -iE "RecordErg|recordErg|error:"`
Expected: FAIL — `has no member 'recordErg'`.

- [ ] **Step 3: Write the implementation** (append to `SquadRepository`)

```swift
    /// Records a coach-entered 2-minute erg result (`metres`) for a paddler.
    func recordErg(paddlerId: String, metres: Int, testedAt: Date, recordedBy: String?) async throws -> ErgTest {
        let row = ErgTest(id: UUID().uuidString, paddlerId: paddlerId, testedAt: testedAt,
                          metres: metres, source: .coach, recordedBy: recordedBy, createdAt: Date())
        try db.write { db in
            try row.insert(db)
            try Outbox.enqueue(db: db, table: ErgTest.databaseTableName, pk: row.syncPrimaryKey,
                               op: "insert", payload: try PostgREST.encoder.encode(row))
        }
        return row
    }
```

- [ ] **Step 4: Run tests to verify they pass**

Run: same, grep `RecordErgTests|TEST SUCCEEDED`. Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add apple/Sources/Data/Repositories/SquadRepository.swift apple/Tests/PaddltirAppTests/RecordErgTests.swift
git commit -m "feat(app): SquadRepository.recordErg (coach-entered erg + outbox)"
```

---

## Task 3: Pure schedule logic — `Headcount` + `ScheduleGrouping`

**Files:**
- Create: `apple/Sources/Features/Schedule/ScheduleModels.swift`
- Test: `apple/Tests/PaddltirAppTests/ScheduleModelsTests.swift`

**Interfaces:**
- Produces:
  - `struct Headcount: Equatable { let inCount: Int; let outCount: Int; let maybeCount: Int; let noReplyCount: Int; static func compute(availability: [Availability], squadSize: Int) -> Headcount }`
  - `struct DaySection: Identifiable, Equatable { let id: Date; let day: Date; let sessions: [SessionRow] }`
  - `enum ScheduleGrouping { static func upNext(_ sessions: [SessionRow], now: Date) -> SessionRow?; static func upcoming(_ sessions: [SessionRow], now: Date) -> [DaySection]; static func past(_ sessions: [SessionRow], now: Date) -> [DaySection] }`

- [ ] **Step 1: Write the failing test**

```swift
// apple/Tests/PaddltirAppTests/ScheduleModelsTests.swift
import Foundation
import Testing
@testable import Paddltir

@Suite struct ScheduleModelsTests {
    private let now = Date(timeIntervalSince1970: 1_700_000_000) // fixed reference

    private func session(_ id: String, _ offset: TimeInterval) -> SessionRow {
        SessionRow(id: id, clubId: "c", kind: .training, title: id, startsAt: now.addingTimeInterval(offset),
                   venue: nil, notes: nil, createdAt: now, updatedAt: nil)
    }
    private func avail(_ status: AvailabilityStatus) -> Availability {
        Availability(sessionId: "s", paddlerId: UUID().uuidString, status: status, note: nil, updatedAt: now)
    }

    @Test func headcountCountsAndDerivesNoReply() {
        let h = Headcount.compute(availability: [avail(.in), avail(.in), avail(.out), avail(.maybe)], squadSize: 10)
        #expect(h == Headcount(inCount: 2, outCount: 1, maybeCount: 1, noReplyCount: 6))
    }

    @Test func headcountNoReplyNeverNegative() {
        let h = Headcount.compute(availability: [avail(.in), avail(.in)], squadSize: 1) // more replies than squad
        #expect(h.noReplyCount == 0)
    }

    @Test func upNextIsSoonestFutureSession() {
        let s = [session("past", -3600), session("soon", 3600), session("later", 7200)]
        #expect(ScheduleGrouping.upNext(s, now: now)?.id == "soon")
    }

    @Test func upcomingAndPastSplitByDayDescendingPastAscendingUpcoming() {
        let s = [session("yesterday", -86_400), session("today-later", 3600), session("in-3-days", 3 * 86_400)]
        let up = ScheduleGrouping.upcoming(s, now: now)
        let past = ScheduleGrouping.past(s, now: now)
        #expect(up.flatMap(\.sessions).map(\.id) == ["today-later", "in-3-days"]) // soonest first
        #expect(past.flatMap(\.sessions).map(\.id) == ["yesterday"])
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd apple && xcodegen generate && xcodebuild ... test 2>&1 | grep -iE "ScheduleModels|Headcount|error:"`
Expected: FAIL — `cannot find 'Headcount' in scope`.

- [ ] **Step 3: Write the implementation**

```swift
// apple/Sources/Features/Schedule/ScheduleModels.swift
// Pure, UI-free display logic for the Schedule tab: headcount math and the
// day-bucketing that splits sessions into up-next / upcoming / past. All
// deterministic given an injected `now`, so unit tests don't depend on the
// wall clock.
import Foundation

struct Headcount: Equatable {
    let inCount: Int
    let outCount: Int
    let maybeCount: Int
    let noReplyCount: Int

    /// "No reply" is squad members with no availability row; clamped at 0 so
    /// stray rows (e.g. an archived paddler still holding a reply) can't drive
    /// it negative.
    static func compute(availability: [Availability], squadSize: Int) -> Headcount {
        let i = availability.lazy.filter { $0.status == .in }.count
        let o = availability.lazy.filter { $0.status == .out }.count
        let m = availability.lazy.filter { $0.status == .maybe }.count
        return Headcount(inCount: i, outCount: o, maybeCount: m,
                         noReplyCount: max(0, squadSize - (i + o + m)))
    }
}

struct DaySection: Identifiable, Equatable {
    let id: Date      // start-of-day, unique per section
    let day: Date
    let sessions: [SessionRow]
}

enum ScheduleGrouping {
    /// The soonest session that hasn't started yet.
    static func upNext(_ sessions: [SessionRow], now: Date) -> SessionRow? {
        sessions.filter { $0.startsAt >= now }.min { $0.startsAt < $1.startsAt }
    }

    /// Future sessions, grouped by calendar day, soonest day first.
    static func upcoming(_ sessions: [SessionRow], now: Date) -> [DaySection] {
        group(sessions.filter { $0.startsAt >= now }.sorted { $0.startsAt < $1.startsAt })
    }

    /// Past sessions, grouped by calendar day, most-recent day first.
    static func past(_ sessions: [SessionRow], now: Date) -> [DaySection] {
        group(sessions.filter { $0.startsAt < now }.sorted { $0.startsAt > $1.startsAt })
    }

    private static func group(_ ordered: [SessionRow]) -> [DaySection] {
        var sections: [DaySection] = []
        let cal = Calendar.current
        for s in ordered {
            let day = cal.startOfDay(for: s.startsAt)
            if let last = sections.last, last.day == day {
                sections[sections.count - 1] = DaySection(id: day, day: day, sessions: last.sessions + [s])
            } else {
                sections.append(DaySection(id: day, day: day, sessions: [s]))
            }
        }
        return sections
    }
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: same, grep `ScheduleModelsTests|TEST SUCCEEDED`. Expected: 4 tests PASS.

- [ ] **Step 5: Commit**

```bash
git add apple/Sources/Features/Schedule/ScheduleModels.swift apple/Tests/PaddltirAppTests/ScheduleModelsTests.swift
git commit -m "feat(app): pure Headcount + ScheduleGrouping day-bucketing"
```

---

## Task 4: `ScheduleViewModel`

**Files:**
- Create: `apple/Sources/Features/Schedule/ScheduleViewModel.swift`
- Test: `apple/Tests/PaddltirAppTests/ScheduleViewModelTests.swift`

**Interfaces:**
- Consumes: `AppDatabase` (via `AppModel.environment.db`), `ScheduleRepository`, `SquadRepository`, `Headcount`/`ScheduleGrouping`, `Club`.
- Produces: `@MainActor @Observable final class ScheduleViewModel` with:
  - `init(db: AppDatabase, now: @escaping () -> Date = Date.init)`
  - `private(set) var upNext: SessionRow?`, `private(set) var upcoming: [DaySection]`, `private(set) var past: [DaySection]`, `private(set) var squadSize: Int`, `private(set) var clubId: String?`
  - `func load() async` (reads sessions + squad + club; recomputes the three groupings)
  - `func headcount(for sessionId: String) async -> Headcount`
  - `func createTraining(title: String, startsAt: Date, venue: String?, notes: String?) async` / `func createRaceDay(...)` (both call the repo then `load()`)

- [ ] **Step 1: Write the failing test**

```swift
// apple/Tests/PaddltirAppTests/ScheduleViewModelTests.swift
import Foundation
import GRDB
import Testing
@testable import Paddltir

@MainActor @Suite struct ScheduleViewModelTests {
    private let now = Date(timeIntervalSince1970: 1_700_000_000)

    private func seed(_ appDB: AppDatabase) throws {
        try appDB.write { db in
            try Club(id: "club-1", name: "C", inviteCode: "ABCD2345", createdBy: nil, createdAt: now, updatedAt: nil).insert(db)
            try SessionRow(id: "past", clubId: "club-1", kind: .training, title: "Past", startsAt: now.addingTimeInterval(-86_400), venue: nil, notes: nil, createdAt: now, updatedAt: nil).insert(db)
            try SessionRow(id: "soon", clubId: "club-1", kind: .training, title: "Soon", startsAt: now.addingTimeInterval(3600), venue: nil, notes: nil, createdAt: now, updatedAt: nil).insert(db)
        }
    }

    @Test func loadComposesGroupingsAndClub() async throws {
        let appDB = try AppDatabase.inMemory()
        try seed(appDB)
        let vm = ScheduleViewModel(db: appDB, now: { self.now })
        await vm.load()
        #expect(vm.clubId == "club-1")
        #expect(vm.upNext?.id == "soon")
        #expect(vm.upcoming.flatMap(\.sessions).map(\.id) == ["soon"])
        #expect(vm.past.flatMap(\.sessions).map(\.id) == ["past"])
    }

    @Test func createTrainingWritesThenReloads() async throws {
        let appDB = try AppDatabase.inMemory()
        try seed(appDB)
        let vm = ScheduleViewModel(db: appDB, now: { self.now })
        await vm.load()
        await vm.createTraining(title: "New paddle", startsAt: now.addingTimeInterval(7200), venue: "Bay", notes: nil)
        #expect(vm.upcoming.flatMap(\.sessions).contains { $0.title == "New paddle" })
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd apple && xcodegen generate && xcodebuild ... test 2>&1 | grep -iE "ScheduleViewModel|error:"`
Expected: FAIL — `cannot find 'ScheduleViewModel'`.

- [ ] **Step 3: Write the implementation**

```swift
// apple/Sources/Features/Schedule/ScheduleViewModel.swift
// Loads + composes the Schedule tab's state from the repositories and the
// pure ScheduleGrouping/Headcount helpers. @MainActor so the @Observable
// state mutates on the main actor for SwiftUI. `now` is injected so tests are
// deterministic; production uses `Date.init`.
import Foundation
import GRDB

@MainActor @Observable
final class ScheduleViewModel {
    private(set) var upNext: SessionRow?
    private(set) var upcoming: [DaySection] = []
    private(set) var past: [DaySection] = []
    private(set) var squadSize = 0
    private(set) var clubId: String?
    private(set) var isLoading = false

    private let schedule: ScheduleRepository
    private let squad: SquadRepository
    private let db: AppDatabase
    private let now: () -> Date

    init(db: AppDatabase, now: @escaping () -> Date = Date.init) {
        self.db = db
        self.schedule = ScheduleRepository(db: db)
        self.squad = SquadRepository(db: db)
        self.now = now
    }

    func load() async {
        isLoading = true
        defer { isLoading = false }
        do {
            let sessions = try await schedule.sessions()
            let paddlers = try await squad.paddlers()
            clubId = try db.read { db in try Club.fetchOne(db)?.id }
            squadSize = paddlers.count
            let n = now()
            upNext = ScheduleGrouping.upNext(sessions, now: n)
            upcoming = ScheduleGrouping.upcoming(sessions, now: n)
            past = ScheduleGrouping.past(sessions, now: n)
        } catch { /* offline-first: a read failure leaves the last good state */ }
    }

    func headcount(for sessionId: String) async -> Headcount {
        let availability = (try? await schedule.session(id: sessionId))?.availability ?? []
        return Headcount.compute(availability: availability, squadSize: squadSize)
    }

    func createTraining(title: String, startsAt: Date, venue: String?, notes: String?) async {
        await create(kind: .training, title: title, startsAt: startsAt, venue: venue, notes: notes)
    }

    func createRaceDay(title: String, startsAt: Date, venue: String?, notes: String?) async {
        await create(kind: .raceDay, title: title, startsAt: startsAt, venue: venue, notes: notes)
    }

    private func create(kind: SessionKind, title: String, startsAt: Date, venue: String?, notes: String?) async {
        guard let clubId else { return }
        _ = try? await schedule.createSession(clubId: clubId, kind: kind, title: title, startsAt: startsAt, venue: venue, notes: notes)
        await load()
    }
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: same, grep `ScheduleViewModelTests|TEST SUCCEEDED`. Expected: 2 tests PASS.

- [ ] **Step 5: Commit**

```bash
git add apple/Sources/Features/Schedule/ScheduleViewModel.swift apple/Tests/PaddltirAppTests/ScheduleViewModelTests.swift
git commit -m "feat(app): ScheduleViewModel composes repos + grouping"
```

---

## Task 5: `ScheduleView` tab + wire into the shell

**Files:**
- Create: `apple/Sources/Features/Schedule/ScheduleView.swift`
- Modify: `apple/Sources/App/RootView.swift`
- Delete: `apple/Sources/Features/SchedulePlaceholder.swift`

**Interfaces:**
- Consumes: `AppModel` (via `@Environment`), `ScheduleViewModel`, DS components, `SessionFormView` (Task 6), `TrainingDetailView` (Task 7), `RaceDayDetailView` (Task 8).
- Produces: `struct ScheduleView: View` (owns a `NavigationStack` + `ScheduleViewModel`).

- [ ] **Step 1: Write `ScheduleView`**

```swift
// apple/Sources/Features/Schedule/ScheduleView.swift
// The Schedule tab: an "Up next" glass hero over day-grouped upcoming
// sections, with past sessions collapsed. `+` creates a training or race-day
// session. Tapping a session pushes its detail (training vs race-day).
import SwiftUI

struct ScheduleView: View {
    @Environment(AppModel.self) private var app
    @State private var model: ScheduleViewModel?
    @State private var newSessionKind: SessionKind?

    var body: some View {
        NavigationStack {
            Group {
                if let model { content(model) } else { ProgressView() }
            }
            .navigationTitle("Schedule")
            .background(DS.bg)
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Menu {
                        Button("Training session") { newSessionKind = .training }
                        Button("Race day") { newSessionKind = .raceDay }
                    } label: { Image(systemName: "plus") }
                }
            }
            .sheet(item: $newSessionKind) { kind in
                SessionFormView(kind: kind) { title, startsAt, venue, notes in
                    if kind == .training { await model?.createTraining(title: title, startsAt: startsAt, venue: venue, notes: notes) }
                    else { await model?.createRaceDay(title: title, startsAt: startsAt, venue: venue, notes: notes) }
                }
            }
            .navigationDestination(for: SessionRow.self) { session in
                if session.kind == .training { TrainingDetailView(session: session) }
                else { RaceDayDetailView(session: session) }
            }
        }
        .task {
            if model == nil { model = ScheduleViewModel(db: app.environment.db) }
            await model?.load()
        }
    }

    @ViewBuilder private func content(_ model: ScheduleViewModel) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DS.Space.l) {
                if let up = model.upNext { upNextHero(up, model: model) }
                ForEach(model.upcoming) { section in
                    daySection(section, header: DateFormatting.day(section.day), model: model)
                }
                if !model.past.isEmpty {
                    DisclosureGroup("Past") {
                        ForEach(model.past) { section in
                            daySection(section, header: DateFormatting.day(section.day), model: model)
                        }
                    }
                    .font(.dsSubhead).foregroundStyle(DS.ink2).padding(.top, DS.Space.m)
                }
            }
            .padding(DS.Space.l)
        }
    }

    private func upNextHero(_ session: SessionRow, model: ScheduleViewModel) -> some View {
        NavigationLink(value: session) {
            GlassContainer {
                VStack(alignment: .leading, spacing: DS.Space.s) {
                    MicroLabel("UP NEXT")
                    Text(session.title).font(.dsTitle).foregroundStyle(DS.ink)
                    HStack(spacing: DS.Space.s) {
                        if let venue = session.venue { Label(venue, systemImage: "mappin.and.ellipse").font(.dsCaption).foregroundStyle(DS.ink2) }
                        Text(DateFormatting.relative(session.startsAt)).font(.dsCaption).foregroundStyle(DS.accent)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(DS.Space.m)
            }
        }
        .buttonStyle(.plain)
    }

    private func daySection(_ section: DaySection, header: String, model: ScheduleViewModel) -> some View {
        VStack(alignment: .leading, spacing: DS.Space.s) {
            MicroLabel(header.uppercased())
            ForEach(section.sessions, id: \.id) { session in
                NavigationLink(value: session) {
                    HairlineCard {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(session.title).font(.dsHeadline).foregroundStyle(DS.ink)
                                Text(session.kind == .training ? "Training" : "Race day")
                                    .font(.dsCaption).foregroundStyle(DS.ink3)
                            }
                            Spacer()
                            Image(systemName: "chevron.right").foregroundStyle(DS.ink3)
                        }
                    }
                }
                .buttonStyle(.plain)
            }
        }
    }
}

/// Small date helpers local to the Schedule feature.
enum DateFormatting {
    static func day(_ date: Date) -> String {
        date.formatted(.dateTime.weekday(.wide).month().day())
    }
    static func relative(_ date: Date) -> String {
        date.formatted(.relative(presentation: .named))
    }
}
```

Note: `SessionKind` must be `Identifiable` for `.sheet(item:)` — add `extension SessionKind: Identifiable { var id: String { rawValue } }` in this file if the enum isn't already Identifiable (check `Enums.swift`; if adding, keep it in the app layer, not the Data model file, to avoid touching the shared enum — actually add it as a small `extension` in ScheduleView.swift). `SessionRow` is `Hashable` already, so `navigationDestination(for: SessionRow.self)` + `NavigationLink(value:)` work.

- [ ] **Step 2: Wire into the shell + delete the placeholder**

In `apple/Sources/App/RootView.swift`, replace `SchedulePlaceholder()` with `ScheduleView()` at BOTH sites: the iOS `TabView` (tag 0) and the macOS `macDetail` `.schedule` arm. Then delete `apple/Sources/Features/SchedulePlaceholder.swift`.

- [ ] **Step 3: Build + verify**

Run the iOS build gate + `xcodebuild ... -destination 'platform=macOS' build`. Expected: green, no warnings, `grep -rn SchedulePlaceholder apple/Sources` returns nothing.

- [ ] **Step 4: Commit**

```bash
git add apple/Sources/Features/Schedule/ScheduleView.swift apple/Sources/App/RootView.swift
git rm apple/Sources/Features/SchedulePlaceholder.swift
git commit -m "feat(app): Schedule tab — up-next hero, day sections, create menu"
```

---

## Task 6: `SessionFormView` (create training / race day)

**Files:**
- Create: `apple/Sources/Features/Schedule/SessionFormView.swift`

**Interfaces:**
- Produces: `struct SessionFormView: View` with `init(kind: SessionKind, onCreate: @escaping (_ title: String, _ startsAt: Date, _ venue: String?, _ notes: String?) async -> Void)`.

- [ ] **Step 1: Write the view**

```swift
// apple/Sources/Features/Schedule/SessionFormView.swift
// Modal form to create a training or race-day session. Presented from the
// Schedule tab's `+` menu; hands the entered fields back through `onCreate`
// (the caller's ScheduleViewModel does the write), then dismisses.
import SwiftUI

struct SessionFormView: View {
    let kind: SessionKind
    let onCreate: (_ title: String, _ startsAt: Date, _ venue: String?, _ notes: String?) async -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var title = ""
    @State private var startsAt = Date()
    @State private var venue = ""
    @State private var notes = ""
    @State private var isSaving = false

    private var canSave: Bool { !title.trimmingCharacters(in: .whitespaces).isEmpty && !isSaving }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField(kind == .training ? "Tuesday paddle" : "Regatta day", text: $title)
                    DatePicker("Starts", selection: $startsAt)
                    TextField("Venue", text: $venue)
                } header: { MicroLabel(kind == .training ? "TRAINING SESSION" : "RACE DAY") }
                Section { TextField("Notes", text: $notes, axis: .vertical) } header: { MicroLabel("NOTES") }
            }
            .navigationTitle(kind == .training ? "New training" : "New race day")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") {
                        Task {
                            isSaving = true
                            await onCreate(title.trimmingCharacters(in: .whitespaces), startsAt,
                                           venue.isEmpty ? nil : venue, notes.isEmpty ? nil : notes)
                            dismiss()
                        }
                    }
                    .disabled(!canSave)
                }
            }
        }
    }
}
```

- [ ] **Step 2: Build + verify**

Run the iOS build gate + macOS build. Expected: green. (`ScheduleView`'s `.sheet` now resolves.)

- [ ] **Step 3: Commit**

```bash
git add apple/Sources/Features/Schedule/SessionFormView.swift
git commit -m "feat(app): SessionFormView — create training / race-day session"
```

---

## Task 7: `TrainingDetailView` (availability + coach override + record-erg)

**Files:**
- Create: `apple/Sources/Features/Schedule/TrainingDetailView.swift`

**Interfaces:**
- Consumes: `AppModel`, `ScheduleRepository`, `SquadRepository`, `PaddlerWithErg`, `Headcount`, DS components.
- Produces: `struct TrainingDetailView: View` with `init(session: SessionRow)`; an internal `@MainActor @Observable TrainingDetailModel` loading the squad + availability and doing overrides/erg writes.

- [ ] **Step 1: Write the view + model**

```swift
// apple/Sources/Features/Schedule/TrainingDetailView.swift
// Training-session detail: a headcount summary, then every squad paddler with
// their availability (In/Out/Maybe or "No reply"). The coach overrides a
// paddler's status inline (writes availability), and a per-paddler menu opens
// a record-erg sheet.
import SwiftUI

@MainActor @Observable
final class TrainingDetailModel {
    let session: SessionRow
    private(set) var paddlers: [PaddlerWithErg] = []
    private(set) var availability: [String: Availability] = [:]   // paddlerId -> row
    private let schedule: ScheduleRepository
    private let squad: SquadRepository

    init(session: SessionRow, db: AppDatabase) {
        self.session = session
        self.schedule = ScheduleRepository(db: db)
        self.squad = SquadRepository(db: db)
    }

    var headcount: Headcount { Headcount.compute(availability: Array(availability.values), squadSize: paddlers.count) }

    func load() async {
        paddlers = (try? await squad.paddlers()) ?? []
        let rows = (try? await schedule.session(id: session.id))?.availability ?? []
        availability = Dictionary(uniqueKeysWithValues: rows.map { ($0.paddlerId, $0) })
    }

    func setStatus(_ status: AvailabilityStatus, for paddlerId: String) async {
        try? await schedule.setAvailability(sessionId: session.id, paddlerId: paddlerId, status: status,
                                            note: availability[paddlerId]?.note)
        await load()
    }

    func recordErg(paddlerId: String, metres: Int) async {
        _ = try? await squad.recordErg(paddlerId: paddlerId, metres: metres, testedAt: Date(), recordedBy: nil)
        await load()
    }
}

struct TrainingDetailView: View {
    let session: SessionRow
    @Environment(AppModel.self) private var app
    @State private var model: TrainingDetailModel?
    @State private var ergTarget: PaddlerWithErg?

    var body: some View {
        Group {
            if let model { content(model) } else { ProgressView() }
        }
        .navigationTitle(session.title)
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .background(DS.bg)
        .task {
            if model == nil { model = TrainingDetailModel(session: session, db: app.environment.db) }
            await model?.load()
        }
        .sheet(item: $ergTarget) { target in
            RecordErgSheet(paddlerName: target.row.name) { metres in
                await model?.recordErg(paddlerId: target.row.id, metres: metres)
            }
        }
    }

    @ViewBuilder private func content(_ model: TrainingDetailModel) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DS.Space.m) {
                headcountCard(model.headcount)
                ForEach(model.paddlers, id: \.row.id) { p in
                    availabilityRow(p, status: model.availability[p.row.id]?.status, model: model)
                }
            }
            .padding(DS.Space.l)
        }
    }

    private func headcountCard(_ h: Headcount) -> some View {
        HairlineCard {
            HStack(spacing: DS.Space.l) {
                AvailabilityRing(count: h.inCount, total: max(1, h.inCount + h.outCount + h.maybeCount + h.noReplyCount))
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(h.inCount) in · \(h.outCount) out · \(h.maybeCount) maybe").font(.dsHeadline).foregroundStyle(DS.ink)
                    Text("\(h.noReplyCount) no reply").font(.dsCaption).foregroundStyle(DS.ink3)
                }
                Spacer()
            }
        }
    }

    private func availabilityRow(_ p: PaddlerWithErg, status: AvailabilityStatus?, model: TrainingDetailModel) -> some View {
        HairlineCard {
            HStack {
                Text(p.row.name).font(.dsBody).foregroundStyle(DS.ink)
                Spacer()
                ForEach([AvailabilityStatus.in, .maybe, .out], id: \.self) { s in
                    Button {
                        Task { await model.setStatus(s, for: p.row.id) }
                    } label: {
                        Text(label(s))
                            .font(.dsCaption)
                            .padding(.horizontal, DS.Space.s).padding(.vertical, DS.Space.xs)
                            .background(status == s ? tint(s).opacity(0.18) : DS.surface2, in: Capsule())
                            .foregroundStyle(status == s ? tint(s) : DS.ink3)
                    }
                    .buttonStyle(.plain)
                }
                Menu {
                    Button("Record erg test…") { ergTarget = p }
                } label: { Image(systemName: "ellipsis.circle").foregroundStyle(DS.ink3) }
            }
        }
    }

    private func label(_ s: AvailabilityStatus) -> String { s == .in ? "In" : s == .out ? "Out" : "Maybe" }
    private func tint(_ s: AvailabilityStatus) -> Color { s == .in ? DS.good : s == .out ? DS.danger : DS.accent }
}

/// Compact erg-entry sheet.
struct RecordErgSheet: View {
    let paddlerName: String
    let onSave: (_ metres: Int) async -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var metresText = ""

    var body: some View {
        NavigationStack {
            Form {
                Section { TextField("Metres in 2 min", text: $metresText)
                    #if os(iOS)
                    .keyboardType(.numberPad)
                    #endif
                } header: { MicroLabel("ERG — \(paddlerName.uppercased())") }
            }
            .navigationTitle("Record erg")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        Task { if let m = Int(metresText) { await onSave(m) }; dismiss() }
                    }
                    .disabled(Int(metresText) == nil)
                }
            }
        }
    }
}
```

Note: `PaddlerWithErg` must be `Identifiable` for `.sheet(item:)` — it's `Hashable, Sendable`; add `extension PaddlerWithErg: Identifiable { var id: String { row.id } }` in this file if it isn't already Identifiable (check `PaddlerWithErg.swift`).

- [ ] **Step 2: Build + verify**

Run the iOS build gate + macOS build. Expected: green.

- [ ] **Step 3: Commit**

```bash
git add apple/Sources/Features/Schedule/TrainingDetailView.swift
git commit -m "feat(app): TrainingDetailView — availability, coach override, record erg"
```

---

## Task 8: `RaceDayDetailView` (races + day headcount + add race)

**Files:**
- Create: `apple/Sources/Features/Schedule/RaceDayDetailView.swift`

**Interfaces:**
- Consumes: `AppModel`, `ScheduleRepository`, `CrewRepository`, `Headcount`, DS components.
- Produces: `struct RaceDayDetailView: View` with `init(session: SessionRow)`; an internal `@MainActor @Observable RaceDayModel`; a `RaceFormView` (pick crew + boat size + distance); a `LineupEditorPlaceholder` nav stub (real editor is Plan 4f).

- [ ] **Step 1: Write the view + model + race form + lineup stub**

```swift
// apple/Sources/Features/Schedule/RaceDayDetailView.swift
// Race-day detail: the day's headcount summary, the list of races (crew ·
// boat size · distance), and `+ Race`. Tapping a race navigates toward the
// lineup editor (a placeholder until Plan 4f builds it).
import SwiftUI

@MainActor @Observable
final class RaceDayModel {
    let session: SessionRow
    private(set) var races: [Race] = []
    private(set) var crewNames: [String: String] = [:]   // crewId -> name
    private(set) var headcount = Headcount(inCount: 0, outCount: 0, maybeCount: 0, noReplyCount: 0)
    private let schedule: ScheduleRepository
    private let crews: CrewRepository
    private let squad: SquadRepository

    init(session: SessionRow, db: AppDatabase) {
        self.session = session
        self.schedule = ScheduleRepository(db: db)
        self.crews = CrewRepository(db: db)
        self.squad = SquadRepository(db: db)
    }

    var allCrews: [Crew] { _allCrews }
    private var _allCrews: [Crew] = []

    func load() async {
        races = (try? await schedule.races(sessionId: session.id)) ?? []
        _allCrews = (try? await crews.crews()) ?? []
        crewNames = Dictionary(uniqueKeysWithValues: _allCrews.map { ($0.id, $0.name) })
        let availability = (try? await schedule.session(id: session.id))?.availability ?? []
        let squadSize = ((try? await squad.paddlers()) ?? []).count
        headcount = Headcount.compute(availability: availability, squadSize: squadSize)
    }

    func addRace(crewId: String, name: String, boatSize: BoatSize, distanceM: Int?) async {
        _ = try? await schedule.createRace(sessionId: session.id, crewId: crewId, name: name, boatSize: boatSize, distanceM: distanceM)
        await load()
    }
}

struct RaceDayDetailView: View {
    let session: SessionRow
    @Environment(AppModel.self) private var app
    @State private var model: RaceDayModel?
    @State private var addingRace = false

    var body: some View {
        Group {
            if let model { content(model) } else { ProgressView() }
        }
        .navigationTitle(session.title)
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .background(DS.bg)
        .toolbar {
            ToolbarItem(placement: .primaryAction) { Button { addingRace = true } label: { Image(systemName: "plus") } }
        }
        .sheet(isPresented: $addingRace) {
            if let model { RaceFormView(crews: model.allCrews) { crewId, name, size, dist in
                await model.addRace(crewId: crewId, name: name, boatSize: size, distanceM: dist)
            } }
        }
        .navigationDestination(for: Race.self) { race in LineupEditorPlaceholder(race: race) }
        .task {
            if model == nil { model = RaceDayModel(session: session, db: app.environment.db) }
            await model?.load()
        }
    }

    @ViewBuilder private func content(_ model: RaceDayModel) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DS.Space.m) {
                HairlineCard {
                    Text("\(model.headcount.inCount) in · \(model.headcount.outCount) out · \(model.headcount.maybeCount) maybe · \(model.headcount.noReplyCount) no reply")
                        .font(.dsCallout).foregroundStyle(DS.ink2)
                }
                MicroLabel("RACES")
                if model.races.isEmpty {
                    Text("No races yet — tap + to add one.").font(.dsCaption).foregroundStyle(DS.ink3)
                }
                ForEach(model.races, id: \.id) { race in
                    NavigationLink(value: race) {
                        HairlineCard {
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(race.name).font(.dsHeadline).foregroundStyle(DS.ink)
                                    Text("\(model.crewNames[race.crewId] ?? "Crew") · \(race.boatSize == .standard ? "Standard" : "Small")\(race.distanceM.map { " · \($0)m" } ?? "")")
                                        .font(.dsCaption).foregroundStyle(DS.ink3)
                                }
                                Spacer()
                                Image(systemName: "chevron.right").foregroundStyle(DS.ink3)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(DS.Space.l)
        }
    }
}

/// Add-race form: pick a crew, boat size, optional distance.
struct RaceFormView: View {
    let crews: [Crew]
    let onCreate: (_ crewId: String, _ name: String, _ boatSize: BoatSize, _ distanceM: Int?) async -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var crewId = ""
    @State private var boatSize: BoatSize = .standard
    @State private var distanceText = ""

    var body: some View {
        NavigationStack {
            Form {
                TextField("Race name (e.g. Heat A)", text: $name)
                Picker("Crew", selection: $crewId) {
                    Text("Select…").tag("")
                    ForEach(crews, id: \.id) { Text($0.name).tag($0.id) }
                }
                Picker("Boat size", selection: $boatSize) {
                    Text("Standard").tag(BoatSize.standard); Text("Small").tag(BoatSize.small)
                }
                TextField("Distance (m)", text: $distanceText)
                    #if os(iOS)
                    .keyboardType(.numberPad)
                    #endif
            }
            .navigationTitle("Add race")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        Task { await onCreate(crewId, name.trimmingCharacters(in: .whitespaces), boatSize, Int(distanceText)); dismiss() }
                    }
                    .disabled(crewId.isEmpty || name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }
}

/// Stands in for the Plan 4f lineup editor so a race is tappable now.
struct LineupEditorPlaceholder: View {
    let race: Race
    var body: some View {
        ScreenScaffold("Lineup", note: "\(race.name) — the lineup editor arrives in Plan 4f.")
    }
}
```

Note: `Race` is `Hashable` already (for `navigationDestination(for: Race.self)`). Verify `Crew` has `id`/`name` (it does — `Crew` row model).

- [ ] **Step 2: Build + verify**

Run the iOS build gate + macOS build. Expected: green.

- [ ] **Step 3: Commit**

```bash
git add apple/Sources/Features/Schedule/RaceDayDetailView.swift
git commit -m "feat(app): RaceDayDetailView — races, day headcount, add race"
```

---

## Task 9: Integration, DEBUG screenshot harness & verification

**Files:**
- Modify: `apple/Sources/App/SessionController.swift` (a DEBUG-only auto-sign-in launch hook, for screenshots)

- [ ] **Step 1: DEBUG auto-sign-in hook** (so a launched build can screenshot signed-in screens)

In `SessionController.start()`, before the `authStateChanges` loop, add a DEBUG-only fast path: if `ProcessInfo.processInfo.environment["PADDLTIR_DEBUG_AUTOSIGNIN"] == "1"` and there is no current session, sign in as the local dev coach so a `simctl` launch lands inside the app. Keep it strictly `#if DEBUG`:

```swift
    func start() async {
        #if DEBUG
        if ProcessInfo.processInfo.environment["PADDLTIR_DEBUG_AUTOSIGNIN"] == "1" {
            if (try? await client.auth.session) == nil {
                try? await client.auth.signIn(email: "coach@paddltir.dev", password: "password123")
                await refreshClub()
            }
        }
        #endif
        for await (_, session) in client.auth.authStateChanges {
            await resolve(session: session)
        }
    }
```

- [ ] **Step 2: Full build gate (iOS + macOS), whole suite green**

```bash
cd apple && xcodegen generate
xcodebuild -scheme Paddltir -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -derivedDataPath DerivedData test 2>&1 | grep -iE "Test run with .* tests|skipped|TEST SUCCEEDED|error:"
xcodebuild -scheme Paddltir -destination 'platform=macOS' build 2>&1 | tail -3
```
Expected: all Schedule unit tests present and passing (repo writes, recordErg, ScheduleModels, ScheduleViewModel), gated live tests still **skipped**, zero Swift warnings, macOS builds.

- [ ] **Step 3: Capture the Schedule screenshot** (controller, with the local stack up + seed loaded)

```bash
DEV="iPhone 17 Pro"
APP=".../DerivedData/Build/Products/Debug-iphonesimulator/Paddltir.app"
xcrun simctl boot "$DEV" 2>/dev/null; xcrun simctl bootstatus "$DEV"
xcrun simctl install "$DEV" "$APP"
SIMCTL_CHILD_PADDLTIR_DEBUG_AUTOSIGNIN=1 xcrun simctl launch "$DEV" app.paddltir.Paddltir
sleep 8
xcrun simctl io "$DEV" screenshot apple/screenshots/4d-schedule.png
```
Surface `apple/screenshots/4d-schedule.png` to Jun. (Detail views need in-sim taps to reach; verify those by build + the unit tests. If the seed has no sessions, the shot shows the empty Schedule — still valid.)

- [ ] **Step 4: Update PROGRESS.md + roadmap** (post-merge, on main — mark 4d merged, list any deferred minors).

- [ ] **Step 5: Commit**

```bash
git add apple/Sources/App/SessionController.swift
git commit -m "chore(app): DEBUG auto-sign-in launch hook for screenshots"
```

---

## Self-Review

**Spec coverage (§3 Schedule):**
- Timeline grouped by day, upcoming + past (collapsed) → Tasks 3+5. ✓
- Up-next hero (kind, venue, countdown) → Task 5 (`upNextHero`, relative time). ✓ (Headcount on the hero itself is derivable via `model.headcount(for:)`; the hero shows title/venue/time — per-session headcount lives on the detail; acceptable, note if Jun wants it on the hero.)
- `+` → Training | Race day → Tasks 5+6. ✓
- Training detail: availability In/Out/Maybe/No-reply + notes, coach override, record-erg → Task 7. ✓ (Per-paddler note editing is read-through only in v1 — the override preserves an existing note; free-text note editing deferred, flag in review.)
- Race-day detail: races (crew · boat size · distance), day availability summary, `+ Race`, tap → lineup → Task 8 (lineup is a placeholder until 4f). ✓
- Offline-first writes via outbox → Tasks 1+2. ✓

**Placeholder scan:** no "TBD"/"handle errors"/"similar to". The `LineupEditorPlaceholder` is an intentional, labelled nav stub (Plan 4f owns the real editor), not a plan placeholder. Two explicit "add `Identifiable`/`Identifiable` conformance if absent" notes are lookups against shipped files, not gaps.

**Type consistency:** `ScheduleViewModel`/`Headcount`/`DaySection`/`ScheduleGrouping` names match across Tasks 3–5. Repository method signatures match between Task 1/2 definitions and Tasks 4/7/8 call sites (`createSession`, `setAvailability`, `createRace`, `recordErg`). `SessionRow`/`Race` `Hashable` used for `navigationDestination`. `AppModel.environment.db` used consistently.

**Known deferrals (flag at merge):** per-session headcount on the up-next hero; free-text availability note editing; wiring `recordedBy` to the current coach's id; the deferred-polish carried from 4c (`.dsMono` token, muted-grey placeholder). None block the increment.

## Execution Handoff

**Plan complete and saved to `docs/superpowers/plans/2026-08-25-plan-4d-schedule.md`.** Executing via subagent-driven-development (the project's established mode): fresh implementer per task, task review after each, final whole-branch review before merge.

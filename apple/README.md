# Paddltir (Apple)

SwiftUI app foundation — config, manage, and get insights into your dragon
boat crew. Links `PaddltirCore` and ships the app's design system plus a
DEBUG-only gallery tab for reviewing it.

**Prerequisites:** Xcode 26 (tested 26.1), [XcodeGen](https://github.com/yonaskolb/XcodeGen) (`brew install xcodegen`).

**First-time setup:** copy `Sources/Data/App/Secrets.example.swift` to
`Sources/App/Secrets.swift` (git-ignored) and fill in the Supabase URL + anon
key — the app won't compile without it. See that template's header for the
local-dev values printed by `supabase status`.

**Build:** `cd apple && xcodegen generate`, then open `Paddltir.xcodeproj`
and run the `Paddltir` scheme, or `xcodebuild -scheme Paddltir -destination
'platform=iOS Simulator,name=iPhone 17 Pro' build`. `.xcodeproj`/`DerivedData/`
are gitignored — always regenerate after pulling.

**Tests:** same command with `test` instead of `build`.

**Gallery screenshot:** DEBUG builds default-select the "Design" tab. Boot a
simulator, install/launch the app, then `xcrun simctl io booted screenshot
apple/screenshots/gallery.png`.

**Fonts:** Inter Tight is bundled under `Sources/Resources/Fonts/`
(OFL-licensed, see `OFL.txt`) and registered at launch.

**Build status:** iOS Simulator builds, tests pass, 0 compiler warnings.
macOS compiles successfully (signing disabled via `CODE_SIGNING_REQUIRED=NO`);
not run/verified beyond compiling.

## Data layer

Offline-first: the app reads and writes a local GRDB/SQLite cache
(`Sources/Data/Local/AppDatabase.swift`), never Supabase directly, and a
background `SyncEngine` (`Sources/Data/Sync/SyncEngine.swift`) reconciles
that cache with Postgres/PostgREST over `Sources/Data/Remote/SupabaseRemote.swift`.
Every table in `supabase/migrations/20260822000100_types_tables.sql` has a
Codable row model in `Sources/Data/Models/Rows.swift`, decoded/encoded via
`PostgREST.decoder`/`.encoder` (`Sources/Data/Models/PostgRESTCoding.swift`)
on the wire and mirrored into GRDB via the `SnakeCaseRecord` conformances in
`Sources/Data/Local/Records.swift`.

**Sync model** (see `SyncEngine.swift`'s header for the full rationale):
`syncAll()` pulls each table's rows changed since its last sync, skips any
row whose primary key has a pending local edit (**outbox entries win until
pushed**), then drains the outbox — pushing every queued local write and
deleting its entry once the push succeeds. There is no server-authoritative
merge beyond that: it is deliberately simple, single-club, last-write-wins.

**Repositories** (`Sources/Data/Repositories/`) are the only data-layer API
the feature screens are meant to call — never `AppDatabase`, `Outbox`, or
`DomainMapping` directly:

- `SquadRepository` — `paddlers()`/`paddler(id:)` (non-archived, joined to
  each paddler's latest erg test via `PaddlerWithErg`, the local
  `paddlers_with_power` equivalent), `upsert(_:)`, `archive(id:)`.
- `CrewRepository` — `crews()`, `crew(id:)` (crew + members as
  `[PaddlerWithErg]`), `setMembers(crewId:paddlerIds:)`.
- `ScheduleRepository` — `upcomingSessions()`, `session(id:)` (session +
  availability), `races(sessionId:)`. Read-only for now.
- `LineupRepository` — `heat(id:)` (heat + seats + reserves),
  `saveSeats(heatId:seats:)`, and `placementRequest(heatId:)`, which walks
  heat → race → crew → crew members/ergs, the race's category rule, and the
  heat's current seats/drummer/sweep into a `PaddltirCore.PlacementRequest`
  — everything the lineup editor's Auto-fill/Suggest action
  (`PaddltirCore.Greedy.autoFill`) needs.

All reads go straight to GRDB (`AppDatabase.read`); every write commits its
GRDB change and an `Outbox.enqueue(...)` call in the *same*
`AppDatabase.write` transaction, so a local edit and its sync record either
both land or neither does. Repositories take an `AppDatabase` in their
initializer (dependency injection — tests, previews, and the app target each
construct their own: `.inMemory()` or `.onDisk()`), and are plain
`Sendable` structs with `async throws` methods, not actors — every method
body is a single synchronous `db.read`/`db.write` call, so there's no
internal mutable state to isolate.

**Running the live-Supabase test:** `Tests/PaddltirAppTests/SupabaseRemoteTests.swift`
exercises `SupabaseRemote` against a real local Supabase stack instead of a
fake, and is skipped by default. To run it:

```sh
supabase start                      # needs Docker/OrbStack
supabase db reset                   # applies migrations + supabase/seed.sql
psql "$DB_URL" -f supabase/seed_dev.sql   # demo coach account + bulk rows
cd apple && TEST_RUNNER_PADDLTIR_LIVE_SUPABASE=1 xcodebuild -scheme Paddltir \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -derivedDataPath DerivedData test
```

Note the `TEST_RUNNER_` prefix — `xcodebuild test` runs the test host in the
Simulator, which only inherits environment variables under that prefix (see
the test file's header for how this was confirmed). A plain
`PADDLTIR_LIVE_SUPABASE=1 xcodebuild ... test` leaves the test skipped.

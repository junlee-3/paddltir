# Plan 4 — Coach App (SwiftUI) Roadmap

> The flagship: a premium SwiftUI app for iOS 26 + macOS 26. Executed as sub-plans in sequence;
> each ends in a **buildable, screenshot-verifiable increment**. Re-read `PROGRESS.md` and
> `docs/design/direction.md` after any compaction.

**Spec:** `docs/superpowers/specs/2026-08-22-paddltir-design.md` (§3 coach app).
**Visual direction (APPROVED):** `docs/design/direction.md` — enhanced CrewCoach: slate-on-white,
hairline borders, green=Male/amber=Female tiles + emerald/red verdicts kept; teal `#0D7377` accent;
**Inter Tight sans throughout**; **light mode only (v1)**; native Liquid Glass on floating chrome; 8px geometry.
**Concept:** `docs/design/concepts/coach-app-concepts.html`.

## Locked build decisions
- **Project generation: XcodeGen** (installed) — the project is a checked-in `apple/project.yml`
  (+ generated `.xcodeproj`, git-ignored). Reproducible, diffable, no giant pbxproj churn.
- **One app target, two platforms:** iOS 26 + macOS 26 (SwiftUI multiplatform, `supportedDestinations`).
- **Local dependency:** `packages/PaddltirCore` (already built) via a local SPM package reference.
- **Font:** bundle **Inter Tight** variable TTF (Google Fonts OFL) in the app; SF Pro is the fallback.
- **Verification:** every sub-plan builds via `xcodebuild -scheme Paddltir -destination 'platform=iOS Simulator,name=iPhone 17 Pro'`
  and, for UI, boots the sim and captures a screenshot (`xcrun simctl … io … screenshot`). Screenshots
  saved under `apple/screenshots/` (git-ignored) and surfaced to Jun.
- **Colors are light-only now** but declared as asset-catalog colour sets so a dark set drops in later.

## Sub-plans (write + execute in order)
- [x] **4a — Foundation (MERGED ac2b8ea)** `2026-08-25-plan-4a-foundation.md`
      XcodeGen project (iOS+macOS), PaddltirCore linked, Inter Tight bundled, colour asset catalog from
      tokens, type scale + spacing, core reusable components (MicroLabel, GlassCard/Toolbar, PrimaryButton,
      SeatTile, TelemetryGrid, Pill), a **Design System gallery** screen. Verify: builds + screenshot.
- [x] **4b — Data layer & sync (MERGED a7e83d2)** `2026-08-25-plan-4b-data.md`
      Swift row models mirroring the schema; GRDB local store + migrations; Supabase client (supabase-swift)
      for Auth/PostgREST/Realtime; repositories; pull-on-foreground / outbox-push / last-write-wins sync;
      an offline-first cache. 59 tests. Final review + 3 cross-cutting fixes (delete-routing, deterministic
      drain order, clubID cache-on-success). **First-time setup:** copy `Sources/Data/App/Secrets.example.swift`
      → `Sources/App/Secrets.swift` (git-ignored) or the app won't compile.
- [x] **4c — Auth & onboarding (MERGED cd2579b)** `2026-08-25-plan-4c-auth.md`
      3-state `AuthState` gate over RootView (`SessionController`); `ClubService` wraps create_club/join_club/
      claimable_paddlers/regenerate_invite_code; `AppModel` shares one SupabaseClient; AuthView (SIWA + magic
      link + DEBUG dev sign-in), OnboardingView (create/join+claim), SettingsView (invite code/share/regen,
      rules, sign out). 66 tests + gated live onboarding e2e (verified PASS vs local stack). **SIWA + magic-link
      functional verification DEFERRED to a signed go-live build** (entitlements need signing; magic link needs
      SMTP/deep-links) — built & rendered, not runnable unsigned. Residual polish → 4d/4e (see PROGRESS).
- [x] **4d — Schedule & availability (MERGED 3b13bf6)** `2026-08-25-plan-4d-schedule.md`
      Schedule tab (up-next glass hero with headcount, day-grouped timeline, past collapsed, create menu),
      SessionFormView (create training/race-day), TrainingDetailView (availability list + coach override +
      record-erg), RaceDayDetailView (races + day headcount + add-race + lineup nav stub). Repo writes
      (createSession/setAvailability/createRace/recordErg, each atomic mutation+outbox) + `sessions()` rename.
      Pure Headcount/ScheduleGrouping. 76 tests + gated live e2e verified vs local stack; screenshot surfaced.
      Carry-forwards from 4b DONE (@MainActor AppEnvironment + sync() wired in 4c; upcomingSessions→sessions()).
      **Deferred to 4g:** screens don't reload when background sync completes (load once via `.task`) — add a
      sync-completion refresh; ScheduleViewModel.load() re-entrancy guard. DEBUG-only auto-sign-in + in-memory
      auth storage added (gated on PADDLTIR_DEBUG_AUTOSIGNIN) for signed-in screenshots.
- [x] **4e — Crews & Squad (MERGED 1d8dbca)** `2026-08-25-plan-4e-crews-squad.md`
      Squad tab (searchable/sortable roster; paddler detail with erg-history sparkline via Swift Charts, edit,
      archive; add/edit paddler) + Crews tab (crew cards; detail with members, IDBF gender-rule check reusing
      PaddltirCore.GenderRule, add/remove-from-squad, races; create crew). Repo adds: SquadRepository.ergHistory;
      CrewRepository createCrew/racesForCrew/summaries. Pure SquadQuery + GenderTally. 84 tests + gated live e2e
      verified; Squad+Crews screenshots surfaced (real seed). DEBUG PADDLTIR_DEBUG_TAB env for screenshots.
      **Carry-forward to 4f/4g:** add heat drummer/sweep persistence (LineupRepository writes `seats` but nothing
      writes `heats` — needed by the 4f editor); a CrewDetailModel gender-rule-verdict unit test; guard SquadView's
      add-sheet on a non-empty clubId (currently falls back to ""); boat-size-specific gender check (4f); surface
      the side/gender/role squad filter chips (model already supports them).
- [ ] **4f — Lineup editor (the hero)** `2026-08-25-plan-4f-editor.md`
      Races/heats; the hull grid; seat **drag** (spring + haptic) and **tap-tap**; the **Balance HUD**
      telemetry (emerald/red verdicts + balance beam) driven by `PaddltirCore` on every change; reserves
      tray; **Suggest** & **Auto-fill** (PaddltirCore); **Optimise** (calls the solver, honest proven marks);
      heat switcher; glass toolbar; undo/redo; locks. Mac: centred hull + right inspector. Verify: screenshots + interaction.
- [ ] **4g — Coach app integration & polish** end-to-end against merged backend, offline smoke,
      verification-before-completion, Mac layout pass, accessibility pass. (write after 4f)

## Cross-cutting contracts (every sub-plan honours)
- Import `PaddltirCore` for ALL domain logic (scoring, greedy, suggestions, validation) — no logic in the app.
- Style everything through the design-system tokens/components from 4a — never raw hex/fonts in a view.
- Light mode only; but colours come from asset-catalog sets (future-dark-ready).
- Liquid Glass ONLY on floating chrome (heat switcher, toolbars, tray, balance bar); solid hairline
  surfaces for the hull/tables/dense data.
- 44pt targets, VoiceOver labels, Dynamic Type, reduced-motion, safe-area — the quality floor in direction.md.
- Commit per task; each sub-plan merges to main after its own review (subagent-driven-development).

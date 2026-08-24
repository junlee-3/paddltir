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
- [ ] **4a — Foundation** `2026-08-25-plan-4a-foundation.md`
      XcodeGen project (iOS+macOS), PaddltirCore linked, Inter Tight bundled, colour asset catalog from
      tokens, type scale + spacing, core reusable components (MicroLabel, GlassCard/Toolbar, PrimaryButton,
      SeatTile, TelemetryGrid, Pill), a **Design System gallery** screen. Verify: builds + screenshot.
- [ ] **4b — Data layer & sync** `2026-08-25-plan-4b-data.md`
      Swift row models mirroring the schema; GRDB local store + migrations; Supabase client (supabase-swift)
      for Auth/PostgREST/Realtime; repositories; pull-on-foreground / outbox-push / last-write-wins sync;
      an offline-first cache. Verify: unit tests on mappers/sync-diff; a seeded local DB renders a list.
- [ ] **4c — Auth & onboarding** `2026-08-25-plan-4c-auth.md`
      Sign in with Apple + email magic link (Supabase Auth); create-club / join-with-code (RPCs);
      claim-your-name; Settings (club, invite code/share, category rules, sign out). Verify: flow screenshots.
- [ ] **4d — Schedule & availability** `2026-08-25-plan-4d-schedule.md`
      Schedule tab, Up-next hero, session detail (training + race day), availability list + coach override,
      record-erg quick action. Verify: screenshots against the demo data.
- [ ] **4e — Crews & Squad** `2026-08-25-plan-4e-crews-squad.md`
      Crews tab + crew detail (members, gender-rule check, races history); Squad roster table (sort/filter),
      paddler detail (edit, erg history sparkline, availability, invite/link). Verify: screenshots.
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

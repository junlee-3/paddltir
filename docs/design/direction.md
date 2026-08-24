# Paddltir — Visual Direction (CrewCoach, enhanced)

*Native SwiftUI, iOS 26 + macOS 26. Premium Apple sensibility, real Liquid Glass, light mode only (v1).*

**Direction chosen by Jun (2026-08-25): carry the CrewCoach look & colour scheme forward, elevated.**
Not the water/teal-identity that was explored and rejected. The job is to keep CrewCoach recognisable
and make it feel premium.

## What CrewCoach is (preserve these — they are the identity)
- A **clean, dense, utilitarian data tool**: near-monochrome **slate on off-white**, depth from
  **1px hairline borders**, not shadows; crisp near-square geometry; tiny **UPPERCASE tracked
  micro-labels**; a confident **slate-900 primary button**; **Inter Tight** throughout.
- **Colour is only semantic**, and it pops because everything around it is grey:
  - **Gender tiles (load-bearing):** Male = green (`#DCFCE7` fill / `#86EFAC` border);
    Female = amber (`#FEF3C7` fill / `#FCD34D` border).
  - **Balance verdicts:** good = emerald `#059669`; over threshold = red `#DC2626` (bold).
- A separate warm **landing brand**: cream paper, **Playfair Display** serif headlines, teal CTA
  `#0D7377`, softer shapes.

## The enhancement (what "better" means)
*Jun's calls (2026-08-25) after reviewing the concept: **sans-serif throughout** (no serif),
**light mode only**, keep the **Liquid Glass**. Light look otherwise approved.*

1. **Sans-serif, all of it — Inter Tight throughout.** UI, data, labels, wordmark, and display titles.
   No Playfair / serif. Display moments earn their weight through size + heavier Inter Tight weights
   (700/800) and tight tracking, not a second family. This keeps the CrewCoach *app* voice (which was
   always Inter Tight sans), just sharpened.
2. **Unify one brand accent: teal `#0D7377`** (CrewCoach's landing CTA). Active nav, selection, focus,
   links, brand marks. The **primary action stays slate-900** (that black button is premium) — teal is
   the identity accent, not the button colour.
3. **Light mode only (v1).** Per Jun. The token architecture below stays theme-able so a dark mode
   could be added later without a rework, but v1 ships light-only — do not build dark surfaces now.
4. **Premium Apple polish + Liquid Glass** on floating chrome — the native enhancement CrewCoach (a web
   app) couldn't have. Lean into the glass on the heat switcher, toolbar, reserves tray, balance bar.
5. **Refined geometry**: keep it crisp (CrewCoach's 2px is *too* sharp for touch) → **12px cards** / 8px
   controls / 6px control-sm / 8px tiles (shipped DS.R values). Hairline borders remain the primary depth
   cue; shadows stay restrained.
6. **Tabular numerals everywhere** data appears; better spacing rhythm and touch density than the web app.

## Palette — CrewCoach slate + teal (light only, v1)
| token | value | role |
|---|---|---|
| `bg`           | `#FAFAFA` | app background (CrewCoach off-white) |
| `surface`      | `#FFFFFF` | cards, hull, main panel |
| `surface2`     | `#F8FAFC` | insets, table head, section bands (slate-50) |
| `ink`          | `#0F172A` | primary text (slate-900) |
| `ink2`         | `#475569` | secondary text (slate-600) |
| `ink3`         | `#64748B` | muted / micro-labels (slate-500) |
| `border`       | `#E2E8F0` | hairline — the CrewCoach depth cue (slate-200) |
| `primary`      | `#0F172A` | primary button (slate-900) |
| `accent`       | `#0D7377` | brand teal — active, selection, focus, links |
| `good`         | `#059669` | balanced / within threshold (emerald-600) |
| `danger`       | `#DC2626` | over threshold / violation (red-600) |
| `maleFill`/`maleBrd`     | `#DCFCE7` / `#86EFAC` | Male tile (kept exactly) |
| `femaleFill`/`femaleBrd` | `#FEF3C7` / `#FCD34D` | Female tile (kept exactly) |

*Define these as an asset-catalog colour set anyway (single "Any Appearance" value) so a dark set can
be dropped in later without touching call sites.*

## Typography — Inter Tight only
- **Inter Tight** everywhere. No serif. Body/data 400–600; **display titles + wordmark 700/800 with
  tight tracking** (`-0.02em`) at large sizes — weight and scale do the work a second family would.
- Micro-labels: `11px`/`text-xs` UPPERCASE, `letter-spacing .09em`, slate-500 — the CrewCoach signature.
- **Tabular figures** for every number (weights, erg, deltas, seat #s).
- Native: bundle Inter Tight (variable) in the app; SF Pro is the only fallback in the stack.

## Liquid Glass — floating chrome only (real APIs)
`.glassEffect()`, `GlassEffectContainer`, `glassEffectID`, `.buttonStyle(.glass)`.
Glass: heat-switcher capsule, the toolbar (Suggest/Auto-fill/Optimise/Share), the reserves tray, the
Up-next floating actions. Solid + hairline-bordered: the boat hull grid, tables, every dense surface.
*Glass over numbers is unreadable — obey it.*

## Balance telemetry (enhance CrewCoach's "Crew Controls", don't replace it)
Keep the CrewCoach **2-column stat grid** whose verdicts flip **emerald (ok) ↔ red bold (warn)** at the
same thresholds (`weight Δ 10kg`, `power Δ 10%`, `side-pref 80%`, `trim Δ 50kg`), plus the gender count
vs rule. Elevate it: a glass bar, tabular numerals, a slim horizontal **balance beam** (a hairline with
a teal/amber indicator that slides off-centre when the hull lists) as a refined at-a-glance cue above
the stats. This is CrewCoach's telemetry, made premium — not the rejected water-line.

## Motion, density, quality floor
Physical spring drag with haptics; matched-geometry heat switch (`glassEffectID`); 200–320ms springs,
exits ~70%; reduced-motion honoured. Dense tables done beautifully (tabular nums, subtle slate-50 head,
hairline dividers, hover). Contrast ≥ 4.5:1; 44pt targets; VoiceOver on seats/gauges;
Dynamic Type; safe-area aware; enforced light appearance (system chrome must not go dark). Custom favicon/wordmark (CrewCoach had the default Vite icon — replace it).

## Component inventory (coach app)
Glass: HeatSwitcher · GlassToolbar · ReservesTray · UpNext actions · BalanceBar.
Solid + hairline: SeatTile (green/amber gender, name · role letter · side · weight) · HullGrid ·
SectionBand · TelemetryGrid (emerald/red verdicts) · RosterTable · SquadRow · CrewCard ·
AvailabilityRing · OptimiseSheet (honest per-stage ✓ proven / ≈ best-found).
Nav: iPhone 3-tab (Schedule · Crews · Squad) with a **teal left-accent-bar active state** (CrewCoach's
own nav pattern) on iPad/Mac sidebar; NavigationSplitView on the big screens.

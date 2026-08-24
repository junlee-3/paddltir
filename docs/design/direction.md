# Paddltir — Visual Direction (CrewCoach, enhanced)

*Native SwiftUI, iOS 26 + macOS 26. Premium Apple sensibility, real Liquid Glass, full light + dark.*

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
1. **Reconcile the two CrewCoach systems.** Keep the app's disciplined slate/white data-density AND
   borrow the landing's typographic character: **Playfair Display** for display/brand moments
   (wordmark, big screen titles, the hero metric), **Inter Tight** for all UI and data. This is the
   single biggest lift in perceived quality.
2. **Unify one brand accent: teal `#0D7377`** (already CrewCoach's landing CTA). Used for active nav,
   selection, focus, links, and brand marks. The **primary action stays slate-900** (that black button
   is premium) — teal is the identity accent, not the button colour.
3. **First-class dark mode** (CrewCoach had none; the new product requires it). Slate-950 grounds,
   brightened teal + status colours, borders become light hairlines.
4. **Premium Apple polish + Liquid Glass** on floating chrome — the native enhancement CrewCoach (a web
   app) couldn't have.
5. **Refined geometry**: keep it crisp (CrewCoach's 2px is *too* sharp for touch) → 8px cards / 6px
   controls / 8px tiles. Hairline borders remain the primary depth cue; shadows stay restrained.
6. **Tabular numerals everywhere** data appears; better spacing rhythm and touch density than the web app.

## Palette — CrewCoach slate + teal (light / dark)
| token | light | dark | role |
|---|---|---|---|
| `bg`           | `#FAFAFA` | `#0B0F14` | app background (CrewCoach off-white) |
| `surface`      | `#FFFFFF` | `#111820` | cards, hull, main panel |
| `surface2`     | `#F8FAFC` | `#18212B` | insets, table head, section bands (slate-50) |
| `ink`          | `#0F172A` | `#E6EDF3` | primary text (slate-900) |
| `ink2`         | `#475569` | `#94A3B8` | secondary (slate-600 / slate-400) |
| `ink3`         | `#64748B` | `#64748B` | muted / micro-labels (slate-500) |
| `border`       | `#E2E8F0` | `#243040` | hairline — the CrewCoach depth cue (slate-200) |
| `primary`      | `#0F172A` | `#E6EDF3` | primary button (slate-900 → near-white on dark) |
| `accent`       | `#0D7377` | `#2CB7B0` | brand teal — active, selection, focus, links |
| `good`         | `#059669` | `#34D399` | balanced / within threshold (emerald-600) |
| `danger`       | `#DC2626` | `#F87171` | over threshold / violation (red-600) |
| `maleFill`/`maleBrd`     | `#DCFCE7` / `#86EFAC` | `#16351f` / `#2f6b3d` | Male tile |
| `femaleFill`/`femaleBrd` | `#FEF3C7` / `#FCD34D` | `#3a2f10` / `#7a6320` | Female tile |

## Typography
- **Inter Tight** — all UI, data, labels. Weights 500/600 dominant; headings semibold `tracking-tight`.
  Micro-labels: `text-xs`/`11px` UPPERCASE, `tracking-wider`, slate-500. Tabular figures for all numbers.
- **Playfair Display** (600/700, italic for emphasis) — the wordmark, large screen titles, the hero
  metric on the Up-next card. Used with restraint; this is the "premium editorial" borrow from the
  CrewCoach landing that lifts the whole app.
- Native note: on device, Inter Tight is bundled; Playfair Display bundled for display only. (SF Pro is
  the fallback, but Inter Tight *is* the CrewCoach signature and is kept.)

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
hairline dividers, hover). Contrast ≥ 4.5:1 both themes; 44pt targets; VoiceOver on seats/gauges;
Dynamic Type; safe-area aware. Custom favicon/wordmark (CrewCoach had the default Vite icon — replace it).

## Component inventory (coach app)
Glass: HeatSwitcher · GlassToolbar · ReservesTray · UpNext actions · BalanceBar.
Solid + hairline: SeatTile (green/amber gender, name · role letter · side · weight) · HullGrid ·
SectionBand · TelemetryGrid (emerald/red verdicts) · RosterTable · SquadRow · CrewCard ·
AvailabilityRing · OptimiseSheet (honest per-stage ✓ proven / ≈ best-found).
Nav: iPhone 3-tab (Schedule · Crews · Squad) with a **teal left-accent-bar active state** (CrewCoach's
own nav pattern) on iPad/Mac sidebar; NavigationSplitView on the big screens.

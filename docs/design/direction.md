# Paddltir — Visual Direction

*Native SwiftUI, iOS 26 + macOS 26. Premium Apple sensibility, real Liquid Glass, full light + dark.*

Design skills consulted: frontend-design, ui-ux-pro-max (its default sports-app recommendation
— team red / Barlow Condensed / "vibrant block-based" — was deliberately rejected as generic;
the brief calls for Apple-first-party restraint and a water identity, not an energetic sports look).

## Thesis — "a boat that sits level"
The core job of the product is **balance**: a level hull sits flat and runs true; an unbalanced one
lists and veers. That physical truth is the whole design language. The interface is calm and precise
when a lineup is balanced, and introduces subtle visual *tension* (a tilt, a warmed edge) when it
isn't. This is specific to dragon boat and cannot be mistaken for a generic roster app.

## Signature — the Balance HUD as a bubble-level
The live balance readout is NOT a row of stat tiles. It is a **water-line**: a horizontal liquid
surface that tilts left/right with weight imbalance and rides high/low bow/stern with trim, settling
flat with a spring when the lineup comes into balance. Four quiet gauges (weight Δ, power Δ, side/seat
prefs, trim) and a gender badge sit under it. Spend the boldness here; keep everything else disciplined.

## Palette — water & dawn (cohesive, calm status colors)
Semantic tokens (SwiftUI `Color` asset catalog, light / dark):

| token | light | dark | use |
|---|---|---|---|
| `bg`            | `#F5F3EE` | `#0A1A22` | app background (warm bone / river-at-dusk) |
| `surface`       | `#FFFFFF` | `#12262F` | hull, cards (solid, legible — never glass) |
| `surface2`      | `#ECEFEF` | `#1A333D` | section bands, insets |
| `ink`           | `#10242E` | `#EAF1F0` | primary text (≥ 12:1 on surface) |
| `inkSecondary`  | `#4A5A62` | `#9FB4B7` | secondary text (≥ 4.5:1) |
| `accent`        | `#0B7E7A` | `#35C4BE` | river teal — selection, active, the water line |
| `good`          | `#2F8F5B` | `#4CC585` | balanced / within threshold |
| `warn`          | `#9A6A1E` (text) / `#C98A2E` (fill) | `#E8B057` | over threshold (amber, paddle-wood) |
| `danger`        | `#C2453C` | `#E8635A` | hard violation (gender rule, duplicate) — muted, never fire-engine |
| `hairline`      | `#00000014` | `#FFFFFF1A` | dividers, seat borders |

Gender is shown by a hairline/side-dot, never a loud fill (the old app's green/amber tiles read cheap).

## Typography — native, numerals are the star
- **SF Pro Text / Display** for all UI. Dynamic Type throughout; never truncate data labels.
- **SF Pro Rounded** for numeric readouts, the Balance HUD figures, and section headers — the rounded
  variant reads calmer/more "water" and marks the readout moments, while staying 100% native + free.
- **Tabular figures** everywhere numbers appear (weights, erg, deltas, seat numbers) — no layout jitter.
- Type scale (pt): 34 largeTitle · 28/22 title · 17 headline(semibold) · 17 body · 16 callout ·
  15 subhead · 13 footnote · 12 caption. HUD hero number 44 rounded-bold tabular.
- Consider (not committed): New York for the wordmark only — a subtle heritage nod. In-app stays SF.

## Liquid Glass — floating chrome only (real APIs)
`.glassEffect()`, `GlassEffectContainer`, `glassEffectID` (morph transitions), `.buttonStyle(.glass)`.
- **Glass:** heat-switcher capsule, Balance HUD bar, reserves tray sheet, toolbar (Suggest/Auto-fill/
  Optimise/Share), the "Up next" floating actions. Glass edges pick up the teal accent.
- **Solid, high-legibility:** the boat hull grid and every dense-data surface. *Glass over numbers is
  unreadable* — the brief says this explicitly; obey it.

## Motion — physical, spring, interruptible
- Seat drag: long-press lift (scale 1.03 + shadow + haptic), targets highlight, drop = spring; a
  displaced card springs back to origin. Gauges preview the delta live while dragging.
- **Signature motion:** the HUD water-line *settles* with a spring when balance is reached (a small
  "click into level"). Reduced-motion: it snaps flat instead of sloshing.
- Heat switch + suggestion-apply: matched geometry (`glassEffectID`). Durations 200–320ms, spring
  curves; exits ~70% of enter. Never block input mid-animation.

## Data density done well
The seating grid is tabular by nature — make it beautiful, not fought. `L | bench# · section | R`
rhythm, subtly shaded section bands (Stroke/Pace/Engine/Sprint), tabular numerals, restrained color
(color appears only for a violated pref or a threshold breach). Mac/iPad: hull centred, right inspector.

## Component inventory (coach app)
Glass: HeatSwitcher capsule · BalanceHUD (water-line + 4 gauges + gender badge) · ReservesTray ·
GlassToolbar · UpNext actions. Solid: SeatCard · HullGrid · SectionBand · CrewCard · SquadRow ·
AvailabilityList · OptimiseProgressSheet (honest per-stage ✓ proven / ≈ best-found). 
Navigation: iPhone 3-tab (Schedule · Crews · Squad) + avatar; iPad/Mac NavigationSplitView.

## Quality floor (non-negotiable)
Contrast ≥ 4.5:1 both themes · 44pt targets · VoiceOver labels on every seat/gauge · Dynamic Type to
largest without breakage · reduced-motion honored · safe-area aware · both themes designed together.

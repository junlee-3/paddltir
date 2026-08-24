# Plan 4a — Coach App Foundation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: superpowers:subagent-driven-development. Steps use `- [ ]`.

**Goal:** A buildable SwiftUI multiplatform app (iOS 26 + macOS 26) that links `PaddltirCore`, bundles Inter Tight, defines the full enhanced-CrewCoach design system (colour tokens, type scale, spacing, reusable components), and renders a **Design System gallery** plus a 3-tab navigation shell — verified by an iOS-simulator build and screenshot.

**Architecture:** XcodeGen-generated project from a checked-in `apple/project.yml`. One multiplatform app target `Paddltir` + a unit-test target. Design system lives in `apple/Sources/DesignSystem/` (tokens, type, components) and is consumed by feature code. Fonts registered at runtime (cross-platform). Light mode only, colours via asset catalog.

**Tech Stack:** Swift 6.2 / Xcode 26.1, SwiftUI, XcodeGen 2.45, PaddltirCore (local SPM), Inter Tight (bundled static TTFs), Swift Testing.

**Spec:** `docs/superpowers/specs/2026-08-22-paddltir-design.md` §3; `docs/design/direction.md` (tokens/rules); `docs/superpowers/plans/2026-08-25-plan-4-roadmap.md` (build decisions); concept `docs/design/concepts/coach-app-concepts.html`.

## Global Constraints
- **Colours (light, from direction.md)** — asset-catalog colour sets, exact hex:
  bg `#FAFAFA`, surface `#FFFFFF`, surface2 `#F8FAFC`, ink `#0F172A`, ink2 `#475569`, ink3 `#64748B`,
  border `#E2E8F0`, border2 `#EEF2F6`, primary `#0F172A`, onPrimary `#FFFFFF`, accent `#0D7377`,
  good `#059669`, danger `#DC2626`, maleFill `#DCFCE7`, maleBorder `#86EFAC`, femaleFill `#FEF3C7`,
  femaleBorder `#FCD34D`.
- **Type: Inter Tight only.** Static weights 400/500/600/700/800 bundled; tabular figures for numbers;
  display titles 700/800 tight tracking. Never SF-serif; never a second family.
- **Liquid Glass** via `.glassEffect()` / `.buttonStyle(.glass)` ONLY on floating chrome; solid hairline
  surfaces elsewhere.
- Geometry: card radius 12, control/tile radius 8, control-sm 6. Hairline borders are the depth cue.
- All domain logic comes from `import PaddltirCore` — no domain math in the app.
- `apple/*.xcodeproj`, `apple/DerivedData/`, `apple/screenshots/`, bundled font binaries staged under
  `apple/Sources/Resources/Fonts/` ARE committed (fonts), but `.xcodeproj`/DerivedData are git-ignored.
- Build check: `cd apple && xcodegen generate && xcodebuild -scheme Paddltir -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -derivedDataPath DerivedData build` → BUILD SUCCEEDED, 0 warnings ideally.
- Commit per task with the conventional prefix + Co-Authored-By / Claude-Session trailers.

---

## File structure
```
apple/
  project.yml                       XcodeGen spec (iOS+macOS app + tests)
  .gitignore                        *.xcodeproj/, DerivedData/, screenshots/
  Sources/
    App/
      PaddltirApp.swift             @main; registers fonts; RootView
      RootView.swift                TabView (iOS) / NavigationSplitView (macOS), 3 tabs
      FontRegistration.swift        CTFontManager runtime registration
    DesignSystem/
      Theme.swift                   Color tokens (from asset catalog), Metrics (radius/spacing)
      Typography.swift              Font.paddltir(...) scale + weights + tabular
      Components/
        MicroLabel.swift  Pill.swift  Buttons.swift  Cards.swift  GlassChrome.swift
        SeatTile.swift  TelemetryGrid.swift  BalanceBeam.swift  HeatSwitcher.swift  AvailabilityRing.swift
      Gallery/DesignSystemGallery.swift
    Resources/
      Assets.xcassets/              colour sets (one per token), AppIcon, AccentColor
      Fonts/InterTight-{Regular,Medium,SemiBold,Bold,ExtraBold}.ttf
    Features/
      SchedulePlaceholder.swift  CrewsPlaceholder.swift  SquadPlaceholder.swift
  Tests/PaddltirAppTests/ThemeTests.swift  TypographyTests.swift
```

---

### Task 1: XcodeGen project + PaddltirCore, buildable hello app

**Files:** create `apple/project.yml`, `apple/.gitignore`, `apple/Sources/App/PaddltirApp.swift`, `apple/Sources/App/RootView.swift`, `apple/Sources/Resources/Assets.xcassets/` (AppIcon + AccentColor placeholders), `apple/Tests/PaddltirAppTests/SmokeTests.swift`. Modify repo-root `.gitignore`.

- [ ] **Step 1: project.yml**
```yaml
name: Paddltir
options:
  bundleIdPrefix: app.paddltir
  deploymentTarget:
    iOS: "26.0"
    macOS: "26.0"
  createIntermediateGroups: true
packages:
  PaddltirCore:
    path: ../packages/PaddltirCore
targets:
  Paddltir:
    type: application
    supportedDestinations: [iOS, macOS]
    sources:
      - path: Sources
    resources:
      - path: Sources/Resources
    dependencies:
      - package: PaddltirCore
    info:
      path: Sources/App/Info.plist
      properties:
        CFBundleDisplayName: Paddltir
        UILaunchScreen: {}
        ITSAppUsesNonExemptEncryption: false
    settings:
      base:
        MARKETING_VERSION: "0.1.0"
        CURRENT_PROJECT_VERSION: "1"
        GENERATE_INFOPLIST_FILE: true
        SWIFT_VERSION: "6.0"
        DEVELOPMENT_TEAM: ""
        CODE_SIGN_IDENTITY: ""
        CODE_SIGNING_REQUIRED: "NO"
        CODE_SIGNING_ALLOWED: "NO"
        ENABLE_PREVIEWS: "YES"
        ASSETCATALOG_COMPILER_GENERATE_ASSET_SYMBOLS: "NO"
  PaddltirAppTests:
    type: bundle.unit-test
    supportedDestinations: [iOS, macOS]
    sources: [Tests/PaddltirAppTests]
    dependencies:
      - target: Paddltir
schemes:
  Paddltir:
    build:
      targets: {Paddltir: all, PaddltirAppTests: [test]}
    test:
      targets: [PaddltirAppTests]
```
Note: XcodeGen auto-generates Info.plist via `GENERATE_INFOPLIST_FILE`; delete the explicit `info:` block if it conflicts — prefer the generated one and set `INFOPLIST_KEY_*` build settings if needed. Verify which works when you build.

- [ ] **Step 2: .gitignore** (`apple/.gitignore`): `*.xcodeproj/`, `DerivedData/`, `screenshots/`, `.DS_Store`. Append to repo-root `.gitignore`: `apple/*.xcodeproj/`, `apple/DerivedData/`, `apple/screenshots/`.

- [ ] **Step 3: minimal app**
```swift
// apple/Sources/App/PaddltirApp.swift
import SwiftUI
import PaddltirCore
@main struct PaddltirApp: App {
    init() { FontRegistration.registerAll() }   // FontRegistration added in Task 2; stub it as empty now
    var body: some Scene { WindowGroup { RootView() } }
}
```
```swift
// apple/Sources/App/RootView.swift
import SwiftUI
import PaddltirCore
struct RootView: View {
    var body: some View {
        VStack(spacing: 12) {
            Text("Paddltir").font(.largeTitle.bold())
            // prove PaddltirCore links:
            Text("Boat capacity: \(Boat.standard.capacity)").monospacedDigit()
        }.padding()
    }
}
```
Add a temporary empty `FontRegistration` so it compiles:
```swift
// apple/Sources/App/FontRegistration.swift
enum FontRegistration { static func registerAll() {} }
```

- [ ] **Step 4: smoke test**
```swift
// apple/Tests/PaddltirAppTests/SmokeTests.swift
import Testing
import PaddltirCore
@testable import Paddltir
@Suite struct SmokeTests { @Test func coreLinks() { #expect(Boat.standard.capacity == 20) } }
```

- [ ] **Step 5: generate + build**
Run: `cd apple && xcodegen generate && xcodebuild -scheme Paddltir -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -derivedDataPath DerivedData build 2>&1 | tail -20`
Expected: `** BUILD SUCCEEDED **`. Fix any project.yml issues (deployment target names, resource path). If `xcodebuild` can't find the scheme, run `xcodegen generate` first and check `xcodebuild -list`.

- [ ] **Step 6: commit** — `git add apple .gitignore && git commit -m "feat(app): XcodeGen project, PaddltirCore linked, buildable shell"`

---

### Task 2: Inter Tight fonts + Typography

**Files:** download 5 TTFs to `apple/Sources/Resources/Fonts/`; create `apple/Sources/App/FontRegistration.swift` (real), `apple/Sources/DesignSystem/Typography.swift`, `apple/Tests/PaddltirAppTests/TypographyTests.swift`.

- [ ] **Step 1: fetch Inter Tight static weights** (Google Fonts OFL)
```bash
cd apple/Sources/Resources/Fonts
base=https://github.com/google/fonts/raw/main/ofl/intertight/static
for w in Regular Medium SemiBold Bold ExtraBold; do
  curl -fsSL "$base/InterTight-$w.ttf" -o "InterTight-$w.ttf"; done
ls -la   # 5 .ttf files, each ~300–400KB
```
If a URL 404s, list the dir via the GitHub API `https://api.github.com/repos/google/fonts/contents/ofl/intertight/static` and adjust names. Commit the TTFs (they're app resources; OFL license permits bundling — note the license in the fonts folder as `OFL.txt` fetched from `ofl/intertight/OFL.txt`).

- [ ] **Step 2: runtime registration** (cross-platform, robust)
```swift
// apple/Sources/App/FontRegistration.swift
import CoreText
import Foundation
enum FontRegistration {
    static func registerAll() {
        let names = ["InterTight-Regular","InterTight-Medium","InterTight-SemiBold","InterTight-Bold","InterTight-ExtraBold"]
        for n in names {
            guard let url = Bundle.main.url(forResource: n, withExtension: "ttf") else { continue }
            CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
        }
    }
}
```

- [ ] **Step 3: Typography** — the scale from direction.md, mapping weights to the bundled family names.
```swift
// apple/Sources/DesignSystem/Typography.swift
import SwiftUI
public enum PaddltirFont {
    public enum W { case regular, medium, semibold, bold, heavy
        var name: String { switch self {
            case .regular:"InterTight-Regular"; case .medium:"InterTight-Medium"
            case .semibold:"InterTight-SemiBold"; case .bold:"InterTight-Bold"; case .heavy:"InterTight-ExtraBold" } } }
    /// Inter Tight at a size/weight; falls back to system if the custom face is unavailable.
    public static func font(_ size: CGFloat, _ w: W = .regular) -> Font { .custom(w.name, size: size) }
}
public extension Font {
    static let dsLargeTitle = PaddltirFont.font(30, .heavy)      // screen titles (tracking -.02 applied at call site)
    static let dsTitle      = PaddltirFont.font(22, .bold)
    static let dsHeadline   = PaddltirFont.font(17, .semibold)
    static let dsBody       = PaddltirFont.font(16, .regular)
    static let dsCallout    = PaddltirFont.font(15, .medium)
    static let dsSubhead    = PaddltirFont.font(14, .medium)
    static let dsFootnote   = PaddltirFont.font(13, .regular)
    static let dsCaption    = PaddltirFont.font(12, .medium)
    static let dsMicro      = PaddltirFont.font(11, .semibold)   // UPPERCASE tracked micro-labels
    static func dsNumber(_ size: CGFloat, _ w: PaddltirFont.W = .bold) -> Font {
        PaddltirFont.font(size, w) }   // pair with .monospacedDigit() at the call site
}
```

- [ ] **Step 4: test the fonts register** — a test asserting the CTFont for "InterTight-SemiBold" resolves.
```swift
// apple/Tests/PaddltirAppTests/TypographyTests.swift
import Testing
import CoreText
@testable import Paddltir
@Suite struct TypographyTests {
    @Test func interTightRegisters() {
        FontRegistration.registerAll()
        let f = CTFontCreateWithName("InterTight-SemiBold" as CFString, 17, nil)
        let name = CTFontCopyPostScriptName(f) as String
        #expect(name.contains("InterTight"), "resolved \(name) — Inter Tight not registered/bundled")
    }
}
```

- [ ] **Step 5: wire registration** — ensure `PaddltirApp.init()` calls `FontRegistration.registerAll()` (already does from Task 1). Build + run test: `xcodebuild -scheme Paddltir -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -derivedDataPath DerivedData test 2>&1 | tail -15`. Expected: TypographyTests pass. If the PostScript name differs (e.g. `InterTight-SemiBold` vs `InterTight18pt-SemiBold`), adjust `W.name` to the actual PostScript names — print them from the registered fonts to discover.
- [ ] **Step 6: commit** — `git add apple && git commit -m "feat(app): bundle Inter Tight, runtime registration, type scale"`

---

### Task 3: Colour asset catalog + Theme

**Files:** create colour sets under `apple/Sources/Resources/Assets.xcassets/Colors/` (one `.colorset` per token) and `apple/Sources/DesignSystem/Theme.swift`, `apple/Tests/PaddltirAppTests/ThemeTests.swift`.

- [ ] **Step 1: colour sets** — for each token in Global Constraints, create `Colors/<Token>.colorset/Contents.json` with the sRGB hex as a single "Universal / Any Appearance" colour (light-only now). Example for `accent` (#0D7377 → r 0.051, g 0.451, b 0.467):
```json
{ "colors": [ { "idiom":"universal", "color": { "color-space":"srgb",
  "components": { "red":"0.051","green":"0.451","blue":"0.467","alpha":"1.000" } } } ],
  "info": { "author":"xcode", "version":1 } }
```
Write a tiny helper script to generate all 18 colorsets from a hex list to avoid hand-rounding errors, e.g.:
```bash
python3 - <<'PY'
import json,os
tokens={"bg":"FAFAFA","surface":"FFFFFF","surface2":"F8FAFC","ink":"0F172A","ink2":"475569","ink3":"64748B","border":"E2E8F0","border2":"EEF2F6","primary":"0F172A","onPrimary":"FFFFFF","accent":"0D7377","good":"059669","danger":"DC2626","maleFill":"DCFCE7","maleBorder":"86EFAC","femaleFill":"FEF3C7","femaleBorder":"FCD34D"}
base="apple/Sources/Resources/Assets.xcassets/Colors"
for name,hexv in tokens.items():
    r,g,b=(int(hexv[i:i+2],16)/255 for i in (0,2,4))
    d=f"{base}/{name}.colorset"; os.makedirs(d,exist_ok=True)
    json.dump({"colors":[{"idiom":"universal","color":{"color-space":"srgb","components":{"red":f"{r:.3f}","green":f"{g:.3f}","blue":f"{b:.3f}","alpha":"1.000"}}}],"info":{"author":"xcode","version":1}},open(f"{d}/Contents.json","w"),indent=2)
open(f"{base}/Contents.json","w").write('{ "info": { "author":"xcode", "version":1 } }')
print("wrote",len(tokens),"colorsets")
PY
```

- [ ] **Step 2: Theme** — typed accessors + metrics.
```swift
// apple/Sources/DesignSystem/Theme.swift
import SwiftUI
public enum DS {
    // colours (asset catalog, light-only for now)
    public static let bg = Color("bg"); public static let surface = Color("surface")
    public static let surface2 = Color("surface2"); public static let ink = Color("ink")
    public static let ink2 = Color("ink2"); public static let ink3 = Color("ink3")
    public static let border = Color("border"); public static let border2 = Color("border2")
    public static let primary = Color("primary"); public static let onPrimary = Color("onPrimary")
    public static let accent = Color("accent"); public static let good = Color("good"); public static let danger = Color("danger")
    public static let maleFill = Color("maleFill"); public static let maleBorder = Color("maleBorder")
    public static let femaleFill = Color("femaleFill"); public static let femaleBorder = Color("femaleBorder")
    // metrics
    public enum R { public static let card: CGFloat = 12, ctl: CGFloat = 8, sm: CGFloat = 6, tile: CGFloat = 8 }
    public enum Space { public static let xs: CGFloat = 4, s: CGFloat = 8, m: CGFloat = 12, l: CGFloat = 16, xl: CGFloat = 24 }
    public static let hairline: CGFloat = 1
    // thresholds mirror PaddltirCore.Thresholds for HUD colouring
}
```

- [ ] **Step 3: test** — assert an asset colour resolves (non-nil) on the platform.
```swift
// apple/Tests/PaddltirAppTests/ThemeTests.swift
import Testing; import SwiftUI
@testable import Paddltir
@Suite struct ThemeTests {
    @Test func accentResolves() {
        #if canImport(UIKit)
        let c = UIColor(DS.accent); var r:CGFloat=0,g:CGFloat=0,b:CGFloat=0,a:CGFloat=0
        c.getRed(&r,green:&g,blue:&b,alpha:&a)
        #expect(abs(r-0.051) < 0.02 && abs(g-0.451) < 0.02, "accent wrong: \(r),\(g),\(b)")
        #endif
    }
}
```

- [ ] **Step 4: build + test** → pass. **Step 5: commit** — `git add apple && git commit -m "feat(app): colour asset catalog and Theme tokens"`

---

### Task 4: Core primitives (labels, buttons, cards, glass)

**Files:** `apple/Sources/DesignSystem/Components/{MicroLabel,Pill,Buttons,Cards,GlassChrome}.swift`.

- [ ] **Step 1: MicroLabel + Pill**
```swift
// MicroLabel.swift
import SwiftUI
public struct MicroLabel: View {
    let text: String; public init(_ t: String) { text = t }
    public var body: some View {
        Text(text.uppercased()).font(.dsMicro).tracking(1.2).foregroundStyle(DS.ink3)
    }
}
// Pill.swift
public struct Pill: View {
    let text: String; var tint: Color?; public init(_ t: String, tint: Color? = nil){text=t;self.tint=tint}
    public var body: some View {
        Text(text).font(.dsCaption)
            .padding(.horizontal, 9).padding(.vertical, 3)
            .background((tint ?? DS.surface2), in: .rect(cornerRadius: DS.R.sm))
            .overlay(RoundedRectangle(cornerRadius: DS.R.sm).stroke(tint == nil ? DS.border : .clear))
            .foregroundStyle(tint == nil ? DS.ink : DS.accent)
    }
}
```
- [ ] **Step 2: Buttons** — primary (slate-900) + secondary (white hairline). Include `.dynamicTypeSize` friendliness and ≥44pt height.
```swift
// Buttons.swift
public struct PrimaryButton: View {
    let title: String; let action: () -> Void
    public init(_ t: String, action: @escaping () -> Void){title=t;self.action=action}
    public var body: some View {
        Button(action: action) { Text(title).font(.dsHeadline).frame(maxWidth:.infinity).frame(minHeight:44) }
            .foregroundStyle(DS.onPrimary).background(DS.primary, in: .rect(cornerRadius: DS.R.ctl)).buttonStyle(.plain)
    }
}
public struct SecondaryButton: View { /* white bg, DS.border stroke, DS.ink text, minHeight 44 */ 
    let title: String; let action: () -> Void
    public init(_ t: String, action: @escaping () -> Void){title=t;self.action=action}
    public var body: some View {
        Button(action: action){ Text(title).font(.dsHeadline).frame(maxWidth:.infinity).frame(minHeight:44) }
            .foregroundStyle(DS.ink).background(DS.surface, in: .rect(cornerRadius: DS.R.ctl))
            .overlay(RoundedRectangle(cornerRadius: DS.R.ctl).stroke(DS.border)).buttonStyle(.plain)
    }
}
```
- [ ] **Step 3: Cards** — `HairlineCard` (white, 1px border, radius, subtle shadow) container.
```swift
// Cards.swift
public struct HairlineCard<Content: View>: View {
    var padding: CGFloat; @ViewBuilder var content: Content
    public init(padding: CGFloat = DS.Space.l, @ViewBuilder content: () -> Content){self.padding=padding;self.content=content()}
    public var body: some View {
        content.padding(padding).background(DS.surface, in: .rect(cornerRadius: DS.R.card))
            .overlay(RoundedRectangle(cornerRadius: DS.R.card).stroke(DS.border))
            .shadow(color: .black.opacity(0.05), radius: 10, y: 4)
    }
}
```
- [ ] **Step 4: GlassChrome** — the ONLY place `.glassEffect()` is used. A `GlassBar` container + a `.glassEffect` modifier wrapper with a fallback for when the API is unavailable.
```swift
// GlassChrome.swift
import SwiftUI
public struct GlassContainer<Content: View>: View {
    var radius: CGFloat; @ViewBuilder var content: Content
    public init(radius: CGFloat = DS.R.card, @ViewBuilder content: () -> Content){self.radius=radius;self.content=content()}
    public var body: some View {
        content.padding(DS.Space.m)
            .glassEffect(.regular, in: .rect(cornerRadius: radius))   // iOS/macOS 26 Liquid Glass
    }
}
```
Note: if `.glassEffect(_:in:)` signature differs in the installed SDK, adapt to the real API (`.glassEffect()` bare, or `GlassEffectContainer`). Verify against Xcode 26 SwiftUI. If the API is entirely different, wrap in `#if` and fall back to `.background(.ultraThinMaterial, in:)` — but PREFER the real Liquid Glass API; only fall back if it genuinely doesn't compile, and note it in the report.

- [ ] **Step 5: build** (compile-only is fine here) → succeeds. **Step 6: commit** — `git add apple && git commit -m "feat(app): core primitives — labels, pills, buttons, cards, glass"`

---

### Task 5: Domain components (SeatTile, TelemetryGrid, BalanceBeam, HeatSwitcher, AvailabilityRing)

**Files:** `apple/Sources/DesignSystem/Components/{SeatTile,TelemetryGrid,BalanceBeam,HeatSwitcher,AvailabilityRing}.swift`. Import `PaddltirCore` for the enums (`Gender`, `Side`, `Metrics`, `Thresholds`, `Boat`).

- [ ] **Step 1: SeatTile** — the CrewCoach gender-coloured tile. Inputs: name, side letter, weight, gender, plus flags (violatesPref, selected, lifted). Male → maleFill/maleBorder; Female → femaleFill/femaleBorder.
```swift
// SeatTile.swift
import SwiftUI; import PaddltirCore
public struct SeatTile: View {
    let name: String; let side: String; let weightKg: Double; let gender: Gender
    var violatesPref = false; var lifted = false
    public init(name: String, side: String, weightKg: Double, gender: Gender, violatesPref: Bool=false, lifted: Bool=false){
        self.name=name; self.side=side; self.weightKg=weightKg; self.gender=gender; self.violatesPref=violatesPref; self.lifted=lifted }
    var fill: Color { gender == .male ? DS.maleFill : DS.femaleFill }
    var stroke: Color { violatesPref ? DS.danger : (gender == .male ? DS.maleBorder : DS.femaleBorder) }
    public var body: some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(name).font(.dsFootnote.weight(.semibold)).foregroundStyle(DS.ink).lineLimit(1)
            HStack(spacing: 5) {
                Text(side).font(.dsCaption.weight(.bold)).foregroundStyle(violatesPref ? DS.danger : DS.ink)
                Text(weightKg, format: .number.precision(.fractionLength(0))).font(.dsCaption).monospacedDigit().foregroundStyle(DS.ink2)
            }
        }.frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 8).padding(.vertical, 5)
        .background(fill, in: .rect(cornerRadius: DS.R.tile))
        .overlay(RoundedRectangle(cornerRadius: DS.R.tile).stroke(stroke, lineWidth: violatesPref ? 1.5 : 1))
        .scaleEffect(lifted ? 1.05 : 1).shadow(color: .black.opacity(lifted ? 0.28 : 0), radius: 12, y: 6)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(name), \(gender == .male ? "male" : "female"), side \(side), \(Int(weightKg)) kilograms\(violatesPref ? ", side preference not met" : "")")
    }
}
```
- [ ] **Step 2: TelemetryGrid + gender badge** — a 2-col grid of label/value pairs that colour good (emerald) vs warn (red), driven by `Metrics` + `Boat` + `Thresholds` from PaddltirCore. A row struct `TelemetryItem(label, value, ok)`.
```swift
// TelemetryGrid.swift
import SwiftUI; import PaddltirCore
public struct TelemetryGrid: View {
    let metrics: Metrics; let boat: Boat; var thresholds: Thresholds = .default
    public init(metrics: Metrics, boat: Boat, thresholds: Thresholds = .default){self.metrics=metrics;self.boat=boat;self.thresholds=thresholds}
    var warnings: Set<Metrics.Warning> { metrics.warnings(boat: boat, thresholds: thresholds) }
    public var body: some View {
        let cols = [GridItem(.flexible()), GridItem(.flexible())]
        LazyVGrid(columns: cols, spacing: 7) {
            item("Weight", "\(Int(metrics.weightDelta)) kg", ok: !warnings.contains(.weight))
            item("Power", metrics.totalPower > 0 ? "\(Int((metrics.powerDelta/metrics.totalPower)*100))%" : "—", ok: !warnings.contains(.power))
            item("Trim", warnings.contains(.trim) ? "\(Int(metrics.trimDeltaKg(boat: boat))) kg" : "level", ok: !warnings.contains(.trim))
            item("Side pref", "\(Int(metrics.sidePreferenceFraction*100))%", ok: !warnings.contains(.side))
        }
    }
    @ViewBuilder func item(_ l: String, _ v: String, ok: Bool) -> some View {
        HStack(alignment: .firstTextBaseline) {
            MicroLabel(l); Spacer()
            Text(v).font(.dsCaption.weight(.bold)).monospacedDigit().foregroundStyle(ok ? DS.good : DS.danger)
        }.padding(.bottom, 5).overlay(alignment: .bottom){ Rectangle().fill(DS.border2).frame(height: 1) }
    }
}
```
- [ ] **Step 3: BalanceBeam** — a slim hairline track with a teal indicator offset by weight imbalance (−1…+1 normalised). Reduced-motion friendly.
- [ ] **Step 4: HeatSwitcher** — a glass segmented capsule (`GlassContainer`) with selected pill (accent) + `+`. Binding<Int> selection, `[String]` names.
- [ ] **Step 5: AvailabilityRing** — a conic-gradient ring (good fraction) with a centred count, for session cards.
- [ ] **Step 6: build → succeeds. commit** — `git add apple && git commit -m "feat(app): domain components — SeatTile, telemetry, beam, heat switcher, ring"`

---

### Task 6: Design System gallery + navigation shell

**Files:** `apple/Sources/DesignSystem/Gallery/DesignSystemGallery.swift`, `apple/Sources/Features/{Schedule,Crews,Squad}Placeholder.swift`, modify `RootView.swift`.

- [ ] **Step 1: RootView** — TabView on iOS (Schedule/Crews/Squad + a hidden Design tab in DEBUG), NavigationSplitView on macOS. Teal accent via `.tint(DS.accent)`.
```swift
// RootView.swift
import SwiftUI
struct RootView: View {
    var body: some View {
        #if os(macOS)
        NavigationSplitView { SidebarList() } detail: { SchedulePlaceholder() }.tint(DS.accent)
        #else
        TabView {
            SchedulePlaceholder().tabItem { Label("Schedule", systemImage: "calendar") }
            CrewsPlaceholder().tabItem { Label("Crews", systemImage: "figure.water.fitness") }
            SquadPlaceholder().tabItem { Label("Squad", systemImage: "person.3") }
            #if DEBUG
            DesignSystemGallery().tabItem { Label("Design", systemImage: "paintpalette") }
            #endif
        }.tint(DS.accent)
        #endif
    }
}
```
(Provide a simple `SidebarList` for macOS listing the three sections. Placeholders show the section title via a shared `ScreenScaffold` with a large Inter Tight title + a "Coming in 4d/4e/4f" note over `DS.bg`.)

- [ ] **Step 2: DesignSystemGallery** — one scrollable screen exercising every component against `DS.bg`, so a screenshot validates the whole system: swatches of all colour tokens; the type scale; primary/secondary buttons; a `HairlineCard`; a `GlassContainer` bar; a mini hull of `SeatTile`s (2–3 rows, both genders, one violating); a `TelemetryGrid` fed a sample `Metrics` (build one inline or via `Scoring.evaluate` on a tiny lineup); the `HeatSwitcher`; `AvailabilityRing`; `Pill`s and `MicroLabel`s. Group with section headers.

- [ ] **Step 3: build for iOS sim** → BUILD SUCCEEDED.

- [ ] **Step 4: boot sim, install, screenshot** — the concrete verification:
```bash
cd apple
xcrun simctl boot "iPhone 17 Pro" 2>/dev/null; sleep 8
APP=$(find DerivedData -name "Paddltir.app" -path "*Debug-iphonesimulator*" | head -1)
xcrun simctl install "iPhone 17 Pro" "$APP"
xcrun simctl launch "iPhone 17 Pro" app.paddltir.Paddltir
sleep 4; mkdir -p screenshots
xcrun simctl io "iPhone 17 Pro" screenshot screenshots/gallery.png
```
(The DEBUG Design tab is where the gallery lives; if launching lands on Schedule, the screenshot task should navigate — simplest: in DEBUG make `RootView` default-select the Design tab via `@State selection`.) Report the screenshot path; the controller surfaces it to Jun and compares against the concept (slate/white, teal accent, green/amber tiles, Inter Tight, glass bar).

- [ ] **Step 5: commit** — `git add apple && git commit -m "feat(app): design-system gallery and navigation shell"`

---

### Task 7: Wrap-up
- [ ] **Step 1: macOS build** — `xcodebuild -scheme Paddltir -destination 'platform=macOS' -derivedDataPath DerivedData build` → succeeds (fix any `#if os` gaps). If macOS signing blocks the build in this environment, record it and keep the iOS build as the gate.
- [ ] **Step 2: warnings** — `xcodebuild … build 2>&1 | grep -c warning:` → 0 (fix or record).
- [ ] **Step 3:** `apple/README.md` (10 lines: `xcodegen generate`, open/scheme, how to run tests, how to screenshot, that fonts are OFL-bundled).
- [ ] **Step 4:** confirm `xcodegen generate` is reproducible from a clean checkout (delete `.xcodeproj`, regenerate, build). Update PROGRESS + tick 4a in the roadmap. Commit + push.

# Paddltir (Apple)

SwiftUI app foundation — config, manage, and get insights into your dragon
boat crew. Links `PaddltirCore` and ships the app's design system plus a
DEBUG-only gallery tab for reviewing it.

**Prerequisites:** Xcode 26 (tested 26.1), [XcodeGen](https://github.com/yonaskolb/XcodeGen) (`brew install xcodegen`).

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

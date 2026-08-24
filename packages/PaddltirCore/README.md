# PaddltirCore

Pure Swift (Foundation only — no SwiftUI/UIKit/AppKit/Combine) library for dragon-boat
crew placement: greedy auto-fill, scoring/metrics, swap/replacement suggestions, and
gender-rule validation. Shared logic that any Swift UI layer can wrap.

## Test

```
swift test
```

53 domain/unit tests plus `PropertyTests` (60 randomized rosters checking placement
invariants) and `PerformanceTests`. All run in well under a second in debug.

## Fixtures

Golden fixtures live in `../../fixtures/{placement,evaluate}` and are shared with the
Python solver. Regenerate/verify the `expected.greedy` block via `FixtureTool`:

```
swift run FixtureTool update-greedy ../../fixtures/placement   # rewrite expected output
swift run FixtureTool check ../../fixtures/placement           # verify, exit 1 on mismatch
swift run -c release FixtureTool bench ../../fixtures/placement/std-mixed-22.json
```

Greedy auto-fill: 2.97 ms per run, release, 22-athlete standard boat.

import Foundation
@testable import PaddltirCore

/// Repo-root /fixtures directory, located relative to this source file.
func fixturesURL() -> URL {
    // .../packages/PaddltirCore/Tests/PaddltirCoreTests/Support/TestSupport.swift → repo root is 5 levels up
    var url = URL(fileURLWithPath: #filePath)
    for _ in 0..<5 { url.deleteLastPathComponent() }
    return url.appendingPathComponent("fixtures", isDirectory: true)
}

/// Deterministic RNG for property-style tests (SplitMix64).
struct SeededRNG: RandomNumberGenerator {
    private var state: UInt64
    init(seed: UInt64) { state = seed }
    mutating func next() -> UInt64 {
        state &+= 0x9E3779B97F4A7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
        z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
        return z ^ (z >> 31)
    }
}

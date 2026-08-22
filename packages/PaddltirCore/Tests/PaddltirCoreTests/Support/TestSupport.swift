import Foundation
@testable import PaddltirCore

/// Repo-root /fixtures directory, located relative to this source file.
func fixturesURL() -> URL {
    // .../packages/PaddltirCore/Tests/PaddltirCoreTests/Support/TestSupport.swift → repo root is 6 levels up
    var url = URL(fileURLWithPath: #filePath)
    for _ in 0..<6 { url.deleteLastPathComponent() }
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

func makePaddler(_ id: String, w: Double, erg: Double, side: SidePreference = .either,
                 gender: Gender = .male, pref: SeatPreference = .none, role: BoatRole = .paddler) -> Paddler {
    Paddler(id: PaddlerID(id), name: id.uppercased(), weightKg: w, ergM: erg,
            side: side, gender: gender, seatPref: pref, role: role)
}

/// 22 bench candidates + drummer + sweep, mixed, deterministic.
func standardMixedRoster() -> Roster {
    var ps: [Paddler] = []
    let women: [(Double, Double, SidePreference, SeatPreference)] = [
        (58, 520, .left, .stroke), (62, 540, .right, .stroke), (60, 500, .left, .pace), (64, 515, .either, .pace),
        (66, 530, .right, .engine), (59, 490, .left, .engine), (63, 505, .right, .engine), (61, 495, .either, .sprint),
        (65, 510, .left, .sprint), (57, 480, .right, .none),
    ]
    let men: [(Double, Double, SidePreference, SeatPreference)] = [
        (78, 640, .left, .stroke), (82, 660, .right, .pace), (85, 650, .left, .engine), (88, 670, .right, .engine),
        (80, 630, .either, .engine), (90, 680, .left, .engine), (76, 620, .right, .sprint), (84, 645, .left, .sprint),
        (79, 635, .either, .sprint), (86, 655, .right, .none), (83, 625, .left, .none), (77, 615, .right, .pace),
    ]
    for (i, w) in women.enumerated() { ps.append(makePaddler(String(format: "w%02d", i + 1), w: w.0, erg: w.1, side: w.2, gender: .female, pref: w.3)) }
    for (i, m) in men.enumerated() { ps.append(makePaddler(String(format: "m%02d", i + 1), w: m.0, erg: m.1, side: m.2, gender: .male, pref: m.3)) }
    ps.append(makePaddler("drum", w: 52, erg: 0, gender: .female, role: .drummer))
    ps.append(makePaddler("sweep", w: 81, erg: 0, gender: .male, role: .sweep))
    return Roster(ps)
}

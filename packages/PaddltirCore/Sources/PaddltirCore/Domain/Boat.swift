import Foundation

public struct Boat: Hashable, Codable, Sendable {
    public let benches: Int
    public init(benches: Int) {
        precondition(benches >= 1, "a boat needs at least one bench")
        self.benches = benches
    }
    public static let standard = Boat(benches: 10)
    public static let small = Boat(benches: 5)

    public var capacity: Int { benches * 2 }
    public var benchRange: ClosedRange<Int> { 1...benches }
    /// Fore-aft centre; bench arms are measured from here in "bench units" (≈ metres).
    public var midpoint: Double { Double(benches + 1) / 2 }
    public func arm(ofBench bench: Int) -> Double { Double(bench) - midpoint }
    public var drummerArm: Double { -midpoint }
    public var sweepArm: Double { midpoint }

    /// stroke = bench 1; sprint = last round(0.3n); pace = round(0.2n) after stroke; engine = rest.
    public func benches(in section: Section) -> ClosedRange<Int> {
        let n = benches
        if n < 4 {  // degenerate boats: stroke first, sprint last, pace/engine share the middle
            switch section {
            case .stroke: return 1...1
            case .pace: return n >= 2 ? 2...2 : 1...1
            case .engine: return n >= 3 ? 3...3 : (n >= 2 ? 2...2 : 1...1)
            case .sprint: return n...n
            }
        }
        let sprintCount = max(1, Int((Double(n) * 0.3).rounded()))
        let paceCount = max(1, Int((Double(n) * 0.2).rounded()))
        let paceStart = 2, paceEnd = 1 + paceCount
        let sprintStart = n - sprintCount + 1
        switch section {
        case .stroke: return 1...1
        case .pace: return paceStart...paceEnd
        case .engine: return (paceEnd + 1)...(sprintStart - 1)
        case .sprint: return sprintStart...n
        }
    }
    public func section(ofBench bench: Int) -> Section {
        for s in Section.allCases where benches(in: s).contains(bench) { return s }
        return .engine
    }
}

import Foundation

/// Golden fixture document (see fixtures/README.md). Shared with the Python solver.
public struct Fixture: Codable, Sendable {
    public struct Outcome: Codable, Hashable, Sendable {
        public var seats: [SeatAssignment]
        public var metrics: Metrics
        public var ruleSatisfied: Bool
        public var proven: [String: Bool]?
        public init(seats: [SeatAssignment], metrics: Metrics, ruleSatisfied: Bool, proven: [String: Bool]? = nil) {
            self.seats = seats; self.metrics = metrics; self.ruleSatisfied = ruleSatisfied; self.proven = proven
        }
    }
    public struct Expected: Codable, Hashable, Sendable {
        public var metrics: Metrics?
        public var greedy: Outcome?
        public var mip: Outcome?
        public init(metrics: Metrics? = nil, greedy: Outcome? = nil, mip: Outcome? = nil) {
            self.metrics = metrics; self.greedy = greedy; self.mip = mip
        }
    }

    public var name: String
    public var description: String?
    public var boat: Boat
    public var rule: GenderRule?
    public var paddlers: [Paddler]
    public var drummerId: PaddlerID?
    public var sweepId: PaddlerID?
    public var candidates: [PaddlerID]?
    public var locked: [SeatAssignment]?
    public var current: [SeatAssignment]?
    public var lineup: [SeatAssignment]?
    public var expected: Expected?

    public var roster: Roster { Roster(paddlers) }

    /// Default candidates: everyone who may paddle, minus the heat's drummer/sweep.
    public var effectiveCandidates: [PaddlerID] {
        candidates ?? paddlers.filter { $0.role.mayPaddle && $0.id != drummerId && $0.id != sweepId }.map(\.id)
    }
    public var placementRequest: PlacementRequest {
        PlacementRequest(boat: boat, roster: roster, candidates: effectiveCandidates, drummerId: drummerId, sweepId: sweepId,
                         locked: locked ?? [], rule: rule,
                         current: current.map { Lineup(boat: boat, drummerId: drummerId, sweepId: sweepId, assignments: $0) })
    }
    public var evaluationLineup: Lineup? {
        lineup.map { Lineup(boat: boat, drummerId: drummerId, sweepId: sweepId, assignments: $0) }
    }

    public static func outcome(from r: PlacementResult) -> Outcome {
        Outcome(seats: r.lineup.assignments, metrics: r.metrics, ruleSatisfied: r.ruleSatisfied)
    }

    public static func load(from url: URL) throws -> Fixture {
        try JSONDecoder().decode(Fixture.self, from: Data(contentsOf: url))
    }
    public static func loadAll(in dir: URL) throws -> [Fixture] {
        try FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil)
            .filter { $0.pathExtension == "json" }.sorted { $0.lastPathComponent < $1.lastPathComponent }
            .map(load(from:))
    }
    public func write(to url: URL) throws {
        let enc = JSONEncoder()
        enc.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        try (try enc.encode(self) + Data("\n".utf8)).write(to: url, options: .atomic)
    }
}

import Foundation

/// Everything the placement algorithms need. Pure data so it can be a fixture.
public struct PlacementRequest: Hashable, Codable, Sendable {
    public var boat: Boat
    public var roster: Roster
    /// Eligible for benches (already excludes unavailable/excluded people). Sweeps and the heat's drummer/sweep are filtered anyway.
    public var candidates: [PaddlerID]
    public var drummerId: PaddlerID?
    public var sweepId: PaddlerID?
    public var locked: [SeatAssignment]
    public var rule: GenderRule?
    /// Reference lineup for the `moves` tie-break.
    public var current: Lineup?
    public init(boat: Boat, roster: Roster, candidates: [PaddlerID], drummerId: PaddlerID? = nil, sweepId: PaddlerID? = nil,
                locked: [SeatAssignment] = [], rule: GenderRule? = nil, current: Lineup? = nil) {
        self.boat = boat; self.roster = roster; self.candidates = candidates; self.drummerId = drummerId
        self.sweepId = sweepId; self.locked = locked; self.rule = rule; self.current = current
    }
}

public struct PlacementResult: Hashable, Codable, Sendable {
    public var lineup: Lineup
    public var metrics: Metrics
    public var ruleSatisfied: Bool
    /// Eligible candidates left on the bank, strongest first.
    public var unseated: [PaddlerID]
    public init(lineup: Lineup, metrics: Metrics, ruleSatisfied: Bool, unseated: [PaddlerID]) {
        self.lineup = lineup; self.metrics = metrics; self.ruleSatisfied = ruleSatisfied; self.unseated = unseated
    }
}

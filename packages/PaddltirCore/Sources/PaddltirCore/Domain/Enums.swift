/// Physical side of the boat.
public enum Side: String, Codable, Hashable, Sendable, CaseIterable {
    case left, right
    public var opposite: Side { self == .left ? .right : .left }
}

/// Which side a paddler prefers to paddle on.
public enum SidePreference: String, Codable, Hashable, Sendable, CaseIterable {
    case left, right, either
    public func matches(_ side: Side) -> Bool {
        switch self {
        case .either: return true
        case .left: return side == .left
        case .right: return side == .right
        }
    }
}

public enum Gender: String, Codable, Hashable, Sendable, CaseIterable {
    case female, male
}

/// Named group of benches, bow to stern.
public enum Section: String, Codable, Hashable, Sendable, CaseIterable {
    case stroke, pace, engine, sprint
}

public enum SeatPreference: String, Codable, Hashable, Sendable, CaseIterable {
    case stroke, pace, engine, sprint, none
    public var section: Section? {
        switch self {
        case .stroke: return .stroke
        case .pace: return .pace
        case .engine: return .engine
        case .sprint: return .sprint
        case .none: return nil
        }
    }
}

public enum BoatRole: String, Codable, Hashable, Sendable, CaseIterable {
    case paddler, drummer, sweep
    /// Sweeps are never benched by the algorithms.
    public var mayPaddle: Bool { self != .sweep }
}

import Foundation

public struct Seat: Hashable, Codable, Sendable, Comparable, CustomStringConvertible {
    public let bench: Int
    public let side: Side
    public init(bench: Int, side: Side) { self.bench = bench; self.side = side }
    public static func < (a: Seat, b: Seat) -> Bool {
        a.bench != b.bench ? a.bench < b.bench : (a.side == .left && b.side == .right)
    }
    public var description: String { "\(bench)\(side == .left ? "L" : "R")" }
}

public struct SeatAssignment: Hashable, Codable, Sendable {
    public var bench: Int
    public var side: Side
    public var paddlerId: PaddlerID
    public var locked: Bool
    public init(bench: Int, side: Side, paddlerId: PaddlerID, locked: Bool = false) {
        self.bench = bench; self.side = side; self.paddlerId = paddlerId; self.locked = locked
    }
    public init(seat: Seat, paddlerId: PaddlerID, locked: Bool = false) {
        self.init(bench: seat.bench, side: seat.side, paddlerId: paddlerId, locked: locked)
    }
    public var seat: Seat { Seat(bench: bench, side: side) }

    enum CodingKeys: String, CodingKey { case bench, side, paddlerId, locked }
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        bench = try c.decode(Int.self, forKey: .bench)
        side = try c.decode(Side.self, forKey: .side)
        paddlerId = try c.decode(PaddlerID.self, forKey: .paddlerId)
        locked = try c.decodeIfPresent(Bool.self, forKey: .locked) ?? false
    }
    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(bench, forKey: .bench); try c.encode(side, forKey: .side)
        try c.encode(paddlerId, forKey: .paddlerId)
        if locked { try c.encode(locked, forKey: .locked) }
    }
}

/// Who sits where for one heat. Value type; all mutations keep `assignments` canonical (sorted by seat)
/// and guarantee each seat and each paddler appears at most once.
public struct Lineup: Hashable, Codable, Sendable {
    public var boat: Boat
    public var drummerId: PaddlerID?
    public var sweepId: PaddlerID?
    public private(set) var assignments: [SeatAssignment]

    enum CodingKeys: String, CodingKey { case boat, drummerId, sweepId, assignments }
    /// Decoding goes through the designated init so assignments are always canonical and de-duplicated.
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.init(boat: try c.decode(Boat.self, forKey: .boat),
                  drummerId: try c.decodeIfPresent(PaddlerID.self, forKey: .drummerId),
                  sweepId: try c.decodeIfPresent(PaddlerID.self, forKey: .sweepId),
                  assignments: try c.decodeIfPresent([SeatAssignment].self, forKey: .assignments) ?? [])
    }

    public init(boat: Boat, drummerId: PaddlerID? = nil, sweepId: PaddlerID? = nil, assignments: [SeatAssignment] = []) {
        self.boat = boat; self.drummerId = drummerId; self.sweepId = sweepId
        self.assignments = []
        for a in assignments.sorted(by: { $0.seat < $1.seat }) {   // later duplicates lose
            if paddler(at: a.seat) == nil && seat(of: a.paddlerId) == nil { self.assignments.append(a) }
        }
        self.assignments.sort { $0.seat < $1.seat }
    }

    public func paddler(at seat: Seat) -> PaddlerID? { assignments.first { $0.seat == seat }?.paddlerId }
    public func seat(of id: PaddlerID) -> Seat? { assignments.first { $0.paddlerId == id }?.seat }
    public var seatedIDs: Set<PaddlerID> { Set(assignments.map(\.paddlerId)) }
    public func isLocked(_ seat: Seat) -> Bool { assignments.first { $0.seat == seat }?.locked ?? false }
    public var lockedSeats: [Seat] { assignments.filter(\.locked).map(\.seat) }
    public var emptySeats: [Seat] { boat.allSeats.filter { paddler(at: $0) == nil } }
    public var isFull: Bool { assignments.count == boat.capacity }

    /// Seats `id` at `seat`, vacating any seat `id` held and evicting any occupant. Lock state of `seat` is preserved.
    public mutating func place(_ id: PaddlerID, at seat: Seat) {
        precondition(boat.benchRange.contains(seat.bench), "seat out of range")
        let wasLocked = isLocked(seat)
        assignments.removeAll { $0.paddlerId == id || $0.seat == seat }
        assignments.append(SeatAssignment(seat: seat, paddlerId: id, locked: wasLocked))
        assignments.sort { $0.seat < $1.seat }
    }
    public mutating func remove(at seat: Seat) { assignments.removeAll { $0.seat == seat } }
    public mutating func remove(_ id: PaddlerID) { assignments.removeAll { $0.paddlerId == id } }

    /// Exchanges the occupants of two seats (either may be empty). Lock flags stay with the seats.
    public mutating func swap(_ s1: Seat, _ s2: Seat) {
        guard s1 != s2 else { return }
        let p1 = paddler(at: s1), p2 = paddler(at: s2)
        let l1 = isLocked(s1), l2 = isLocked(s2)
        assignments.removeAll { $0.seat == s1 || $0.seat == s2 }
        if let p2 { assignments.append(SeatAssignment(seat: s1, paddlerId: p2, locked: l1)) }
        if let p1 { assignments.append(SeatAssignment(seat: s2, paddlerId: p1, locked: l2)) }
        assignments.sort { $0.seat < $1.seat }
    }
    public mutating func setLocked(_ locked: Bool, at seat: Seat) {
        guard let i = assignments.firstIndex(where: { $0.seat == seat }) else { return }
        assignments[i].locked = locked
    }
}

extension Boat {
    public var allSeats: [Seat] { benchRange.flatMap { [Seat(bench: $0, side: .left), Seat(bench: $0, side: .right)] } }
}

import Foundation

public struct PaddlerID: Hashable, Codable, Sendable, Comparable, CustomStringConvertible {
    public let rawValue: String
    public init(_ rawValue: String) { self.rawValue = rawValue }
    public init(from decoder: Decoder) throws { rawValue = try decoder.singleValueContainer().decode(String.self) }
    public func encode(to encoder: Encoder) throws { var c = encoder.singleValueContainer(); try c.encode(rawValue) }
    public static func < (a: PaddlerID, b: PaddlerID) -> Bool { a.rawValue < b.rawValue }
    public var description: String { rawValue }
}

public struct Paddler: Hashable, Codable, Sendable, Identifiable {
    public let id: PaddlerID
    public var name: String
    public var weightKg: Double
    /// Latest 2-minute erg result in metres; 0 when unknown.
    public var ergM: Double
    public var side: SidePreference
    public var gender: Gender
    public var seatPref: SeatPreference
    public var role: BoatRole

    public init(id: PaddlerID, name: String, weightKg: Double, ergM: Double,
                side: SidePreference, gender: Gender, seatPref: SeatPreference, role: BoatRole) {
        self.id = id; self.name = name; self.weightKg = weightKg; self.ergM = ergM
        self.side = side; self.gender = gender; self.seatPref = seatPref; self.role = role
    }
}

/// Immutable lookup of paddlers by id. Encodes as a JSON array.
public struct Roster: Hashable, Codable, Sendable {
    public let byID: [PaddlerID: Paddler]
    public init(_ paddlers: [Paddler]) {
        var d: [PaddlerID: Paddler] = [:]
        for p in paddlers { d[p.id] = p }
        byID = d
    }
    public subscript(id: PaddlerID) -> Paddler? { byID[id] }
    public var all: [Paddler] { byID.values.sorted { $0.id < $1.id } }
    public var ids: [PaddlerID] { byID.keys.sorted() }
    public var count: Int { byID.count }
    public init(from decoder: Decoder) throws { self.init(try decoder.singleValueContainer().decode([Paddler].self)) }
    public func encode(to encoder: Encoder) throws { var c = encoder.singleValueContainer(); try c.encode(all) }
}

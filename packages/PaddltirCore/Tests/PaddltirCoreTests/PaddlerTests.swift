import Foundation
import Testing
@testable import PaddltirCore

@Suite struct PaddlerTests {
    @Test func rosterLookupAndOrdering() {
        let r = Roster([makePaddler("b", w: 70, erg: 500), makePaddler("a", w: 60, erg: 400)])
        #expect(r[PaddlerID("a")]?.weightKg == 60)
        #expect(r[PaddlerID("zz")] == nil)
        #expect(r.all.map(\.id.rawValue) == ["a", "b"])   // sorted by id
        #expect(r.ids == [PaddlerID("a"), PaddlerID("b")])
    }
    @Test func paddlerRoundTripsThroughJSON() throws {
        let p = makePaddler("x1", w: 72.5, erg: 610, side: .left, gender: .female, pref: .engine, role: .drummer)
        let data = try JSONEncoder().encode(p)
        let back = try JSONDecoder().decode(Paddler.self, from: data)
        #expect(back == p)
        let json = String(decoding: data, as: UTF8.self)
        #expect(json.contains("\"seatPref\":\"engine\"") && json.contains("\"ergM\":610"))
    }
    @Test func rosterEncodesAsArray() throws {
        let r = Roster([makePaddler("a", w: 60, erg: 400)])
        let json = String(decoding: try JSONEncoder().encode(r), as: UTF8.self)
        #expect(json.hasPrefix("["))
        #expect(try JSONDecoder().decode(Roster.self, from: Data(json.utf8)) == r)
    }
}

import Foundation
import Testing
@testable import Paddltir

@Suite struct RowDecodeTests {
    // MARK: - PaddlerRow

    @Test func paddlerRowDecodes() throws {
        let json = #"""
        {"id":"11111111-1111-1111-1111-111111111111","club_id":"22222222-2222-2222-2222-222222222222","profile_id":null,"name":"Lily","email":null,"weight_kg":58.0,"preferred_side":"left","gender":"female","seat_preference":"stroke","boat_role":"paddler","archived_at":null,"created_at":"2026-08-01T00:00:00+00:00","updated_at":"2026-08-25T07:14:00.123456+00:00"}
        """#
        let p = try PostgREST.decoder.decode(PaddlerRow.self, from: Data(json.utf8))
        #expect(p.id == "11111111-1111-1111-1111-111111111111")
        #expect(p.clubId == "22222222-2222-2222-2222-222222222222")
        #expect(p.profileId == nil)
        #expect(p.name == "Lily")
        #expect(p.email == nil)
        #expect(p.weightKg == 58.0)
        #expect(p.preferredSide == .left)
        #expect(p.gender == .female)
        #expect(p.seatPreference == .stroke)
        #expect(p.boatRole == .paddler)
        #expect(p.archivedAt == nil)
        #expect(p.updatedAt != nil)

        var comps = DateComponents()
        comps.calendar = Calendar(identifier: .gregorian)
        comps.timeZone = TimeZone(identifier: "UTC")
        comps.year = 2026; comps.month = 8; comps.day = 25
        comps.hour = 7; comps.minute = 14; comps.second = 0
        let expected = comps.date!
        // Fractional seconds truncate to millisecond precision on decode;
        // assert the instant is within a second of the expected wall-clock time.
        #expect(abs(p.updatedAt!.timeIntervalSince(expected)) < 1)
    }

    // MARK: - SeatRow

    @Test func seatRowDecodes() throws {
        let json = #"""
        {"heat_id":"33333333-3333-3333-3333-333333333333","bench":1,"side":"left","paddler_id":"11111111-1111-1111-1111-111111111111","locked":true,"updated_at":"2026-08-25T07:14:00.5+00:00"}
        """#
        let s = try PostgREST.decoder.decode(SeatRow.self, from: Data(json.utf8))
        #expect(s.heatId == "33333333-3333-3333-3333-333333333333")
        #expect(s.bench == 1)
        #expect(s.side == .left)
        #expect(s.paddlerId == "11111111-1111-1111-1111-111111111111")
        #expect(s.locked == true)
        #expect(s.updatedAt != nil)
    }

    @Test func seatRowRoundTripsThroughSharedEncoder() throws {
        let original = SeatRow(
            heatId: "33333333-3333-3333-3333-333333333333",
            bench: 4,
            side: .right,
            paddlerId: "44444444-4444-4444-4444-444444444444",
            locked: false,
            updatedAt: PostgREST.parseDate("2026-08-25T07:14:00.123+00:00")
        )
        let data = try PostgREST.encoder.encode(original)
        let json = try #require(String(data: data, encoding: .utf8))
        #expect(json.contains("\"heat_id\""))
        #expect(json.contains("\"paddler_id\""))

        let decoded = try PostgREST.decoder.decode(SeatRow.self, from: data)
        #expect(decoded == original)
    }

    // MARK: - Heat

    @Test func heatDecodes() throws {
        let json = #"""
        {"id":"55555555-5555-5555-5555-555555555555","race_id":"66666666-6666-6666-6666-666666666666","name":"Heat 1","sort_order":0,"drummer_id":null,"sweep_id":null,"created_at":"2026-08-20T09:00:00+00:00","updated_at":"2026-08-25T07:14:00.987654+00:00"}
        """#
        let h = try PostgREST.decoder.decode(Heat.self, from: Data(json.utf8))
        #expect(h.id == "55555555-5555-5555-5555-555555555555")
        #expect(h.raceId == "66666666-6666-6666-6666-666666666666")
        #expect(h.name == "Heat 1")
        #expect(h.sortOrder == 0)
        #expect(h.drummerId == nil)
        #expect(h.sweepId == nil)
        #expect(h.updatedAt != nil)
    }

    // MARK: - CategoryRule

    @Test func categoryRuleDecodes() throws {
        let json = #"""
        {"club_id":"22222222-2222-2222-2222-222222222222","category":"mixed","boat_size":"standard","min_women":4,"max_women":10,"min_men":null,"max_men":null,"updated_at":"2026-08-25T07:14:00+00:00"}
        """#
        let r = try PostgREST.decoder.decode(CategoryRule.self, from: Data(json.utf8))
        #expect(r.clubId == "22222222-2222-2222-2222-222222222222")
        #expect(r.category == .mixed)
        #expect(r.boatSize == .standard)
        #expect(r.minWomen == 4)
        #expect(r.maxWomen == 10)
        #expect(r.minMen == nil)
        #expect(r.maxMen == nil)
        #expect(r.updatedAt != nil)
    }

    // MARK: - Availability

    @Test func availabilityDecodes() throws {
        let json = #"""
        {"session_id":"77777777-7777-7777-7777-777777777777","paddler_id":"11111111-1111-1111-1111-111111111111","status":"maybe","note":null,"updated_at":"2026-08-25T07:14:00.1+00:00"}
        """#
        let a = try PostgREST.decoder.decode(Availability.self, from: Data(json.utf8))
        #expect(a.sessionId == "77777777-7777-7777-7777-777777777777")
        #expect(a.paddlerId == "11111111-1111-1111-1111-111111111111")
        #expect(a.status == .maybe)
        #expect(a.note == nil)
        #expect(a.updatedAt != nil)
    }

    @Test func availabilityRoundTripsThroughSharedEncoder() throws {
        let original = Availability(
            sessionId: "77777777-7777-7777-7777-777777777777",
            paddlerId: "11111111-1111-1111-1111-111111111111",
            status: .in,
            note: "running 10 late",
            updatedAt: PostgREST.parseDate("2026-08-25T07:14:00.123+00:00")
        )
        let data = try PostgREST.encoder.encode(original)
        let decoded = try PostgREST.decoder.decode(Availability.self, from: data)
        #expect(decoded == original)
    }

    // MARK: - ErgTest (covers the `date`-only column, no time component)

    @Test func ergTestDecodes() throws {
        let json = #"""
        {"id":"88888888-8888-8888-8888-888888888888","paddler_id":"11111111-1111-1111-1111-111111111111","tested_at":"2026-08-25","metres":512,"source":"coach","recorded_by":null,"created_at":"2026-08-25T07:14:00.123456+00:00"}
        """#
        let e = try PostgREST.decoder.decode(ErgTest.self, from: Data(json.utf8))
        #expect(e.id == "88888888-8888-8888-8888-888888888888")
        #expect(e.paddlerId == "11111111-1111-1111-1111-111111111111")
        #expect(e.metres == 512)
        #expect(e.source == .coach)
        #expect(e.recordedBy == nil)

        var comps = DateComponents()
        comps.calendar = Calendar(identifier: .gregorian)
        comps.timeZone = TimeZone(identifier: "UTC")
        comps.year = 2026; comps.month = 8; comps.day = 25
        let expected = comps.date!
        #expect(e.testedAt == expected)
    }

    @Test func ergTestDecodesSelfReportedSource() throws {
        let json = #"""
        {"id":"88888888-8888-8888-8888-888888888889","paddler_id":"11111111-1111-1111-1111-111111111111","tested_at":"2026-08-24","metres":498,"source":"self","recorded_by":null,"created_at":"2026-08-24T07:14:00+00:00"}
        """#
        let e = try PostgREST.decoder.decode(ErgTest.self, from: Data(json.utf8))
        #expect(e.source == .selfReported)
    }

    // MARK: - Shared date parsing behaviour

    @Test func parseDateHandlesMicrosecondFractionalSeconds() throws {
        let date = try #require(PostgREST.parseDate("2026-08-25T07:14:00.123456+00:00"))
        #expect(abs(date.timeIntervalSince1970 - 1787642040.123) < 0.01)
    }

    @Test func parseDateHandlesNoFractionalSeconds() throws {
        let date = try #require(PostgREST.parseDate("2026-08-25T07:14:00+00:00"))
        #expect(abs(date.timeIntervalSince1970 - 1787642040) < 0.01)
    }

    @Test func parseDateHandlesZuluSuffix() throws {
        #expect(PostgREST.parseDate("2026-08-25T07:14:00.123456Z") != nil)
    }

    @Test func parseDateHandlesDateOnly() throws {
        #expect(PostgREST.parseDate("2026-08-25") != nil)
    }

    @Test func parseDateRejectsGarbage() throws {
        #expect(PostgREST.parseDate("not-a-date") == nil)
    }
}

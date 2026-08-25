import Foundation
import Testing
@testable import Paddltir

@Suite struct ScheduleModelsTests {
    private let now = Date(timeIntervalSince1970: 1_700_000_000) // fixed reference

    private func session(_ id: String, _ offset: TimeInterval) -> SessionRow {
        SessionRow(id: id, clubId: "c", kind: .training, title: id, startsAt: now.addingTimeInterval(offset),
                   venue: nil, notes: nil, createdAt: now, updatedAt: nil)
    }
    private func avail(_ status: AvailabilityStatus) -> Availability {
        Availability(sessionId: "s", paddlerId: UUID().uuidString, status: status, note: nil, updatedAt: now)
    }

    @Test func headcountCountsAndDerivesNoReply() {
        let h = Headcount.compute(availability: [avail(.in), avail(.in), avail(.out), avail(.maybe)], squadSize: 10)
        #expect(h == Headcount(inCount: 2, outCount: 1, maybeCount: 1, noReplyCount: 6))
    }

    @Test func headcountNoReplyNeverNegative() {
        let h = Headcount.compute(availability: [avail(.in), avail(.in)], squadSize: 1) // more replies than squad
        #expect(h.noReplyCount == 0)
    }

    @Test func upNextIsSoonestFutureSession() {
        let s = [session("past", -3600), session("soon", 3600), session("later", 7200)]
        #expect(ScheduleGrouping.upNext(s, now: now)?.id == "soon")
    }

    @Test func upcomingAndPastSplitByDayDescendingPastAscendingUpcoming() {
        let s = [session("yesterday", -86_400), session("today-later", 3600), session("in-3-days", 3 * 86_400)]
        let up = ScheduleGrouping.upcoming(s, now: now)
        let past = ScheduleGrouping.past(s, now: now)
        #expect(up.flatMap(\.sessions).map(\.id) == ["today-later", "in-3-days"]) // soonest first
        #expect(past.flatMap(\.sessions).map(\.id) == ["yesterday"])
    }
}

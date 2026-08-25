// Pure, UI-free display logic for the Schedule tab: headcount math and the
// day-bucketing that splits sessions into up-next / upcoming / past. All
// deterministic given an injected `now`, so unit tests don't depend on the
// wall clock.
import Foundation

struct Headcount: Equatable {
    let inCount: Int
    let outCount: Int
    let maybeCount: Int
    let noReplyCount: Int

    /// "No reply" is squad members with no availability row; clamped at 0 so
    /// stray rows (e.g. an archived paddler still holding a reply) can't drive
    /// it negative.
    static func compute(availability: [Availability], squadSize: Int) -> Headcount {
        let i = availability.lazy.filter { $0.status == .in }.count
        let o = availability.lazy.filter { $0.status == .out }.count
        let m = availability.lazy.filter { $0.status == .maybe }.count
        return Headcount(inCount: i, outCount: o, maybeCount: m,
                         noReplyCount: max(0, squadSize - (i + o + m)))
    }
}

struct DaySection: Identifiable, Equatable {
    let id: Date      // start-of-day, unique per section
    let day: Date
    let sessions: [SessionRow]
}

enum ScheduleGrouping {
    /// The soonest session that hasn't started yet.
    static func upNext(_ sessions: [SessionRow], now: Date) -> SessionRow? {
        sessions.filter { $0.startsAt >= now }.min { $0.startsAt < $1.startsAt }
    }

    /// Future sessions, grouped by calendar day, soonest day first.
    static func upcoming(_ sessions: [SessionRow], now: Date) -> [DaySection] {
        group(sessions.filter { $0.startsAt >= now }.sorted { $0.startsAt < $1.startsAt })
    }

    /// Past sessions, grouped by calendar day, most-recent day first.
    static func past(_ sessions: [SessionRow], now: Date) -> [DaySection] {
        group(sessions.filter { $0.startsAt < now }.sorted { $0.startsAt > $1.startsAt })
    }

    private static func group(_ ordered: [SessionRow]) -> [DaySection] {
        var sections: [DaySection] = []
        let cal = Calendar.current
        for s in ordered {
            let day = cal.startOfDay(for: s.startsAt)
            if let last = sections.last, last.day == day {
                sections[sections.count - 1] = DaySection(id: day, day: day, sessions: last.sessions + [s])
            } else {
                sections.append(DaySection(id: day, day: day, sessions: [s]))
            }
        }
        return sections
    }
}

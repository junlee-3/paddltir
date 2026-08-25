// apple/Sources/Features/Schedule/ScheduleViewModel.swift
// Loads + composes the Schedule tab's state from the repositories and the
// pure ScheduleGrouping/Headcount helpers. @MainActor so the @Observable
// state mutates on the main actor for SwiftUI. `now` is injected so tests are
// deterministic; production uses `Date.init`.
import Foundation
import GRDB

@MainActor @Observable
final class ScheduleViewModel {
    private(set) var upNext: SessionRow?
    private(set) var upNextHeadcount: Headcount?
    private(set) var upcoming: [DaySection] = []
    private(set) var past: [DaySection] = []
    private(set) var squadSize = 0
    private(set) var clubId: String?
    private(set) var isLoading = false

    private let schedule: ScheduleRepository
    private let squad: SquadRepository
    private let db: AppDatabase
    private let now: () -> Date

    init(db: AppDatabase, now: @escaping () -> Date = Date.init) {
        self.db = db
        self.schedule = ScheduleRepository(db: db)
        self.squad = SquadRepository(db: db)
        self.now = now
    }

    func load() async {
        isLoading = true
        defer { isLoading = false }
        do {
            let sessions = try await schedule.sessions()
            let paddlers = try await squad.paddlers()
            clubId = try db.read { db in try Club.fetchOne(db)?.id }
            squadSize = paddlers.count
            let n = now()
            upNext = ScheduleGrouping.upNext(sessions, now: n)
            upcoming = ScheduleGrouping.upcoming(sessions.filter { $0.id != upNext?.id }, now: n)
            past = ScheduleGrouping.past(sessions, now: n)
            if let up = upNext { upNextHeadcount = await headcount(for: up.id) } else { upNextHeadcount = nil }
        } catch { /* offline-first: a read failure leaves the last good state */ }
    }

    func headcount(for sessionId: String) async -> Headcount {
        let availability = (try? await schedule.session(id: sessionId))?.availability ?? []
        return Headcount.compute(availability: availability, squadSize: squadSize)
    }

    func createTraining(title: String, startsAt: Date, venue: String?, notes: String?) async {
        await create(kind: .training, title: title, startsAt: startsAt, venue: venue, notes: notes)
    }

    func createRaceDay(title: String, startsAt: Date, venue: String?, notes: String?) async {
        await create(kind: .raceDay, title: title, startsAt: startsAt, venue: venue, notes: notes)
    }

    private func create(kind: SessionKind, title: String, startsAt: Date, venue: String?, notes: String?) async {
        guard let clubId else { return }
        _ = try? await schedule.createSession(clubId: clubId, kind: kind, title: title, startsAt: startsAt, venue: venue, notes: notes)
        await load()
    }
}

// apple/Sources/Features/Schedule/ScheduleViewModel.swift
// Composes the Schedule tab's state from ScheduleRepository's snapshot and
// the pure ScheduleGrouping/Headcount helpers. @MainActor so the
// @Observable state mutates on the main actor for SwiftUI. `now` is
// injected so tests are deterministic; production uses `Date.init`.
import Foundation
import GRDB

@MainActor @Observable
final class ScheduleViewModel {
    private(set) var upNext: SessionRow?
    private(set) var upNextHeadcount: Headcount?
    private(set) var upcoming: [DaySection] = []
    private(set) var past: [DaySection] = []
    private(set) var squadSize = 0
    private(set) var isLoaded = false
    private(set) var lastError: String?

    private let schedule: ScheduleRepository
    private let db: AppDatabase
    private let now: () -> Date

    init(db: AppDatabase, now: @escaping () -> Date = Date.init) {
        self.db = db
        self.schedule = ScheduleRepository(db: db)
        self.now = now
    }

    /// Long-lived: run from the view's `.task`. Every DB change re-emits.
    func observe() async {
        do {
            for try await snapshot in schedule.observeSchedule().values(in: db.dbQueue) { apply(snapshot) }
        } catch { lastError = error.localizedDescription }   // keep the last good state
    }

    /// One-shot (tests / previews).
    func load() async {
        do { apply(try await schedule.scheduleSnapshot()) } catch { lastError = error.localizedDescription }
    }

    private func apply(_ s: ScheduleRepository.ScheduleSnapshot) {
        let n = now()
        squadSize = s.squadSize
        upNext = ScheduleGrouping.upNext(s.sessions, now: n)
        upcoming = ScheduleGrouping.upcoming(s.sessions.filter { $0.id != upNext?.id }, now: n)
        past = ScheduleGrouping.past(s.sessions, now: n)
        upNextHeadcount = upNext.map { Headcount.compute(availability: s.availabilityBySession[$0.id] ?? [], squadSize: s.squadSize) }
        isLoaded = true
        lastError = nil
    }

    func createTraining(clubId: String, title: String, startsAt: Date, venue: String?, notes: String?) async {
        await create(clubId: clubId, kind: .training, title: title, startsAt: startsAt, venue: venue, notes: notes)
    }

    func createRaceDay(clubId: String, title: String, startsAt: Date, venue: String?, notes: String?) async {
        await create(clubId: clubId, kind: .raceDay, title: title, startsAt: startsAt, venue: venue, notes: notes)
    }

    private func create(clubId: String, kind: SessionKind, title: String, startsAt: Date, venue: String?, notes: String?) async {
        do { _ = try await schedule.createSession(clubId: clubId, kind: kind, title: title, startsAt: startsAt, venue: venue, notes: notes) }
        catch { lastError = error.localizedDescription }
        // No reload: the observation delivers the new session.
    }
}

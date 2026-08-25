// apple/Sources/Features/Squad/SquadViewModel.swift
// Composes the Squad tab's state from SquadRepository's roster query.
// @MainActor so the @Observable state mutates on the main actor for
// SwiftUI.
import Foundation
import GRDB

@MainActor @Observable
final class SquadViewModel {
    var filter = SquadFilter()
    var sort: SquadSort = .name
    private(set) var all: [PaddlerWithErg] = []
    private(set) var isLoaded = false
    private(set) var lastError: String?

    private let squad: SquadRepository
    private let db: AppDatabase

    init(db: AppDatabase) {
        self.db = db
        self.squad = SquadRepository(db: db)
    }

    var visible: [PaddlerWithErg] { SquadQuery.apply(all, filter: filter, sort: sort) }

    /// Long-lived: run from the view's `.task`. Every DB change re-emits.
    func observe() async {
        do {
            for try await rows in squad.observePaddlers().values(in: db.dbQueue) { all = rows; isLoaded = true; lastError = nil }
        } catch {
            lastError = error.localizedDescription
            isLoaded = true
        }
    }

    /// One-shot (tests / previews).
    func load() async {
        do { all = try await squad.paddlers(); isLoaded = true; lastError = nil } catch { lastError = error.localizedDescription }
    }

    func add(_ row: PaddlerRow) async {
        do { try await squad.upsert(row) } catch { lastError = error.localizedDescription }
        // No reload: the observation delivers the new/updated paddler.
    }
}

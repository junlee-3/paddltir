// LineupViewModel.swift
// Orchestrates the lineup editor over PaddltirCore. Holds the live `Lineup`
// value, a tap `selection`, and an undo/redo stack; every seat mutation goes
// through `mutate(_:)`, which snapshots for undo, clears the redo stack, and
// bumps `revision` (the haptics trigger). Placement itself always delegates
// to Lineup.place/.swap/.remove/.setLocked (which keep assignments
// canonical); balance/auto-fill/suggest delegate to PaddltirCore's
// Scoring/Greedy/Suggestions — no placement or scoring logic lives here.
// `observeHeats` mirrors a race's heats and drives `selectedHeatIndex`'s
// load-on-change; a race is born with its first heat
// (ScheduleRepository.createRace), so this never auto-creates one.
import Foundation
import GRDB
import PaddltirCore

@MainActor @Observable
final class LineupViewModel {
    enum Selection: Equatable { case reserve(PaddlerID); case seat(Seat) }

    private(set) var request: PlacementRequest?
    private(set) var lineup: Lineup?
    private(set) var heat: Heat?
    var selection: Selection?
    private(set) var canUndo = false
    private(set) var canRedo = false
    private(set) var isLoaded = false
    private(set) var lastError: String?
    /// Bumped by every real edit (`mutate`, `undo`, `redo`) — nothing else — so
    /// it can drive `.sensoryFeedback(trigger:)` without haptics firing on the
    /// initial load or a heat switch (both of which also replace `lineup`).
    private(set) var revision = 0

    private(set) var heats: [Heat] = []
    var selectedHeatIndex = 0 {
        didSet {
            guard let h = heats[safe: selectedHeatIndex], h.id != heat?.id else { return }
            Task { await load(heatId: h.id) }
        }
    }
    /// A heat just created by `addHeat` but not yet seen in an `observeHeats`
    /// emission — reconciled to a selection as soon as it appears (whichever
    /// order the write-then-observe lands in).
    private var pendingHeatId: String?

    private let db: AppDatabase
    private let repo: LineupRepository
    private var undoStack: [Lineup] = []
    private var redoStack: [Lineup] = []
    private var original: Lineup?   // reference for the `moves` metric

    init(db: AppDatabase) { self.db = db; self.repo = LineupRepository(db: db) }

    var roster: Roster? { request?.roster }
    var boat: Boat? { request?.boat }

    /// One-shot: the editor edits a local `Lineup` value, so a live
    /// observation would clobber unsaved edits — the view re-runs this
    /// explicitly (initial `.task`, a heat switch, or "Try again" on the
    /// empty state). `isLoaded` means "the load finished", whether or not a
    /// placement request resolved: `request`/`heat`/`lineup` stay nil when
    /// `heatId` genuinely has no crew to load (a legitimate empty state — the
    /// error case, below, is what selects the *other* empty state), never on
    /// a thrown read, which sets `lastError` instead so the two are never
    /// conflated.
    func load(heatId: String) async {
        do {
            guard let req = try await repo.placementRequest(heatId: heatId) else { isLoaded = true; return }
            let h = try await repo.heat(id: heatId)?.heat
            request = req
            heat = h
            lineup = req.current ?? Lineup(boat: req.boat, drummerId: req.drummerId, sweepId: req.sweepId)
            original = lineup
            undoStack = []; canUndo = false; redoStack = []; canRedo = false; selection = nil
            #if DEBUG
            if ProcessInfo.processInfo.environment["PADDLTIR_DEBUG_AUTOFILL"] == "1" { autoFill() }
            #endif
            isLoaded = true
        } catch {
            lastError = error.localizedDescription
            isLoaded = true
        }
    }

    /// Long-lived: mirrors the race's heats — a race is always born with one
    /// (`ScheduleRepository.createRace`), so an empty list is a legitimate state
    /// (a race whose only heat was since deleted), never auto-created here.
    ///
    /// Reconciles `selectedHeatIndex` on every emission: a heat `addHeat` just
    /// created (`pendingHeatId`) wins first, then the currently-loaded heat's new
    /// position (so a reorder keeps it selected without reloading — the `didSet`
    /// no-ops when the id already matches), then index 0 (nothing loaded yet, or
    /// the loaded heat vanished from the list).
    func observeHeats(raceId: String) async {
        do {
            for try await list in repo.observeHeats(raceId: raceId).values(in: db.dbQueue) {
                heats = list
                if list.isEmpty {
                    heat = nil; lineup = nil; request = nil
                    isLoaded = true
                    continue
                }
                if let pending = pendingHeatId, let i = list.firstIndex(where: { $0.id == pending }) {
                    pendingHeatId = nil
                    selectedHeatIndex = i
                } else if let i = list.firstIndex(where: { $0.id == heat?.id }) {
                    selectedHeatIndex = i
                } else {
                    selectedHeatIndex = 0
                }
            }
        } catch {
            lastError = error.localizedDescription
            isLoaded = true
        }
    }

    /// No explicit `load` here: `selectedHeatIndex`'s `didSet` loads the new heat
    /// exactly once, whichever order the write and the next `observeHeats`
    /// emission land in — if the emission already arrived, the new heat is in
    /// `heats` and we select it now; otherwise `pendingHeatId` catches it when
    /// the emission does arrive.
    func addHeat(raceId: String) async {
        do {
            let h = try await repo.createHeat(raceId: raceId)
            if let i = heats.firstIndex(where: { $0.id == h.id }) {
                selectedHeatIndex = i
            } else {
                pendingHeatId = h.id
            }
        } catch { lastError = error.localizedDescription }
    }

    /// Candidates not seated / drummer / sweep, strongest erg first.
    var reserves: [PaddlerID] {
        guard let request, let lineup, let roster else { return [] }
        var used = lineup.seatedIDs
        if let d = lineup.drummerId { used.insert(d) }
        if let s = lineup.sweepId { used.insert(s) }
        return request.candidates.filter { !used.contains($0) }
            .sorted { (roster.byID[$0]?.ergM ?? 0) > (roster.byID[$1]?.ergM ?? 0) }
    }

    /// F6: a locked seat resists every manual move — nothing is dropped onto one,
    /// its occupant can't be picked as a swap source, and it can't even become
    /// the tap-to-select source (`case nil`) in the first place. The coach
    /// unlocks first (the seat's own context menu).
    func tapSeat(_ seat: Seat) {
        guard let lineup else { return }
        switch selection {
        case .reserve(let id):
            selection = nil
            guard !lineup.isLocked(seat) else { return }
            mutate { l in
                if l.drummerId == id { l.drummerId = nil }
                if l.sweepId == id { l.sweepId = nil }
                l.place(id, at: seat)
            }
        case .seat(let s):
            selection = nil
            if s == seat { return }
            if lineup.paddler(at: s) == nil && lineup.paddler(at: seat) == nil { return }  // both empty → no-op
            guard !lineup.isLocked(s), !lineup.isLocked(seat) else { return }
            mutate { $0.swap(s, seat) }
        case nil:
            guard !lineup.isLocked(seat) else { return }
            selection = .seat(seat)   // pick a source (occupied or empty) to swap/fill
        }
    }

    func tapReserve(_ id: PaddlerID) {
        guard lineup != nil else { return }
        if case .seat(let s) = selection { mutate { $0.place(id, at: s) }; selection = nil }
        else { selection = (selection == .reserve(id)) ? nil : .reserve(id) }
    }

    func unseat(_ seat: Seat) { mutate { $0.remove(at: seat) }; selection = nil }

    func undo() {
        guard let prev = undoStack.popLast(), let current = lineup else { return }
        redoStack.append(current); canRedo = true
        lineup = prev; canUndo = !undoStack.isEmpty; selection = nil
        revision += 1
    }

    func redo() {
        guard let next = redoStack.popLast(), let current = lineup else { return }
        undoStack.append(current); canUndo = true
        lineup = next; canRedo = !redoStack.isEmpty; selection = nil
        revision += 1
    }

    /// Applies a mutation to `lineup`, snapshotting the prior value for undo
    /// and clearing the redo stack (a fresh edit invalidates any redo history).
    func mutate(_ change: (inout Lineup) -> Void) {
        guard var l = lineup else { return }
        undoStack.append(l); canUndo = true
        redoStack.removeAll(); canRedo = false
        change(&l); lineup = l
        revision += 1
    }

    /// Drag-and-drop: a reserve or a seated paddler dropped onto a seat.
    /// Seated → occupied = swap; seated → empty = move; reserve → any = place
    /// (an evicted occupant returns to the reserves). All via Lineup.
    ///
    /// H12: drops accept any `String` payload, so a drag from outside the app could
    /// carry an id that isn't in the roster — validated here, the VM's single choke
    /// point, so an unknown id is a no-op (no mutate, no undo entry, no save).
    ///
    /// F4: a paddler is never both seated and a cap — placing the current
    /// drummer/sweep into a seat clears that role in the same `mutate`.
    /// F6: nothing is dropped onto a locked seat, and a locked occupant can't
    /// be dragged elsewhere; both sides of a swap must be unlocked.
    func dragDrop(_ id: PaddlerID, onto seat: Seat) {
        guard roster?.byID[id] != nil else { return }
        guard let current = lineup else { return }
        guard !current.isLocked(seat) else { return }
        if let from = current.seat(of: id) {
            guard from != seat, !current.isLocked(from) else { return }
            if current.paddler(at: seat) != nil {
                mutate { $0.swap(from, seat) }
            } else {
                mutate { l in
                    if l.drummerId == id { l.drummerId = nil }
                    if l.sweepId == id { l.sweepId = nil }
                    l.place(id, at: seat)
                }
            }
        } else {
            mutate { l in
                if l.drummerId == id { l.drummerId = nil }
                if l.sweepId == id { l.sweepId = nil }
                l.place(id, at: seat)
            }
        }
        selection = nil
    }

    /// F6: dropping a locked occupant onto the reserves tray is a no-op — unlock first.
    func dropOnTray(_ id: PaddlerID) {
        guard roster?.byID[id] != nil else { return }
        guard let current = lineup, let seat = current.seat(of: id) else { return }
        guard !current.isLocked(seat) else { return }
        mutate { $0.remove(id) }; selection = nil
    }

    func toggleLock(_ seat: Seat) {
        guard let current = lineup, current.paddler(at: seat) != nil else { return }
        mutate { $0.setLocked(!current.isLocked(seat), at: seat) }
    }

    /// Drummer/sweep can't also hold a bench seat; assigning removes them from the hull.
    /// H12: same id validation as `dragDrop`/`dropOnTray` — `nil` (clearing the role) is
    /// always allowed, a non-nil id must resolve in the roster.
    func setDrummer(_ id: PaddlerID?) {
        guard id == nil || roster?.byID[id!] != nil else { return }
        mutate { l in if let id { l.remove(id); if l.sweepId == id { l.sweepId = nil } }; l.drummerId = id }
    }
    func setSweep(_ id: PaddlerID?) {
        guard id == nil || roster?.byID[id!] != nil else { return }
        mutate { l in if let id { l.remove(id); if l.drummerId == id { l.drummerId = nil } }; l.sweepId = id }
    }

    func save() async {
        guard let lineup, let heat else { return }
        let seats = lineup.assignments.map { a in
            SeatRow(heatId: heat.id, bench: a.bench, side: a.side == .left ? .left : .right,
                    paddlerId: a.paddlerId.rawValue, locked: a.locked, updatedAt: Date())
        }
        do {
            try await repo.saveSeats(heatId: heat.id, seats: seats)
            try await repo.saveHeat(heatId: heat.id, name: heat.name,
                                    drummerId: lineup.drummerId?.rawValue, sweepId: lineup.sweepId?.rawValue)
            lastError = nil
        } catch {
            lastError = error.localizedDescription
        }
    }

    var metrics: Metrics? {
        guard let lineup, let roster else { return nil }
        return Scoring.evaluate(lineup, roster: roster, reference: original)
    }

    /// Weight list for the balance beam: right-heavy positive, clamped to ±1.
    var beamImbalance: Double {
        guard let m = metrics else { return 0 }
        let half = max(1, m.totalWeight / 2)
        return max(-1, min(1, (m.weightRight - m.weightLeft) / half))
    }

    func autoFill() {
        guard let request, let lineup else { return }
        let req = PlacementRequest(boat: request.boat, roster: request.roster, candidates: request.candidates,
                                   drummerId: lineup.drummerId, sweepId: lineup.sweepId,
                                   locked: lineup.assignments.filter(\.locked), rule: request.rule, current: lineup)
        let result = Greedy.autoFill(req)
        mutate { $0 = result.lineup }
    }

    func suggestions() -> [SwapSuggestion] {
        guard let lineup, let roster else { return [] }
        return Suggestions.swaps(in: lineup, roster: roster, reference: original, limit: 3)
    }

    func apply(_ suggestion: SwapSuggestion) {
        mutate { $0.swap(suggestion.a, suggestion.b) }
    }

    #if DEBUG
    /// Test hook: inject a request + heat without a live DB round-trip.
    func _injectForTest(request: PlacementRequest, heat: Heat) {
        self.request = request; self.heat = heat
        self.lineup = request.current ?? Lineup(boat: request.boat)
        self.original = self.lineup
    }
    #endif
}

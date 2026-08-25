// apple/Sources/Features/Lineup/LineupEditorView.swift
// The hero screen. Glass heat-switcher header (multi-heat, with "+" to add
// another), the solid HullGrid (drag & drop, long-press context menu, spring
// motion + haptics on every change, section-banded bench rows), a glass
// Balance HUD (beam + telemetry + gender badge) driven by PaddltirCore on
// every change, a drop-target reserves strip (always present — it's the
// drop target for drag-to-unseat), and a glass toolbar (Suggest / Auto-fill /
// Undo / Redo). iPad/Mac get a centred hull + right-hand inspector column;
// iPhone keeps the vertical stack, sharing the same hull/HUD/tray views.
// Optimise (server MIP) is out of scope until the solver is deployed (go-live).
import SwiftUI
import PaddltirCore

struct LineupEditorView: View {
    let race: Race
    @State private var model: LineupViewModel
    @State private var showSuggestions = false

    #if os(iOS)
    @Environment(\.horizontalSizeClass) private var sizeClass
    #endif

    init(race: Race, db: AppDatabase) {
        self.race = race
        _model = State(initialValue: LineupViewModel(db: db))
    }

    /// iPad/Mac get the centred-hull + right-inspector layout; iPhone keeps the vertical stack.
    private var isWide: Bool {
        #if os(macOS)
        true
        #else
        sizeClass == .regular
        #endif
    }

    var body: some View {
        Group {
            if let lineup = model.lineup, let roster = model.roster, let boat = model.boat {
                content(model, lineup: lineup, roster: roster, boat: boat)
            } else if model.isLoaded && model.heats.isEmpty {
                noHeatsState(model)
            } else if model.isLoaded {
                ScreenScaffold("Lineup", note: "Couldn't load this race's crew. It may not have synced yet — go back and try again, or check the crew still exists.") {
                    SecondaryButton("Try again") {
                        if let h = model.heats[safe: model.selectedHeatIndex] {
                            Task { await model.load(heatId: h.id) }
                        }
                    }
                }
            } else {
                ProgressView()
            }
        }
        .navigationTitle(race.name)
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .background(DS.bg)
        .task { await model.observeHeats(raceId: race.id) }
    }

    /// F1: a race with no heats (its only one deleted elsewhere) is a legitimate
    /// state, not an error — the switcher stays visible so "+" still works.
    @ViewBuilder private func noHeatsState(_ model: LineupViewModel) -> some View {
        @Bindable var model = model
        ScreenScaffold("No heats yet", note: "Tap + to add the first heat for this race.") {
            HeatSwitcher(names: model.heats.map(\.name), selection: $model.selectedHeatIndex,
                         onAdd: { Task { await model.addHeat(raceId: race.id) } })
        }
    }

    @ViewBuilder private func content(_ model: LineupViewModel, lineup: Lineup, roster: Roster, boat: Boat) -> some View {
        @Bindable var model = model
        ScrollView {
            Group {
                if isWide {
                    HStack(alignment: .top, spacing: DS.Space.l) {
                        hullColumn(model, heatSelection: $model.selectedHeatIndex, lineup: lineup, roster: roster)
                            .frame(maxWidth: 560)
                        inspector(model, roster: roster, boat: boat)
                            .frame(width: 360)
                    }
                    .frame(maxWidth: .infinity)
                } else {
                    VStack(spacing: DS.Space.m) {
                        hullColumn(model, heatSelection: $model.selectedHeatIndex, lineup: lineup, roster: roster)
                        if let metrics = model.metrics { hud(model, metrics: metrics, boat: boat) }
                        reserves(model, roster: roster)
                        toolbar(model)
                    }
                }
            }
            .padding(DS.Space.l)
        }
        .sheet(isPresented: $showSuggestions) {
            SuggestionsSheet(model: model, roster: roster)
        }
    }

    /// The heat switcher above the hull, shared verbatim between the wide and narrow
    /// layouts so there is exactly one place that lays out the hull — and, per F3,
    /// exactly one place that surfaces a `save()`/`load()` failure, as its first element.
    @ViewBuilder private func hullColumn(_ model: LineupViewModel, heatSelection: Binding<Int>, lineup: Lineup, roster: Roster) -> some View {
        VStack(spacing: DS.Space.m) {
            if let e = model.lastError { StatusBanner(e).padding(.horizontal, DS.Space.l) }
            HeatSwitcher(names: model.heats.map(\.name), selection: heatSelection,
                         onAdd: { Task { await model.addHeat(raceId: race.id) } })
            HullGrid(lineup: lineup, roster: roster, selection: model.selection, actions: hullActions(model))
                .animation(.spring(response: 0.3, dampingFraction: 0.8), value: model.lineup)
                .sensoryFeedback(.impact(weight: .light), trigger: model.revision)
        }
    }

    /// Wide layout only: the Balance HUD + reserves + toolbar in a fixed-width column
    /// beside the centred hull.
    @ViewBuilder private func inspector(_ model: LineupViewModel, roster: Roster, boat: Boat) -> some View {
        VStack(alignment: .leading, spacing: DS.Space.m) {
            if let metrics = model.metrics { hud(model, metrics: metrics, boat: boat) }
            reserves(model, roster: roster)
            toolbar(model)
        }
    }

    @ViewBuilder private func hud(_ model: LineupViewModel, metrics: Metrics, boat: Boat) -> some View {
        GlassBar {
            VStack(alignment: .leading, spacing: DS.Space.s) {
                BalanceBeam(imbalance: model.beamImbalance, label: "Trim").frame(height: 20)
                TelemetryGrid(metrics: metrics, boat: boat)
                HStack {
                    MicroLabel("GENDER")
                    Spacer()
                    GenderBadge(metrics: metrics)
                }
            }
            .padding(DS.Space.m)
        }
    }

    /// H12: rendered unconditionally — it's the drop target for drag-to-unseat, needed
    /// most when the boat is full — with an empty-state sentence in the same container
    /// so the drop target keeps its size.
    @ViewBuilder private func reserves(_ model: LineupViewModel, roster: Roster) -> some View {
        VStack(alignment: .leading, spacing: DS.Space.s) {
            MicroLabel("RESERVES")
            if model.reserves.isEmpty {
                Text("No reserves — drag a paddler here to unseat")
                    .font(.dsFootnote)
                    .foregroundStyle(DS.ink3)
                    .frame(maxWidth: .infinity, minHeight: 40, alignment: .leading)
            } else {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 96))], spacing: DS.Space.s) {
                    ForEach(model.reserves, id: \.self) { id in
                        let p = roster.byID[id]
                        Button { model.tapReserve(id) } label: {
                            Text(p?.name ?? id.rawValue)
                                .font(.dsCaption).foregroundStyle(DS.ink)
                                .padding(.horizontal, DS.Space.s).padding(.vertical, DS.Space.xs)
                                .background(model.selection == .reserve(id) ? DS.accent.opacity(0.18) : DS.surface2, in: Capsule())
                                .overlay(Capsule().stroke(model.selection == .reserve(id) ? DS.accent : DS.border))
                        }
                        .buttonStyle(.plain)
                        .accessibilityAddTraits(model.selection == .reserve(id) ? .isSelected : [])
                        .draggable(id.rawValue)
                    }
                }
            }
        }
        .dropDestination(for: String.self) { items, _ in
            guard let raw = items.first else { return false }
            model.dropOnTray(PaddlerID(raw))
            Task { await model.save() }
            return true
        }
    }

    /// The hull's outbound actions: every one mirrors the tap flow — a VM call
    /// followed by a save — so drag/drop and the context menu persist exactly
    /// like the existing tap-to-place/swap interactions.
    private func hullActions(_ model: LineupViewModel) -> HullActions {
        HullActions(
            tap: { seat in model.tapSeat(seat); Task { await model.save() } },
            drop: { id, seat in model.dragDrop(id, onto: seat); Task { await model.save() } },
            unseat: { seat in model.unseat(seat); Task { await model.save() } },
            toggleLock: { seat in model.toggleLock(seat); Task { await model.save() } },
            setDrummer: { id in model.setDrummer(id); Task { await model.save() } },
            setSweep: { id in model.setSweep(id); Task { await model.save() } },
            clearDrummer: { model.setDrummer(nil); Task { await model.save() } },
            clearSweep: { model.setSweep(nil); Task { await model.save() } }
        )
    }

    private func toolbar(_ model: LineupViewModel) -> some View {
        GlassBar {
            HStack(spacing: DS.Space.l) {
                toolButton("Suggest", "wand.and.stars") { showSuggestions = true }
                    .disabled(model.suggestions().isEmpty)
                toolButton("Auto-fill", "sparkles") { model.autoFill(); Task { await model.save() } }
                toolButton("Undo", "arrow.uturn.backward") { model.undo(); Task { await model.save() } }
                    .disabled(!model.canUndo)
                toolButton("Redo", "arrow.uturn.forward") { model.redo(); Task { await model.save() } }
                    .disabled(!model.canRedo)
            }
            .padding(DS.Space.m)
        }
    }

    private func toolButton(_ label: String, _ icon: String, _ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 2) { Image(systemName: icon); Text(label).font(.dsMicro) }
                .foregroundStyle(DS.accent)
        }
        .buttonStyle(.plain)
    }
}

/// Ranked swap suggestions (`LineupViewModel.suggestions()`), each shown as the
/// two paddlers it would exchange; tapping a row applies that swap and saves.
private struct SuggestionsSheet: View {
    let model: LineupViewModel
    let roster: Roster
    @Environment(\.dismiss) private var dismiss

    private var suggestions: [SwapSuggestion] { model.suggestions() }

    var body: some View {
        NavigationStack {
            Group {
                if suggestions.isEmpty {
                    VStack(spacing: DS.Space.s) {
                        Image(systemName: "wand.and.stars").foregroundStyle(DS.ink3)
                        Text("No improving swaps right now.").font(.dsBody).foregroundStyle(DS.ink2)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List(suggestions, id: \.self) { suggestion in
                        Button {
                            model.apply(suggestion)
                            Task { await model.save() }
                            dismiss()
                        } label: {
                            row(suggestion)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .background(DS.bg)
            .navigationTitle("Suggestions")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Close") { dismiss() } }
            }
        }
    }

    private func row(_ suggestion: SwapSuggestion) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("\(name(at: suggestion.a)) ↔ \(name(at: suggestion.b))")
                    .font(.dsCallout).foregroundStyle(DS.ink)
                Text("Seats \(suggestion.a.description) and \(suggestion.b.description)")
                    .font(.dsMicro).foregroundStyle(DS.ink3)
            }
            Spacer()
            Pill(label(for: suggestion.improves))
        }
    }

    private func name(at seat: Seat) -> String {
        guard let id = model.lineup?.paddler(at: seat) else { return "Empty seat" }
        return roster.byID[id]?.name ?? id.rawValue
    }

    private func label(for improvement: Improvement) -> String {
        switch improvement {
        case .seated: "Seats a reserve"
        case .power: "Power"
        case .weight: "Weight"
        case .side: "Side pref"
        case .seat: "Seat fit"
        case .powerBalance: "Power balance"
        case .trim: "Trim"
        case .moves: "Fewer moves"
        }
    }
}

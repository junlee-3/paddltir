// apple/Sources/Features/Lineup/LineupEditorView.swift
// The hero screen. Glass heat-switcher header, the solid HullGrid, a glass
// Balance HUD (beam + telemetry + gender badge) driven by PaddltirCore on every
// change, a reserves strip, and a glass toolbar (Suggest / Auto-fill / Undo).
// Optimise (server MIP) is out of scope until the solver is deployed (go-live).
import SwiftUI
import PaddltirCore

struct LineupEditorView: View {
    let heatId: String
    let raceName: String
    @State private var model: LineupViewModel
    @State private var heatSelection = 0
    @State private var showSuggestions = false

    init(heatId: String, raceName: String, db: AppDatabase) {
        self.heatId = heatId
        self.raceName = raceName
        _model = State(initialValue: LineupViewModel(db: db))
    }

    var body: some View {
        Group {
            if let lineup = model.lineup, let roster = model.roster, let boat = model.boat {
                content(model, lineup: lineup, roster: roster, boat: boat)
            } else if model.isLoaded {
                ScreenScaffold("Lineup", note: "Couldn't load this race's crew. It may not have synced yet — go back and try again, or check the crew still exists.") {
                    SecondaryButton("Try again") { Task { await model.load(heatId: heatId) } }
                }
            } else {
                ProgressView()
            }
        }
        .navigationTitle(raceName)
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .background(DS.bg)
        .task { await model.load(heatId: heatId) }
    }

    @ViewBuilder private func content(_ model: LineupViewModel, lineup: Lineup, roster: Roster, boat: Boat) -> some View {
        ScrollView {
            VStack(spacing: DS.Space.m) {
                HeatSwitcher(names: [model.heat?.name ?? "Heat"], selection: $heatSelection)   // single heat for now; multi-heat nav is a later pass

                HullGrid(lineup: lineup, roster: roster, selection: model.selection) { seat in
                    model.tapSeat(seat); Task { await model.save() }
                }

                if let metrics = model.metrics {
                    GlassBar {
                        VStack(alignment: .leading, spacing: DS.Space.s) {
                            BalanceBeam(imbalance: model.beamImbalance, label: "Trim").frame(height: 20)
                            TelemetryGrid(metrics: metrics, boat: boat)
                            HStack {
                                MicroLabel("GENDER")
                                Spacer()
                                Text("W \(metrics.women) · M \(metrics.men)").font(.dsCaption.weight(.bold)).foregroundStyle(DS.ink)
                            }
                        }
                        .padding(DS.Space.m)
                    }
                }

                reserves(model, roster: roster)
                toolbar(model)
            }
            .padding(DS.Space.l)
        }
        .sheet(isPresented: $showSuggestions) {
            SuggestionsSheet(model: model, roster: roster)
        }
    }

    @ViewBuilder private func reserves(_ model: LineupViewModel, roster: Roster) -> some View {
        if !model.reserves.isEmpty {
            VStack(alignment: .leading, spacing: DS.Space.s) {
                MicroLabel("RESERVES")
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
                    }
                }
            }
        }
    }

    private func toolbar(_ model: LineupViewModel) -> some View {
        GlassBar {
            HStack(spacing: DS.Space.l) {
                toolButton("Suggest", "wand.and.stars") { showSuggestions = true }
                    .disabled(model.suggestions().isEmpty)
                toolButton("Auto-fill", "sparkles") { model.autoFill(); Task { await model.save() } }
                toolButton("Undo", "arrow.uturn.backward") { model.undo(); Task { await model.save() } }
                    .disabled(!model.canUndo)
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

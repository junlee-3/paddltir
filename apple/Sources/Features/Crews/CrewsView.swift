// apple/Sources/Features/Crews/CrewsView.swift
// Crews tab: crew cards (name, division/category pills, member count, next
// race) from CrewRepository.summaries; `+` creates a crew via CrewFormView;
// tapping a card pushes CrewDetailView.
import SwiftUI

@MainActor @Observable
final class CrewsViewModel {
    private(set) var summaries: [CrewRepository.CrewSummary] = []
    private(set) var isLoaded = false
    private(set) var lastError: String?

    private let crews: CrewRepository
    private let db: AppDatabase

    init(db: AppDatabase) {
        self.db = db
        self.crews = CrewRepository(db: db)
    }

    /// Long-lived: run from the view's `.task`. Every DB change re-emits.
    /// `now` is captured once, at subscription time (Ruling H5) — a stale
    /// "next race" cutoff within one long-lived observation is accepted.
    func observe() async {
        do {
            for try await rows in crews.observeSummaries(now: Date()).values(in: db.dbQueue) { summaries = rows; isLoaded = true; lastError = nil }
        } catch { lastError = error.localizedDescription }
    }

    /// One-shot (tests / previews).
    func load() async {
        do { summaries = try await crews.summaries(now: Date()); isLoaded = true } catch { lastError = error.localizedDescription }
    }

    func createCrew(clubId: String, name: String, division: String, category: CrewCategory) async {
        do { _ = try await crews.createCrew(clubId: clubId, name: name, ageDivision: division, category: category) }
        catch { lastError = error.localizedDescription }
        // No reload: the observation delivers the new crew.
    }
}

struct CrewsView: View {
    @Environment(AppModel.self) private var app
    @State private var model: CrewsViewModel
    @State private var adding = false

    init(db: AppDatabase) { _model = State(initialValue: CrewsViewModel(db: db)) }

    var body: some View {
        NavigationStack {
            content
                .navigationTitle("Crews")
                .background(DS.bg)
                .toolbar {
                    ToolbarItem(placement: .primaryAction) {
                        Button { adding = true } label: { Image(systemName: "plus") }
                            .disabled(app.environment.clubId == nil)
                    }
                }
                .navigationDestination(for: CrewRepository.CrewSummary.self) { s in CrewDetailView(crewId: s.crew.id) }
                .sheet(isPresented: $adding) {
                    if let clubId = app.environment.clubId {
                        CrewFormView(clubId: clubId) { name, div, cat in
                            await model.createCrew(clubId: clubId, name: name, division: div, category: cat)
                        }
                    } else {
                        VStack(spacing: DS.Space.m) {
                            Text("No club yet").font(.dsBody).foregroundStyle(DS.ink2)
                            Button("Close") { adding = false }.keyboardShortcut(.cancelAction)
                        }
                        .padding(DS.Space.l)
                    }
                }
        }
        .task { await model.observe() }
    }

    @ViewBuilder private var content: some View {
        if !model.isLoaded {
            ProgressView()
        } else {
            ScrollView {
                VStack(spacing: DS.Space.m) {
                    if model.summaries.isEmpty {
                        Text("No crews yet — tap + to add one.").font(.dsCaption).foregroundStyle(DS.ink3).padding(.top, DS.Space.xl)
                    }
                    ForEach(model.summaries) { s in
                        NavigationLink(value: s) {
                            HairlineCard {
                                VStack(alignment: .leading, spacing: DS.Space.xs) {
                                    Text(s.crew.name).font(.dsHeadline).foregroundStyle(DS.ink)
                                    HStack(spacing: DS.Space.s) {
                                        Pill(s.crew.ageDivision)
                                        Pill(s.crew.category.rawValue.capitalized)
                                        Text("\(s.memberCount) paddlers").font(.dsCaption).foregroundStyle(DS.ink3)
                                    }
                                    if let next = s.nextRaceName { Text("Next: \(next)").font(.dsCaption).foregroundStyle(DS.accent) }
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(DS.Space.l)
            }
        }
    }
}

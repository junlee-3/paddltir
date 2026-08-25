// apple/Sources/Features/Crews/CrewsView.swift
// Crews tab: crew cards (name, division/category pills, member count, next
// race) from CrewRepository.summaries; `+` creates a crew via CrewFormView;
// tapping a card pushes CrewDetailView.
import SwiftUI

@MainActor @Observable
final class CrewsViewModel {
    private(set) var summaries: [CrewRepository.CrewSummary] = []
    private(set) var clubId: String?
    private let crews: CrewRepository
    private let db: AppDatabase
    init(db: AppDatabase) { self.db = db; self.crews = CrewRepository(db: db) }

    func load() async {
        clubId = (try? db.read { db in try Club.fetchOne(db)?.id }) ?? nil
        summaries = (try? await crews.summaries(now: Date())) ?? []
    }
    func createCrew(name: String, division: String, category: CrewCategory) async {
        guard let clubId else { return }
        _ = try? await crews.createCrew(clubId: clubId, name: name, ageDivision: division, category: category)
        await load()
    }
}

struct CrewsView: View {
    @Environment(AppModel.self) private var app
    @State private var model: CrewsViewModel?
    @State private var adding = false

    var body: some View {
        NavigationStack {
            Group { if let model { content(model) } else { ProgressView() } }
                .navigationTitle("Crews")
                .background(DS.bg)
                .toolbar { ToolbarItem(placement: .primaryAction) { Button { adding = true } label: { Image(systemName: "plus") } } }
                .navigationDestination(for: CrewRepository.CrewSummary.self) { s in CrewDetailView(crewId: s.crew.id) }
                .sheet(isPresented: $adding) {
                    if let model, let clubId = model.clubId {
                        CrewFormView(clubId: clubId) { name, div, cat in await model.createCrew(name: name, division: div, category: cat) }
                    }
                }
        }
        .task {
            if model == nil { model = CrewsViewModel(db: app.environment.db) }
            await model?.load()
        }
    }

    @ViewBuilder private func content(_ model: CrewsViewModel) -> some View {
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

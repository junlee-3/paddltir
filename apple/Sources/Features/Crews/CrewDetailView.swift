// apple/Sources/Features/Crews/CrewDetailView.swift
// Crew detail: members (gender/side/weight/erg chips), the IDBF gender-rule
// check (women/men vs the crew's standard-boat rule, via PaddltirCore's
// GenderRule), add/remove from the squad, and the crew's races.
import SwiftUI
import PaddltirCore
import GRDB

@MainActor @Observable
final class CrewDetailModel {
    let crewId: String
    private(set) var crew: Crew?
    private(set) var members: [PaddlerWithErg] = []
    private(set) var races: [Race] = []
    private(set) var squad: [PaddlerWithErg] = []
    private(set) var ruleVerdict: String?    // nil = OK or no rule
    private(set) var tally = GenderTally(women: 0, men: 0)

    private let crews: CrewRepository
    private let squadRepo: SquadRepository
    private let db: AppDatabase
    init(crewId: String, db: AppDatabase) {
        self.crewId = crewId; self.db = db
        self.crews = CrewRepository(db: db); self.squadRepo = SquadRepository(db: db)
    }

    var memberIds: Set<String> { Set(members.map(\.row.id)) }

    func load() async {
        let loaded = try? await crews.crew(id: crewId)
        crew = loaded?.crew
        members = loaded?.members ?? []
        races = (try? await crews.racesForCrew(crewId: crewId)) ?? []
        squad = (try? await squadRepo.paddlers()) ?? []
        tally = GenderTally.of(members)
        if let crew {
            let rule = try? db.read { db -> GenderRule? in
                let key: [String: (any DatabaseValueConvertible)?] = ["club_id": crew.clubId, "category": crew.category.rawValue, "boat_size": BoatSize.standard.rawValue]
                return DomainMapping.genderRule(try CategoryRule.fetchOne(db, key: key))
            } ?? nil
            ruleVerdict = rule?.violation(women: tally.women, men: tally.men)
        }
    }

    func toggle(_ paddlerId: String) async {
        var ids = memberIds
        if ids.contains(paddlerId) { ids.remove(paddlerId) } else { ids.insert(paddlerId) }
        try? await crews.setMembers(crewId: crewId, paddlerIds: Array(ids))
        await load()
    }
}

struct CrewDetailView: View {
    let crewId: String
    @Environment(AppModel.self) private var app
    @State private var model: CrewDetailModel?
    @State private var addingMembers = false
    @State private var didLoad = false

    var body: some View {
        Group {
            if let model, model.crew != nil {
                content(model)
            } else if didLoad {
                ScreenScaffold("Not found", note: "This record is no longer available.")
            } else {
                ProgressView()
            }
        }
            .navigationTitle(model?.crew?.name ?? "Crew")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .background(DS.bg)
            .task {
                if model == nil { model = CrewDetailModel(crewId: crewId, db: app.environment.db) }
                await model?.load()
                didLoad = true
            }
            .sheet(isPresented: $addingMembers) { if let model { memberPicker(model) } }
    }

    @ViewBuilder private func content(_ model: CrewDetailModel) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DS.Space.m) {
                HairlineCard {
                    HStack {
                        Text("W \(model.tally.women) · M \(model.tally.men)").font(.dsHeadline).foregroundStyle(DS.ink)
                        Spacer()
                        if let why = model.ruleVerdict {
                            Text(why).font(.dsCaption).foregroundStyle(DS.danger)
                        } else {
                            Text("Within rule").font(.dsCaption).foregroundStyle(DS.good)
                        }
                    }
                }
                HStack { MicroLabel("MEMBERS"); Spacer(); Button("Edit") { addingMembers = true }.font(.dsCaption).foregroundStyle(DS.accent) }
                ForEach(model.members) { pw in memberRow(pw) }
                if !model.races.isEmpty {
                    MicroLabel("RACES")
                    ForEach(model.races, id: \.id) { race in
                        HairlineCard { Text("\(race.name) · \(race.boatSize == .standard ? "Standard" : "Small")").font(.dsCallout).foregroundStyle(DS.ink2) }
                    }
                }
            }
            .padding(DS.Space.l)
        }
    }

    private func memberRow(_ pw: PaddlerWithErg) -> some View {
        HairlineCard {
            HStack {
                Text(pw.row.name).font(.dsBody).foregroundStyle(DS.ink)
                Spacer()
                Pill(pw.row.gender == .female ? "F" : "M", tint: pw.row.gender == .female ? DS.femaleFill : DS.maleFill)
                Text("\(pw.row.weightKg, specifier: "%.0f")kg").font(.dsCaption).foregroundStyle(DS.ink3)
                if let m = pw.latestErg?.metres { Text("\(m)m").font(.dsCaption).foregroundStyle(DS.ink3).monospacedDigit() }
            }
        }
    }

    private func memberPicker(_ model: CrewDetailModel) -> some View {
        NavigationStack {
            List(model.squad) { pw in
                Button { Task { await model.toggle(pw.row.id) } } label: {
                    HStack {
                        Text(pw.row.name).foregroundStyle(DS.ink)
                        Spacer()
                        if model.memberIds.contains(pw.row.id) { Image(systemName: "checkmark").foregroundStyle(DS.accent) }
                    }
                }
                .buttonStyle(.plain)
            }
            .navigationTitle("Members")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
        }
    }
}

// apple/Sources/Features/Crews/CrewDetailView.swift
// Crew detail: members (gender/side/weight/erg chips), the IDBF gender-rule
// check (women/men vs the crew's standard-boat rule, via PaddltirCore's
// GenderRule), add/remove from the squad, and the crew's races.
import SwiftUI
import PaddltirCore

@MainActor @Observable
final class CrewDetailModel {
    let crewId: String
    private(set) var crew: Crew?
    private(set) var members: [PaddlerWithErg] = []
    private(set) var races: [Race] = []
    private(set) var squad: [PaddlerWithErg] = []
    private(set) var ruleVerdict: String?    // nil = OK or no rule
    private(set) var tally = GenderTally(women: 0, men: 0)
    private(set) var isLoaded = false
    private(set) var lastError: String?

    private let crews: CrewRepository
    private let db: AppDatabase

    init(crewId: String, db: AppDatabase) {
        self.crewId = crewId; self.db = db; self.crews = CrewRepository(db: db)
    }

    var memberIds: Set<String> { Set(members.map(\.row.id)) }

    /// Long-lived: run from the view's `.task`. Every DB change re-emits.
    func observe() async {
        do { for try await detail in crews.observeCrewDetail(id: crewId).values(in: db.dbQueue) { apply(detail) } }
        catch {
            lastError = error.localizedDescription
            isLoaded = true
        }
    }

    /// One-shot (tests / previews). `CrewGenderRuleTests` calls this directly.
    func load() async {
        do { apply(try db.read { try CrewRepository.fetchCrewDetail($0, id: crewId) }) } catch { lastError = error.localizedDescription }
    }

    private func apply(_ d: CrewRepository.CrewDetail) {
        crew = d.crew; members = d.members; races = d.races; squad = d.squad
        tally = GenderTally.of(d.members)
        ruleVerdict = d.rule?.violation(women: tally.women, men: tally.men)
        isLoaded = true; lastError = nil
    }

    func toggle(_ paddlerId: String) async {
        var ids = memberIds
        if ids.contains(paddlerId) { ids.remove(paddlerId) } else { ids.insert(paddlerId) }
        do { try await crews.setMembers(crewId: crewId, paddlerIds: Array(ids)) } catch { lastError = error.localizedDescription }
        // No reload: the observation delivers the new membership.
    }
}

struct CrewDetailView: View {
    let crewId: String
    @State private var model: CrewDetailModel
    @State private var addingMembers = false

    init(crewId: String, db: AppDatabase) {
        self.crewId = crewId
        _model = State(initialValue: CrewDetailModel(crewId: crewId, db: db))
    }

    var body: some View {
        Group {
            if model.crew != nil {
                content(model)
            } else if model.isLoaded {
                notFoundState(model)
            } else {
                ProgressView()
            }
        }
            .navigationTitle(model.crew?.name ?? "Crew")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .background(DS.bg)
            .task { await model.observe() }
            .sheet(isPresented: $addingMembers) { memberPicker(model) }
    }

    /// F2 (follow-up): a genuine "not found" (no `crew` row, no error) still gets the
    /// plain empty state; a failed first read (`lastError != nil`) surfaces its banner
    /// above it, so a real failure is never presented as "this record doesn't exist".
    @ViewBuilder private func notFoundState(_ model: CrewDetailModel) -> some View {
        VStack(spacing: DS.Space.m) {
            if let e = model.lastError { StatusBanner(e).padding(.horizontal, DS.Space.xl) }
            ScreenScaffold("Not found", note: "This record is no longer available.")
        }
    }

    @ViewBuilder private func content(_ model: CrewDetailModel) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DS.Space.m) {
                if let e = model.lastError { StatusBanner(e) }
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

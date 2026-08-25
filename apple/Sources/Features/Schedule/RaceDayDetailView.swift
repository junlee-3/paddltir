// apple/Sources/Features/Schedule/RaceDayDetailView.swift
// Race-day detail: the day's headcount summary, the list of races (crew ·
// boat size · distance), and `+ Race`. Tapping a race navigates toward the
// lineup editor (a placeholder until Plan 4f builds it).
import SwiftUI

@MainActor @Observable
final class RaceDayModel {
    let session: SessionRow
    private(set) var races: [Race] = []
    private(set) var crews: [Crew] = []
    private(set) var crewNames: [String: String] = [:]   // crewId -> name
    private(set) var headcount = Headcount(inCount: 0, outCount: 0, maybeCount: 0, noReplyCount: 0)
    private(set) var isLoaded = false
    private(set) var lastError: String?
    private let schedule: ScheduleRepository
    private let db: AppDatabase

    init(session: SessionRow, db: AppDatabase) {
        self.session = session
        self.db = db
        self.schedule = ScheduleRepository(db: db)
    }

    /// Long-lived: run from the view's `.task`. Every DB change re-emits.
    func observe() async {
        do { for try await snap in schedule.observeRaceDay(sessionId: session.id).values(in: db.dbQueue) { apply(snap) } }
        catch { lastError = error.localizedDescription }
    }

    private func apply(_ s: ScheduleRepository.RaceDaySnapshot) {
        races = s.races
        crews = s.crews
        crewNames = Dictionary(uniqueKeysWithValues: s.crews.map { ($0.id, $0.name) })
        headcount = Headcount.compute(availability: s.availability, squadSize: s.squadSize)
        isLoaded = true; lastError = nil
    }

    func addRace(crewId: String, name: String, boatSize: BoatSize, distanceM: Int?) async {
        do { _ = try await schedule.createRace(sessionId: session.id, crewId: crewId, name: name, boatSize: boatSize, distanceM: distanceM) }
        catch { lastError = error.localizedDescription }
        // No reload: the observation delivers the new race.
    }
}

struct RaceDayDetailView: View {
    let session: SessionRow
    let db: AppDatabase
    @State private var model: RaceDayModel
    @State private var addingRace = false

    init(session: SessionRow, db: AppDatabase) {
        self.session = session
        self.db = db
        _model = State(initialValue: RaceDayModel(session: session, db: db))
    }

    var body: some View {
        Group {
            if model.isLoaded { content(model) } else { ProgressView() }
        }
        .navigationTitle(session.title)
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .background(DS.bg)
        .toolbar {
            ToolbarItem(placement: .primaryAction) { Button { addingRace = true } label: { Image(systemName: "plus") } }
        }
        .sheet(isPresented: $addingRace) {
            RaceFormView(crews: model.crews) { crewId, name, size, dist in
                await model.addRace(crewId: crewId, name: name, boatSize: size, distanceM: dist)
            }
        }
        .navigationDestination(for: Race.self) { race in RaceHeatLoader(race: race, db: db) }
        .task { await model.observe() }
    }

    @ViewBuilder private func content(_ model: RaceDayModel) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DS.Space.m) {
                if let e = model.lastError { StatusBanner(e) }
                HairlineCard {
                    Text("\(model.headcount.inCount) in · \(model.headcount.outCount) out · \(model.headcount.maybeCount) maybe · \(model.headcount.noReplyCount) no reply")
                        .font(.dsCallout).foregroundStyle(DS.ink2)
                }
                MicroLabel("RACES")
                if model.races.isEmpty {
                    Text("No races yet — tap + to add one.").font(.dsCaption).foregroundStyle(DS.ink3)
                }
                ForEach(model.races, id: \.id) { race in
                    NavigationLink(value: race) {
                        HairlineCard {
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(race.name).font(.dsHeadline).foregroundStyle(DS.ink)
                                    Text("\(model.crewNames[race.crewId] ?? "Crew") · \(race.boatSize == .standard ? "Standard" : "Small")\(race.distanceM.map { " · \($0)m" } ?? "")")
                                        .font(.dsCaption).foregroundStyle(DS.ink3)
                                }
                                Spacer()
                                Image(systemName: "chevron.right").foregroundStyle(DS.ink3)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(DS.Space.l)
        }
    }
}

/// Add-race form: pick a crew, boat size, optional distance.
struct RaceFormView: View {
    let crews: [Crew]
    let onCreate: (_ crewId: String, _ name: String, _ boatSize: BoatSize, _ distanceM: Int?) async -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var crewId = ""
    @State private var boatSize: BoatSize = .standard
    @State private var distanceText = ""

    var body: some View {
        NavigationStack {
            Form {
                TextField("Race name (e.g. Heat A)", text: $name)
                Picker("Crew", selection: $crewId) {
                    Text("Select…").tag("")
                    ForEach(crews, id: \.id) { Text($0.name).tag($0.id) }
                }
                Picker("Boat size", selection: $boatSize) {
                    Text("Standard").tag(BoatSize.standard); Text("Small").tag(BoatSize.small)
                }
                TextField("Distance (m)", text: $distanceText)
                    #if os(iOS)
                    .keyboardType(.numberPad)
                    #endif
            }
            .navigationTitle("Add race")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        Task { await onCreate(crewId, name.trimmingCharacters(in: .whitespaces), boatSize, Int(distanceText)); dismiss() }
                    }
                    .disabled(crewId.isEmpty || name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }
}

/// Resolves a `Race` to its first heat — creating one ("Heat 1") if the race
/// has none yet — then shows the lineup editor for it. A race may have 0+
/// heats; this is the simplest correct wiring until multi-heat navigation
/// (switching among a race's existing heats) lands in a later pass.
struct RaceHeatLoader: View {
    let race: Race
    let db: AppDatabase
    @State private var heatId: String?
    @State private var isResolved = false
    @State private var failed = false

    var body: some View {
        Group {
            if let heatId {
                LineupEditorView(heatId: heatId, raceName: race.name, db: db)
            } else if failed {
                ScreenScaffold("Lineup", note: "Couldn't open the lineup.")
            } else {
                ProgressView()
            }
        }
        .task {
            guard !isResolved else { return }
            let repo = LineupRepository(db: db)
            if let first = (try? await repo.heats(raceId: race.id))?.first {
                heatId = first.id
            } else if let created = try? await repo.createHeat(raceId: race.id, name: "Heat 1") {
                heatId = created.id
            } else {
                failed = true
            }
            isResolved = true
        }
    }
}

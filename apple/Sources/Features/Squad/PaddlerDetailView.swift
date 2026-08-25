// apple/Sources/Features/Squad/PaddlerDetailView.swift
// Paddler detail: fields, an erg-history sparkline (Swift Charts), invite/link
// status, edit, and archive (never delete).
import SwiftUI
import Charts

@MainActor @Observable
final class PaddlerDetailModel {
    let paddlerId: String
    private(set) var paddler: PaddlerWithErg?
    private(set) var ergHistory: [ErgTest] = []
    private(set) var isLoaded = false
    private(set) var lastError: String?
    private let squad: SquadRepository
    private let db: AppDatabase

    init(paddlerId: String, db: AppDatabase) {
        self.paddlerId = paddlerId; self.db = db; self.squad = SquadRepository(db: db)
    }

    /// Long-lived: run from the view's `.task`. Every DB change re-emits.
    func observe() async {
        do { for try await detail in squad.observePaddlerDetail(id: paddlerId).values(in: db.dbQueue) { apply(detail) } }
        catch { lastError = error.localizedDescription }
    }

    private func apply(_ d: SquadRepository.PaddlerDetail) {
        paddler = d.paddler
        ergHistory = d.ergHistory
        isLoaded = true; lastError = nil
    }

    func save(_ row: PaddlerRow) async {
        do { _ = try await squad.upsert(row) } catch { lastError = error.localizedDescription }
        // No reload: the observation delivers the updated paddler.
    }

    func archive() async {
        do { try await squad.archive(id: paddlerId) } catch { lastError = error.localizedDescription }
        // No reload: the view dismisses after this call — the observation
        // would otherwise leave the (now archived) paddler on screen.
    }
}

struct PaddlerDetailView: View {
    let paddlerId: String
    @Environment(AppModel.self) private var app
    @Environment(\.dismiss) private var dismiss
    @State private var model: PaddlerDetailModel
    @State private var editing = false

    init(paddlerId: String, db: AppDatabase) {
        self.paddlerId = paddlerId
        _model = State(initialValue: PaddlerDetailModel(paddlerId: paddlerId, db: db))
    }

    var body: some View {
        Group {
            if let pw = model.paddler {
                content(model, pw)
            } else if model.isLoaded {
                ScreenScaffold("Not found", note: "This record is no longer available.")
            } else {
                ProgressView()
            }
        }
            .navigationTitle(model.paddler?.row.name ?? "Paddler")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .background(DS.bg)
            .task { await model.observe() }
    }

    @ViewBuilder private func content(_ model: PaddlerDetailModel, _ pw: PaddlerWithErg) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DS.Space.m) {
                HairlineCard {
                    VStack(alignment: .leading, spacing: DS.Space.s) {
                        HStack {
                            Pill(pw.row.gender == .female ? "Female" : "Male",
                                 tint: pw.row.gender == .female ? DS.femaleFill : DS.maleFill)
                            Pill(pw.row.preferredSide.rawValue.capitalized)
                            Pill(pw.row.seatPreference.rawValue.capitalized)
                            Pill(pw.row.boatRole.rawValue.capitalized)
                        }
                        Text("\(pw.row.weightKg, specifier: "%.0f") kg").font(.dsHeadline).foregroundStyle(DS.ink)
                        Text(pw.row.profileId != nil ? "Linked" : (pw.row.email != nil ? "Invitable" : "No email"))
                            .font(.dsCaption).foregroundStyle(pw.row.profileId != nil ? DS.good : DS.ink3)
                    }
                }
                if !model.ergHistory.isEmpty {
                    MicroLabel("ERG HISTORY")
                    HairlineCard {
                        Chart(model.ergHistory, id: \.id) { e in
                            LineMark(x: .value("Date", e.testedAt), y: .value("Metres", e.metres))
                                .foregroundStyle(DS.accent)
                        }
                        .frame(height: 120)
                    }
                }
                Button("Edit") { editing = true }.foregroundStyle(DS.accent)
                Button("Archive", role: .destructive) { Task { await model.archive(); dismiss() } }
            }
            .padding(DS.Space.l)
        }
        .sheet(isPresented: $editing) {
            if let clubId = app.environment.clubId {
                PaddlerFormView(clubId: clubId, existing: pw.row) { row in await model.save(row) }
            } else {
                VStack(spacing: DS.Space.m) {
                    Text("No club yet").font(.dsBody).foregroundStyle(DS.ink2)
                    Button("Close") { editing = false }.keyboardShortcut(.cancelAction)
                }
                .padding(DS.Space.l)
            }
        }
    }
}

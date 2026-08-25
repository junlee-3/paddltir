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
    private let squad: SquadRepository
    let clubId: String

    init(paddlerId: String, db: AppDatabase, clubId: String) {
        self.paddlerId = paddlerId; self.squad = SquadRepository(db: db); self.clubId = clubId
    }
    func load() async {
        paddler = try? await squad.paddler(id: paddlerId)
        ergHistory = (try? await squad.ergHistory(paddlerId: paddlerId)) ?? []
    }
    func save(_ row: PaddlerRow) async { _ = try? await squad.upsert(row); await load() }
    func archive() async { try? await squad.archive(id: paddlerId); await load() }
}

struct PaddlerDetailView: View {
    let paddlerId: String
    @Environment(AppModel.self) private var app
    @Environment(\.dismiss) private var dismiss
    @State private var model: PaddlerDetailModel?
    @State private var editing = false

    var body: some View {
        Group { if let model, let pw = model.paddler { content(model, pw) } else { ProgressView() } }
            .navigationTitle(model?.paddler?.row.name ?? "Paddler")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .background(DS.bg)
            .task {
                if model == nil {
                    let clubId = ((try? app.environment.db.read { db in try Club.fetchOne(db)?.id }) ?? nil) ?? ""
                    model = PaddlerDetailModel(paddlerId: paddlerId, db: app.environment.db, clubId: clubId)
                }
                await model?.load()
            }
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
            PaddlerFormView(clubId: model.clubId, existing: pw.row) { row in await model.save(row) }
        }
    }
}

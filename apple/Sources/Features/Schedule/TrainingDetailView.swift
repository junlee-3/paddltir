// apple/Sources/Features/Schedule/TrainingDetailView.swift
// Training-session detail: a headcount summary, then every squad paddler with
// their availability (In/Out/Maybe or "No reply"). The coach overrides a
// paddler's status inline (writes availability), and a per-paddler menu opens
// a record-erg sheet.
import SwiftUI

/// `.sheet(item:)` needs `Identifiable`; `PaddlerWithErg` (Data/Repositories)
/// is only `Hashable, Sendable` — the paddler row's id is a stable identity.
extension PaddlerWithErg: Identifiable { var id: String { row.id } }

@MainActor @Observable
final class TrainingDetailModel {
    let session: SessionRow
    private(set) var paddlers: [PaddlerWithErg] = []
    private(set) var availability: [String: Availability] = [:]   // paddlerId -> row
    private(set) var isLoaded = false
    private(set) var lastError: String?
    private let schedule: ScheduleRepository
    private let squad: SquadRepository
    private let db: AppDatabase

    init(session: SessionRow, db: AppDatabase) {
        self.session = session
        self.db = db
        self.schedule = ScheduleRepository(db: db)
        self.squad = SquadRepository(db: db)
    }

    var headcount: Headcount { Headcount.compute(availability: Array(availability.values), squadSize: paddlers.count) }

    /// Long-lived: run from the view's `.task`. Every DB change re-emits.
    func observe() async {
        do { for try await detail in schedule.observeTrainingDetail(sessionId: session.id).values(in: db.dbQueue) { apply(detail) } }
        catch {
            lastError = error.localizedDescription
            isLoaded = true
        }
    }

    private func apply(_ d: ScheduleRepository.TrainingDetail) {
        paddlers = d.paddlers
        availability = Dictionary(uniqueKeysWithValues: d.availability.map { ($0.paddlerId, $0) })
        isLoaded = true; lastError = nil
    }

    func setStatus(_ status: AvailabilityStatus, for paddlerId: String) async {
        do {
            try await schedule.setAvailability(sessionId: session.id, paddlerId: paddlerId, status: status,
                                               note: availability[paddlerId]?.note)
        } catch { lastError = error.localizedDescription }
        // No reload: the observation delivers the new availability.
    }

    func recordErg(paddlerId: String, metres: Int) async {
        do { _ = try await squad.recordErg(paddlerId: paddlerId, metres: metres, testedAt: Date(), recordedBy: nil) }
        catch { lastError = error.localizedDescription }
        // No reload: the observation delivers the new erg test.
    }
}

struct TrainingDetailView: View {
    let session: SessionRow
    @State private var model: TrainingDetailModel
    @State private var ergTarget: PaddlerWithErg?

    init(session: SessionRow, db: AppDatabase) {
        self.session = session
        _model = State(initialValue: TrainingDetailModel(session: session, db: db))
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
        .task { await model.observe() }
        .sheet(item: $ergTarget) { target in
            RecordErgSheet(paddlerName: target.row.name) { metres in
                await model.recordErg(paddlerId: target.row.id, metres: metres)
            }
        }
    }

    @ViewBuilder private func content(_ model: TrainingDetailModel) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DS.Space.m) {
                if let e = model.lastError { StatusBanner(e) }
                headcountCard(model.headcount)
                ForEach(model.paddlers, id: \.row.id) { p in
                    availabilityRow(p, status: model.availability[p.row.id]?.status, model: model)
                }
            }
            .padding(DS.Space.l)
        }
    }

    private func headcountCard(_ h: Headcount) -> some View {
        HairlineCard {
            HStack(spacing: DS.Space.l) {
                AvailabilityRing(count: h.inCount, total: max(1, h.inCount + h.outCount + h.maybeCount + h.noReplyCount))
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(h.inCount) in · \(h.outCount) out · \(h.maybeCount) maybe").font(.dsHeadline).foregroundStyle(DS.ink)
                    Text("\(h.noReplyCount) no reply").font(.dsCaption).foregroundStyle(DS.ink3)
                }
                Spacer()
            }
        }
    }

    private func availabilityRow(_ p: PaddlerWithErg, status: AvailabilityStatus?, model: TrainingDetailModel) -> some View {
        HairlineCard {
            HStack {
                Text(p.row.name).font(.dsBody).foregroundStyle(DS.ink)
                Spacer()
                ForEach([AvailabilityStatus.in, .maybe, .out], id: \.self) { s in
                    Button {
                        Task { await model.setStatus(s, for: p.row.id) }
                    } label: {
                        Text(label(s))
                            .font(.dsCaption)
                            .padding(.horizontal, DS.Space.s).padding(.vertical, DS.Space.xs)
                            .background(status == s ? tint(s).opacity(0.18) : DS.surface2, in: Capsule())
                            .foregroundStyle(status == s ? tint(s) : DS.ink3)
                    }
                    .buttonStyle(.plain)
                }
                Menu {
                    Button("Record erg test…") { ergTarget = p }
                } label: { Image(systemName: "ellipsis.circle").foregroundStyle(DS.ink3) }
            }
        }
    }

    private func label(_ s: AvailabilityStatus) -> String { s == .in ? "In" : s == .out ? "Out" : "Maybe" }
    private func tint(_ s: AvailabilityStatus) -> Color { s == .in ? DS.good : s == .out ? DS.danger : DS.accent }
}

/// Compact erg-entry sheet.
struct RecordErgSheet: View {
    let paddlerName: String
    let onSave: (_ metres: Int) async -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var metresText = ""

    var body: some View {
        NavigationStack {
            Form {
                Section { TextField("Metres in 2 min", text: $metresText)
                    #if os(iOS)
                    .keyboardType(.numberPad)
                    #endif
                } header: { MicroLabel("ERG — \(paddlerName.uppercased())") }
            }
            .navigationTitle("Record erg")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        Task { if let m = Int(metresText) { await onSave(m) }; dismiss() }
                    }
                    .disabled(Int(metresText) == nil)
                }
            }
        }
    }
}

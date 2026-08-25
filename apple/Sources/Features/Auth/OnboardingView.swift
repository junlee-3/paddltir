// OnboardingView.swift
// Signed-in-but-no-club screen: create a club, or join one with an invite
// code and (optionally) claim your name from the roster. Mirrors AuthView's
// shape — a MainActor @Observable view model owns the async RPC calls and
// pure validation; the view is a thin chooser/create/join switch.
import SwiftUI
import Supabase

@MainActor @Observable
final class OnboardingViewModel {
    enum Mode { case chooser, create, join }
    var mode: Mode = .chooser
    var clubName = ""
    var code = ""
    var claimables: [ClaimablePaddler] = []
    var selectedPaddlerID: String?
    var errorText: String?
    var isBusy = false

    private let clubs: ClubService
    private let onFinished: () async -> Void

    init(client: SupabaseClient, onFinished: @escaping () async -> Void) {
        self.clubs = ClubService(client: client)
        self.onFinished = onFinished
    }

    var canCreate: Bool { !clubName.trimmingCharacters(in: .whitespaces).isEmpty }
    func normalizedCode() -> String {
        code.trimmingCharacters(in: .whitespaces).replacingOccurrences(of: " ", with: "").uppercased()
    }
    var canJoin: Bool { normalizedCode().count == 8 }

    func createClub() async {
        guard canCreate else { return }
        await run { _ = try await clubs.createClub(name: clubName.trimmingCharacters(in: .whitespaces)) }
    }

    /// After a valid code, fetch the claimable (email-less) names so the
    /// paddler can pick theirs. An empty list is fine — they can still join
    /// by email link with no paddler selected.
    func lookupClaimables() async {
        guard canJoin else { return }
        await run(finishes: false) { claimables = try await clubs.claimablePaddlers(code: normalizedCode()) }
    }

    func join() async {
        guard canJoin else { return }
        await run { try await clubs.joinClub(code: normalizedCode(), paddlerId: selectedPaddlerID) }
    }

    private func run(finishes: Bool = true, _ work: () async throws -> Void) async {
        guard !isBusy else { return }
        isBusy = true; errorText = nil
        defer { isBusy = false }
        do { try await work(); if finishes { await onFinished() } }
        catch { errorText = error.localizedDescription }
    }
}

struct OnboardingView: View {
    @Environment(SessionController.self) private var session
    @Environment(AppModel.self) private var app
    @State private var model: OnboardingViewModel?

    var body: some View {
        Group {
            if let model { content(model) } else { ProgressView() }
        }
        .task {
            if model == nil {
                model = OnboardingViewModel(client: app.environment.client,
                                            onFinished: { await session.refreshClub() })
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(DS.bg)
    }

    @ViewBuilder private func content(_ model: OnboardingViewModel) -> some View {
        @Bindable var model = model
        VStack(spacing: DS.Space.l) {
            Spacer()
            switch model.mode {
            case .chooser:
                Text("Set up your club").font(.dsTitle).foregroundStyle(DS.ink)
                PrimaryButton("Create a club") { model.mode = .create }
                Button("I have an invite code") { model.mode = .join }
                    .foregroundStyle(DS.accent)
            case .create:
                MicroLabel("CLUB NAME")
                field("Sydney Dragons", text: $model.clubName)
                PrimaryButton("Create club") { Task { await model.createClub() } }
                    .disabled(!model.canCreate || model.isBusy)
                backButton { model.mode = .chooser }
            case .join:
                MicroLabel("INVITE CODE")
                field("ABCD2345", text: $model.code)
                    .onChange(of: model.code) { Task { await model.lookupClaimables() } }
                if !model.claimables.isEmpty {
                    MicroLabel("CLAIM YOUR NAME")
                    ForEach(model.claimables) { p in
                        claimRow(p, selected: model.selectedPaddlerID == p.id) {
                            model.selectedPaddlerID = (model.selectedPaddlerID == p.id) ? nil : p.id
                        }
                    }
                }
                PrimaryButton("Join club") { Task { await model.join() } }
                    .disabled(!model.canJoin || model.isBusy)
                backButton { model.mode = .chooser }
            }
            if let errorText = model.errorText {
                Text(errorText).font(.dsCaption).foregroundStyle(DS.danger)
            }
            Spacer()
        }
        .frame(maxWidth: 360)
        .padding(DS.Space.xl)
    }

    private func field(_ placeholder: String, text: Binding<String>) -> some View {
        TextField(placeholder, text: text)
            .textFieldStyle(.plain)
            #if os(iOS)
            .textInputAutocapitalization(.never)
            #endif
            .padding(DS.Space.s)
            .background(DS.surface2, in: RoundedRectangle(cornerRadius: DS.R.ctl))
            .overlay(RoundedRectangle(cornerRadius: DS.R.ctl).stroke(DS.border))
    }

    private func claimRow(_ p: ClaimablePaddler, selected: Bool, tap: @escaping () -> Void) -> some View {
        Button(action: tap) {
            HStack {
                Text(p.name).foregroundStyle(DS.ink)
                Spacer()
                if selected { Image(systemName: "checkmark").foregroundStyle(DS.accent) }
            }
            .padding(DS.Space.s)
            .background(selected ? DS.surface2 : DS.surface, in: RoundedRectangle(cornerRadius: DS.R.ctl))
            .overlay(RoundedRectangle(cornerRadius: DS.R.ctl).stroke(selected ? DS.accent : DS.border))
        }
        .buttonStyle(.plain)
    }

    private func backButton(_ action: @escaping () -> Void) -> some View {
        Button("Back", action: action).font(.dsCaption).foregroundStyle(DS.ink3)
    }
}

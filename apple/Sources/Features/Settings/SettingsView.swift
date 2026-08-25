// SettingsView.swift
// Club name, invite code (share + regenerate), category rules (read-only),
// sign out. Reads the club + rules mirrored locally by GRDB (Plan 4b);
// regenerates the invite code via the `regenerate_invite_code` RPC
// (ClubService); signs out through SessionController.
import SwiftUI
import GRDB

struct SettingsView: View {
    @Environment(SessionController.self) private var session
    @Environment(AppModel.self) private var app

    @State private var club: Club?
    @State private var rules: [CategoryRule] = []
    @State private var currentCode: String?

    var body: some View {
        List {
            Section {
                LabeledContent("Club", value: club?.name ?? "—")
                if let code = currentCode ?? club?.inviteCode {
                    HStack {
                        Text("Invite code").foregroundStyle(DS.ink2)
                        Spacer()
                        Text(code)
                            .font(.system(.body, design: .monospaced))
                            .foregroundStyle(DS.ink)
                        ShareLink(item: "Join our club on Paddltir with code \(code)") {
                            Image(systemName: "square.and.arrow.up")
                        }
                    }
                    Button("Regenerate code") { Task { await regenerate() } }
                        .foregroundStyle(DS.accent)
                }
            } header: { MicroLabel("CLUB") }

            Section {
                ForEach(rules, id: \.self) { rule in
                    LabeledContent("\(rule.category.rawValue) · \(rule.boatSize.rawValue)",
                                   value: ruleText(rule))
                }
            } header: { MicroLabel("GENDER RULES") }

            Section {
                Button("Sign out", role: .destructive) { Task { await session.signOut() } }
            }
        }
        .navigationTitle("Settings")
        .task { await load() }
    }

    private func load() async {
        let db = app.environment.db
        club = try? db.read { try Club.fetchOne($0) }
        rules = (try? db.read { try CategoryRule.order(Column("category")).fetchAll($0) }) ?? []
    }

    private func regenerate() async {
        currentCode = try? await ClubService(client: app.environment.client).regenerateInviteCode()
    }

    private func ruleText(_ r: CategoryRule) -> String {
        func fmt(_ lo: Int?, _ hi: Int?) -> String {
            "\(lo.map(String.init) ?? "0")–\(hi.map(String.init) ?? "∞")"
        }
        return "W \(fmt(r.minWomen, r.maxWomen))  ·  M \(fmt(r.minMen, r.maxMen))"
    }
}

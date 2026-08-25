// apple/Sources/Features/Auth/AuthView.swift
// Signed-out screen. Production paths: Sign in with Apple, email magic link
// (both need a signed build / SMTP to work end-to-end — see the plan's
// Global Constraints). DEBUG adds a dev password sign-in against the local
// stack so the flow is exercisable in the simulator and screenshots.
import SwiftUI
import AuthenticationServices
import Supabase

struct AuthView: View {
    @Environment(SessionController.self) private var session
    @Environment(AppModel.self) private var app

    @State private var email = ""
    @State private var magicLinkSent = false
    @State private var errorText: String?
    private var client: SupabaseClient { app.environment.client }
    @State private var currentNonce = ""

    var body: some View {
        VStack(spacing: DS.Space.l) {
            Spacer()
            Text("Paddltir")
                .font(.dsLargeTitle)
                .foregroundStyle(DS.ink)
            MicroLabel("CREW MANAGEMENT")

            VStack(spacing: DS.Space.m) {
                SignInWithAppleButton(.signIn) { request in
                    currentNonce = AppleSignIn.randomNonce()
                    request.requestedScopes = [.fullName, .email]
                    request.nonce = AppleSignIn.sha256(currentNonce)
                } onCompletion: { result in
                    Task { await handleApple(result) }
                }
                .signInWithAppleButtonStyle(.black)
                .frame(height: 50)
                .clipShape(RoundedRectangle(cornerRadius: DS.R.ctl))

                HStack {
                    TextField(text: $email, prompt: Text(verbatim: "you@club.com").foregroundStyle(DS.ink3)) {
                        Text("Email")
                    }
                        .textContentType(.emailAddress)
                        #if os(iOS)
                        .textInputAutocapitalization(.never)
                        .keyboardType(.emailAddress)
                        #endif
                        .textFieldStyle(.plain)
                        .foregroundStyle(DS.ink)
                        .padding(DS.Space.s)
                        .background(DS.surface2, in: RoundedRectangle(cornerRadius: DS.R.ctl))
                        .overlay(RoundedRectangle(cornerRadius: DS.R.ctl).stroke(DS.border))
                        .onChange(of: email) { magicLinkSent = false }
                }
                PrimaryButton(magicLinkSent ? "Link sent — check your email" : "Email me a magic link") {
                    Task { await sendMagicLink() }
                }
                .disabled(email.isEmpty || magicLinkSent)
            }
            .frame(maxWidth: 360)

            if let errorText {
                Text(errorText).font(.dsCaption).foregroundStyle(DS.danger)
            }

            #if DEBUG
            devSignIn
            #endif
            Spacer()
        }
        .padding(DS.Space.xl)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(DS.bg)
    }

    private func handleApple(_ result: Result<ASAuthorization, any Error>) async {
        do {
            guard case let .success(auth) = result,
                  let cred = auth.credential as? ASAuthorizationAppleIDCredential,
                  let tokenData = cred.identityToken,
                  let idToken = String(data: tokenData, encoding: .utf8)
            else { errorText = "Apple sign-in failed"; return }
            _ = try await client.auth.signInWithIdToken(
                credentials: .init(provider: .apple, idToken: idToken, nonce: currentNonce))
            await session.refreshClub()
        } catch { errorText = error.localizedDescription }
    }

    private func sendMagicLink() async {
        do { try await client.auth.signInWithOTP(email: email); magicLinkSent = true }
        catch { errorText = error.localizedDescription }
    }

    #if DEBUG
    @ViewBuilder private var devSignIn: some View {
        VStack(spacing: DS.Space.s) {
            MicroLabel("DEV — LOCAL STACK")
            Button {
                Task {
                    do {
                        try await client.auth.signIn(email: "coach@paddltir.dev", password: "password123")
                        await session.refreshClub()
                    } catch { errorText = error.localizedDescription }
                }
            } label: {
                Text(verbatim: "Sign in as coach@paddltir.dev")
            }
            .font(.dsCaption)
            .foregroundStyle(DS.accent)
        }
        .padding(.top, DS.Space.l)
    }
    #endif
}

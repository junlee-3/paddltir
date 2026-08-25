// apple/Sources/App/AppleSignIn.swift
// Sign in with Apple nonce helpers. Apple wants the SHA-256 of a nonce in
// the authorization request; Supabase wants the RAW nonce alongside the
// returned idToken so it can verify the `nonce` claim. Standard recipe.
import Foundation
import CryptoKit

enum AppleSignIn {
    static func randomNonce(length: Int = 32) -> String {
        let charset = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz-._")
        var result = ""
        var remaining = length
        while remaining > 0 {
            var random: UInt8 = 0
            _ = SecRandomCopyBytes(kSecRandomDefault, 1, &random)
            if random < charset.count { result.append(charset[Int(random)]); remaining -= 1 }
        }
        return result
    }

    static func sha256(_ input: String) -> String {
        SHA256.hash(data: Data(input.utf8)).map { String(format: "%02x", $0) }.joined()
    }
}

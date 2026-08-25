// Secrets.example.swift
// COMMITTED template. Copy this file to `apple/Sources/App/Secrets.swift` (git-ignored)
// and fill in real local values. `apple/Sources/App/Secrets.swift` must exist for the
// app target to build.
//
// Local values: run `supabase start` then `supabase status` from the repo root and
// paste the ANON_KEY below. At go-live, swap in the hosted project URL + anon key.

enum Secrets {
    static let supabaseURL = "http://127.0.0.1:54321"        // local stack; hosted URL at go-live
    static let supabaseAnonKey = "PASTE_LOCAL_ANON_KEY"      // from `supabase status`
}

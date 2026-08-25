// Loadable.swift
// Screen state for observed data: loading (no value yet), loaded, or failed
// (a read error — the UI keeps showing the last value if it had one and
// surfaces the message). Read failures never discard data.
import Foundation

enum Loadable<Value: Equatable & Sendable>: Equatable, Sendable {
    case loading
    case loaded(Value)
    case failed(String)

    var value: Value? { if case .loaded(let v) = self { return v } else { return nil } }
    var isLoading: Bool { if case .loading = self { return true } else { return false } }
}

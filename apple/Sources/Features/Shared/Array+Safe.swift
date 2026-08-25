// Array+Safe.swift
// A tiny, widely-reused guard against out-of-range indices — e.g. the lineup
// editor's `selectedHeatIndex` against a `heats` array that can shrink or
// reorder out from under a stale index.
extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}

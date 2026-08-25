// PostgRESTCoding.swift
// Shared JSONDecoder/JSONEncoder for decoding/encoding PostgREST row JSON.
//
// PostgREST serializes `timestamptz` columns as ISO 8601 with microsecond
// fractional seconds and a numeric UTC offset, e.g.
// "2026-08-25T07:14:00.123456+00:00". `date` columns (erg_tests.tested_at)
// come back as a bare "2026-08-25" with no time component at all. The date
// strategy below tries, in order: ISO8601 with fractional seconds, ISO8601
// without fractional seconds, then a plain yyyy-MM-dd parse — so one decoder
// handles both column kinds. Foundation's ISO8601DateFormatter truncates
// beyond millisecond precision, which is fine here: we only need a correct
// instant, not microsecond-exact round-tripping.

import Foundation

enum PostgREST {
    // Each formatter below is configured once at first access and only ever
    // read afterwards (`.date(from:)` / `.string(from:)`), never mutated, so
    // sharing one instance across threads is safe even though the
    // Foundation formatter classes themselves predate `Sendable`.
    nonisolated(unsafe) private static let isoWithFractionalSeconds: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    nonisolated(unsafe) private static let isoWithoutFractionalSeconds: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()

    private static let dateOnlyFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .iso8601)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: "UTC")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    /// Parses a PostgREST-formatted timestamp or date string into a `Date`.
    static func parseDate(_ string: String) -> Date? {
        isoWithFractionalSeconds.date(from: string)
            ?? isoWithoutFractionalSeconds.date(from: string)
            ?? dateOnlyFormatter.date(from: string)
    }

    /// Formats a `Date` the way PostgREST expects for `timestamptz` columns
    /// (ISO 8601, fractional seconds, UTC offset).
    static func formatDate(_ date: Date) -> String {
        isoWithFractionalSeconds.string(from: date)
    }

    /// Shared decoder for PostgREST row JSON: converts snake_case keys to
    /// camelCase and parses both `timestamptz` and `date` columns.
    static let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let string = try container.decode(String.self)
            guard let date = parseDate(string) else {
                throw DecodingError.dataCorruptedError(
                    in: container,
                    debugDescription: "Expected a PostgREST-formatted date/timestamp, got \"\(string)\""
                )
            }
            return date
        }
        return decoder
    }()

    /// Shared encoder for writing rows back to PostgREST: converts
    /// camelCase keys to snake_case and formats dates for `timestamptz`.
    static let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        encoder.dateEncodingStrategy = .custom { date, encoder in
            var container = encoder.singleValueContainer()
            try container.encode(formatDate(date))
        }
        return encoder
    }()
}

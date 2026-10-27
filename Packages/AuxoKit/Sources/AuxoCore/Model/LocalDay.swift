import Foundation

/// A calendar day with no time of day or time zone attached, such as "2026-10-27".
///
/// Every site reports activity per day, but each one defines "day" differently
/// (GitHub uses dates, LeetCode uses UTC midnights, Codeforces uses exact timestamps).
/// Providers convert to `LocalDay` once, and everything downstream works with plain days.
public struct LocalDay: Hashable, Comparable, Codable, Sendable, CustomStringConvertible {
    public let year: Int
    public let month: Int
    public let day: Int

    public init(year: Int, month: Int, day: Int) {
        self.year = year
        self.month = month
        self.day = day
    }

    public init(date: Date, calendar: Calendar = .current) {
        let parts = calendar.dateComponents([.year, .month, .day], from: date)
        self.init(year: parts.year ?? 1970, month: parts.month ?? 1, day: parts.day ?? 1)
    }

    /// Parses "YYYY-MM-DD". Returns nil for anything else.
    public init?(string: String) {
        let parts = string.split(separator: "-", omittingEmptySubsequences: false)
        guard parts.count == 3,
              parts[0].count == 4, parts[1].count == 2, parts[2].count == 2,
              let y = Int(parts[0]), let m = Int(parts[1]), let d = Int(parts[2]),
              (1...12).contains(m), (1...31).contains(d)
        else { return nil }
        self.init(year: y, month: m, day: d)
    }

    public var string: String {
        String(format: "%04d-%02d-%02d", year, month, day)
    }

    public var description: String { string }

    /// The start of this day in the given calendar's time zone.
    public func date(in calendar: Calendar = .current) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day)) ?? Date(timeIntervalSince1970: 0)
    }

    public func adding(days n: Int, calendar: Calendar = .current) -> LocalDay {
        // Anchor at noon so daylight-saving transitions can never push us into the wrong day.
        let noon = calendar.date(from: DateComponents(year: year, month: month, day: day, hour: 12))
            ?? Date(timeIntervalSince1970: 0)
        let moved = calendar.date(byAdding: .day, value: n, to: noon) ?? noon
        return LocalDay(date: moved, calendar: calendar)
    }

    /// 1 = Sunday … 7 = Saturday, matching `Calendar.component(.weekday, …)`.
    public func weekday(calendar: Calendar = .current) -> Int {
        let noon = calendar.date(from: DateComponents(year: year, month: month, day: day, hour: 12))
            ?? Date(timeIntervalSince1970: 0)
        return calendar.component(.weekday, from: noon)
    }

    public static func today(calendar: Calendar = .current) -> LocalDay {
        LocalDay(date: Date(), calendar: calendar)
    }

    public static func < (lhs: LocalDay, rhs: LocalDay) -> Bool {
        (lhs.year, lhs.month, lhs.day) < (rhs.year, rhs.month, rhs.day)
    }

    // Encoded as "YYYY-MM-DD" so stored files stay readable.
    public init(from decoder: Decoder) throws {
        let raw = try decoder.singleValueContainer().decode(String.self)
        guard let parsed = LocalDay(string: raw) else {
            throw DecodingError.dataCorrupted(.init(codingPath: decoder.codingPath,
                                                    debugDescription: "Invalid day: \(raw)"))
        }
        self = parsed
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(string)
    }
}

public extension Calendar {
    /// Gregorian calendar fixed to UTC, used for sites that report UTC days.
    static var utc: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC") ?? TimeZone(secondsFromGMT: 0) ?? .current
        return calendar
    }
}

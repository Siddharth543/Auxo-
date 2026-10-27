import Foundation

public struct StreakStats: Equatable, Sendable {
    /// Consecutive active days ending today. If nothing has happened yet today,
    /// the streak still counts back from yesterday, because the day isn't over.
    public var current: Int
    /// Longest run inside the window (or the current streak, if that is longer).
    public var longest: Int
    /// Sum of activity inside the window.
    public var total: Int
    /// Days with any activity inside the window.
    public var activeDays: Int

    public init(current: Int, longest: Int, total: Int, activeDays: Int) {
        self.current = current
        self.longest = longest
        self.total = total
        self.activeDays = activeDays
    }

    public static let zero = StreakStats(current: 0, longest: 0, total: 0, activeDays: 0)

    public static func compute(_ series: ActivitySeries,
                               today: LocalDay,
                               calendar: Calendar = .current,
                               windowDays: Int = 365) -> StreakStats {
        guard windowDays > 0 else { return .zero }

        var total = 0
        var active = 0
        var run = 0
        var longest = 0
        var day = today.adding(days: -(windowDays - 1), calendar: calendar)
        for _ in 0..<windowDays {
            let count = series[day]
            total += count
            if count > 0 {
                active += 1
                run += 1
                longest = max(longest, run)
            } else {
                run = 0
            }
            day = day.adding(days: 1, calendar: calendar)
        }

        var current = 0
        var cursor = series[today] > 0 ? today : today.adding(days: -1, calendar: calendar)
        while series[cursor] > 0 && current < 100_000 {
            current += 1
            cursor = cursor.adding(days: -1, calendar: calendar)
        }

        return StreakStats(current: current, longest: max(longest, current), total: total, activeDays: active)
    }
}

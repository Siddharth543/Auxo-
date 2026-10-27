import Foundation

/// Activity per day ("2026-10-27" → 3). Days with no activity are simply absent.
public struct ActivitySeries: Codable, Equatable, Sendable {
    public private(set) var counts: [String: Int]

    public init(counts: [String: Int] = [:]) {
        self.counts = counts.filter { $0.value > 0 }
    }

    public init(days: [LocalDay: Int]) {
        var out: [String: Int] = [:]
        for (day, count) in days where count > 0 {
            out[day.string] = count
        }
        self.counts = out
    }

    public subscript(day: LocalDay) -> Int {
        get { counts[day.string] ?? 0 }
        set { counts[day.string] = newValue > 0 ? newValue : nil }
    }

    public var isEmpty: Bool { counts.isEmpty }

    public mutating func add(_ amount: Int, on day: LocalDay) {
        guard amount > 0 else { return }
        self[day] += amount
    }

    /// A merged series where each day's value is how many of the inputs were active that day.
    /// Summing raw counts would let 30 commits drown out 2 solved problems.
    public static func combined(_ series: [ActivitySeries]) -> ActivitySeries {
        var out: [String: Int] = [:]
        for s in series {
            for (key, count) in s.counts where count > 0 {
                out[key, default: 0] += 1
            }
        }
        return ActivitySeries(counts: out)
    }
}

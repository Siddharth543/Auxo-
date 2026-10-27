import Foundation

/// The last data fetched for an account. Kept on disk so the widget can render instantly
/// and keep showing the last good data when a site is down.
public struct AccountSnapshot: Codable, Equatable, Sendable {
    public var accountID: String
    public var series: ActivitySeries
    public var rating: RatingInfo?
    public var lastSuccess: Date?
    public var lastAttempt: Date?
    /// Set when the most recent attempt failed; the series is then from `lastSuccess`.
    public var lastError: String?

    public init(accountID: String,
                series: ActivitySeries = ActivitySeries(),
                rating: RatingInfo? = nil,
                lastSuccess: Date? = nil,
                lastAttempt: Date? = nil,
                lastError: String? = nil) {
        self.accountID = accountID
        self.series = series
        self.rating = rating
        self.lastSuccess = lastSuccess
        self.lastAttempt = lastAttempt
        self.lastError = lastError
    }

    public var hasError: Bool { lastError != nil }
}

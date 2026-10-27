import Foundation

public struct FetchOptions: Sendable {
    public var codeforcesAcceptedOnly: Bool
    public var githubToken: String?
    /// Calendar used to turn exact timestamps into days (the user's own time zone).
    public var calendar: Calendar

    public init(codeforcesAcceptedOnly: Bool = true, githubToken: String? = nil, calendar: Calendar = .current) {
        self.codeforcesAcceptedOnly = codeforcesAcceptedOnly
        self.githubToken = githubToken
        self.calendar = calendar
    }
}

public struct ProviderResult: Sendable, Equatable {
    public var series: ActivitySeries
    public var rating: RatingInfo?
    /// The handle exactly as the site spells it (case can differ from what the user typed).
    public var canonicalHandle: String

    public init(series: ActivitySeries, rating: RatingInfo?, canonicalHandle: String) {
        self.series = series
        self.rating = rating
        self.canonicalHandle = canonicalHandle
    }
}

/// Everything a site integration has to implement.
public protocol ActivityProvider: Sendable {
    var source: Source { get }

    /// Fetches daily activity from `since` (inclusive) to today, plus rating if the site has one.
    func fetch(handle: String, since: LocalDay, options: FetchOptions) async throws -> ProviderResult
}

public enum ProviderError: Error, LocalizedError, Equatable, Sendable {
    case notFound(String)
    case signInRequired
    case unauthorized
    case rateLimited
    case unavailable(String)
    case invalidResponse

    public var errorDescription: String? {
        switch self {
        case .notFound(let handle):
            return "No account named “\(handle)” was found. Check the spelling."
        case .signInRequired:
            return "Sign in to GitHub in Auxo to load contribution data."
        case .unauthorized:
            return "GitHub rejected the saved sign-in. Sign in again in Auxo."
        case .rateLimited:
            return "The site is limiting requests right now. Auxo will try again shortly."
        case .unavailable(let message):
            return message
        case .invalidResponse:
            return "The site sent a response Auxo couldn't read."
        }
    }
}

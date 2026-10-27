import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
import AuxoCore

/// Codeforces via its official public API (https://codeforces.com/apiHelp).
///
/// Calls: `user.info` (rating, rank), `user.rating` (contest count, rated users only),
/// then `user.status` paged newest-first until it passes the start of the window.
/// The API allows about one call every two seconds, enforced by a shared `RateLimiter`.
public struct CodeforcesProvider: ActivityProvider {
    public let source: Source = .codeforces

    public static let sharedLimiter = RateLimiter(interval: 2.1)

    private let transport: HTTPTransport
    private let limiter: RateLimiter
    private let pageSize: Int
    private let baseURL: URL

    public init(transport: HTTPTransport = URLSessionTransport(),
                limiter: RateLimiter = CodeforcesProvider.sharedLimiter,
                pageSize: Int = 1000,
                baseURL: URL = URL(string: "https://codeforces.com/api/")!) {
        self.transport = transport
        self.limiter = limiter
        self.pageSize = pageSize
        self.baseURL = baseURL
    }

    struct Envelope<T: Decodable>: Decodable {
        let status: String
        let comment: String?
        let result: T?
    }

    struct UserInfo: Decodable {
        let handle: String
        let rating: Int?
        let maxRating: Int?
    }

    struct RatingChange: Decodable {
        let contestId: Int
    }

    struct Submission: Decodable {
        let creationTimeSeconds: Int
        let verdict: String?
    }

    public func fetch(handle: String, since: LocalDay, options: FetchOptions) async throws -> ProviderResult {
        let requested = handle.trimmingCharacters(in: .whitespacesAndNewlines)

        let users: [UserInfo] = try await call("user.info", ["handles": requested], handle: requested)
        guard let user = users.first else { throw ProviderError.notFound(requested) }

        var rating: RatingInfo?
        if let current = user.rating {
            let changes: [RatingChange] = try await call("user.rating", ["handle": user.handle], handle: requested)
            rating = RatingInfo(kind: .codeforces,
                                rating: current,
                                maxRating: max(user.maxRating ?? current, current),
                                contests: changes.count)
        }

        let series = try await submissions(handle: user.handle, since: since, options: options)
        return ProviderResult(series: series, rating: rating, canonicalHandle: user.handle)
    }

    private func submissions(handle: String, since: LocalDay, options: FetchOptions) async throws -> ActivitySeries {
        let cutoff = since.date(in: options.calendar)
        var series = ActivitySeries()
        var from = 1

        while true {
            let page: [Submission] = try await call("user.status",
                                                    ["handle": handle, "from": String(from), "count": String(pageSize)],
                                                    handle: handle)
            var passedCutoff = false
            for submission in page {
                let date = Date(timeIntervalSince1970: TimeInterval(submission.creationTimeSeconds))
                if date < cutoff {
                    passedCutoff = true
                    break
                }
                if options.codeforcesAcceptedOnly && submission.verdict != "OK" { continue }
                series.add(1, on: LocalDay(date: date, calendar: options.calendar))
            }
            if passedCutoff || page.count < pageSize || from > 50_000 { break }
            from += pageSize
        }
        return series
    }

    private func call<T: Decodable>(_ method: String, _ parameters: [String: String], handle: String) async throws -> T {
        await limiter.wait()

        guard var components = URLComponents(url: baseURL.appendingPathComponent(method),
                                             resolvingAgainstBaseURL: false) else {
            throw ProviderError.invalidResponse
        }
        components.queryItems = parameters.sorted { $0.key < $1.key }.map { URLQueryItem(name: $0.key, value: $0.value) }
        guard let url = components.url else { throw ProviderError.invalidResponse }

        var request = URLRequest(url: url, timeoutInterval: 20)
        request.setValue(HTTP.userAgent, forHTTPHeaderField: "User-Agent")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        let (data, response) = try await transport.send(request)
        if response.statusCode == 429 || response.statusCode == 503 {
            throw ProviderError.rateLimited
        }

        let envelope: Envelope<T>
        do {
            envelope = try JSONDecoder().decode(Envelope<T>.self, from: data)
        } catch {
            throw ProviderError.unavailable("Codeforces sent an unexpected response. It may be under maintenance.")
        }

        guard envelope.status == "OK", let result = envelope.result else {
            let comment = envelope.comment ?? ""
            if comment.localizedCaseInsensitiveContains("not found") {
                throw ProviderError.notFound(handle)
            }
            if comment.localizedCaseInsensitiveContains("limit exceeded") {
                throw ProviderError.rateLimited
            }
            throw ProviderError.unavailable(comment.isEmpty ? "Codeforces returned an error." : "Codeforces: \(comment)")
        }
        return result
    }
}

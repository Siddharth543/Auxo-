import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
import AuxoCore

/// LeetCode via the GraphQL endpoint its own website uses.
///
/// This endpoint is **not an official API**: LeetCode can change or block it at any time.
/// Failures are reported as `.unavailable` so the app keeps showing the last good data and
/// every other source keeps working. Submission calendar days are UTC days.
public struct LeetCodeProvider: ActivityProvider {
    public let source: Source = .leetcode

    private let transport: HTTPTransport
    private let endpoint: URL

    public init(transport: HTTPTransport = URLSessionTransport(),
                endpoint: URL = URL(string: "https://leetcode.com/graphql")!) {
        self.transport = transport
        self.endpoint = endpoint
    }

    static let calendarQuery = """
    query userProfileCalendar($username: String!) {
      matchedUser(username: $username) {
        username
        userCalendar { submissionCalendar }
      }
    }
    """

    static let contestQuery = """
    query userContestRankingInfo($username: String!) {
      userContestRanking(username: $username) {
        attendedContestsCount
        rating
        topPercentage
        badge { name }
      }
    }
    """

    struct CalendarResponse: Decodable {
        struct Payload: Decodable { let matchedUser: MatchedUser? }
        struct MatchedUser: Decodable {
            let username: String
            let userCalendar: UserCalendar?
        }
        struct UserCalendar: Decodable { let submissionCalendar: String? }
        let data: Payload?
        let errors: [GraphQLError]?
    }

    struct ContestResponse: Decodable {
        struct Payload: Decodable { let userContestRanking: Ranking? }
        struct Ranking: Decodable {
            let attendedContestsCount: Int?
            let rating: Double?
            let topPercentage: Double?
            let badge: Badge?
        }
        struct Badge: Decodable { let name: String? }
        let data: Payload?
    }

    public func fetch(handle: String, since: LocalDay, options: FetchOptions) async throws -> ProviderResult {
        let username = handle.trimmingCharacters(in: .whitespacesAndNewlines)
        let data = try await post(query: Self.calendarQuery, username: username)

        let response: CalendarResponse
        do {
            response = try JSONDecoder().decode(CalendarResponse.self, from: data)
        } catch {
            throw ProviderError.unavailable("LeetCode isn't responding the way Auxo expects. Showing the last saved data.")
        }
        if let errors = response.errors, !errors.isEmpty, response.data?.matchedUser == nil {
            if errors.contains(where: { $0.message.localizedCaseInsensitiveContains("does not exist") }) {
                throw ProviderError.notFound(username)
            }
            throw ProviderError.unavailable("LeetCode: \(errors[0].message)")
        }
        guard let user = response.data?.matchedUser else {
            throw ProviderError.notFound(username)
        }

        let series = Self.parseCalendar(user.userCalendar?.submissionCalendar, since: since)

        // Contest rating is a bonus: if it fails, keep the heatmap.
        var rating: RatingInfo?
        do {
            rating = try await contestRating(username: user.username)
        } catch {
            rating = nil
        }

        return ProviderResult(series: series, rating: rating, canonicalHandle: user.username)
    }

    /// `submissionCalendar` is a JSON string: {"<unix seconds at UTC midnight>": count, …}.
    static func parseCalendar(_ raw: String?, since: LocalDay) -> ActivitySeries {
        guard let raw,
              let data = raw.data(using: .utf8),
              let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return ActivitySeries()
        }
        let utc = Calendar.utc
        var series = ActivitySeries()
        for (key, value) in object {
            guard let seconds = TimeInterval(key) else { continue }
            let count: Int
            if let n = value as? Int {
                count = n
            } else if let n = value as? NSNumber {
                count = n.intValue
            } else if let s = value as? String, let n = Int(s) {
                count = n
            } else {
                continue
            }
            let day = LocalDay(date: Date(timeIntervalSince1970: seconds), calendar: utc)
            if day >= since {
                series.add(count, on: day)
            }
        }
        return series
    }

    private func contestRating(username: String) async throws -> RatingInfo? {
        let data = try await post(query: Self.contestQuery, username: username)
        let response = try JSONDecoder().decode(ContestResponse.self, from: data)
        guard let ranking = response.data?.userContestRanking,
              let rating = ranking.rating,
              (ranking.attendedContestsCount ?? 0) > 0 else {
            return nil
        }
        let badge = ranking.badge?.name.flatMap { $0.isEmpty ? nil : $0 }
        return RatingInfo(kind: .leetcode,
                          rating: Int(rating.rounded()),
                          contests: ranking.attendedContestsCount,
                          badge: badge,
                          topPercentage: ranking.topPercentage)
    }

    private func post(query: String, username: String) async throws -> Data {
        let encoded = username.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? username
        let request = try HTTP.jsonPOST(endpoint,
                                        body: ["query": query, "variables": ["username": username]],
                                        headers: ["Referer": "https://leetcode.com/u/\(encoded)/",
                                                  "Origin": "https://leetcode.com"])
        let (data, response) = try await transport.send(request)
        switch response.statusCode {
        case 200..<300:
            return data
        case 429:
            throw ProviderError.rateLimited
        default:
            throw ProviderError.unavailable("LeetCode refused the request (HTTP \(response.statusCode)). Showing the last saved data.")
        }
    }
}

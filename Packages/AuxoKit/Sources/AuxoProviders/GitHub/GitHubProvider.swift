import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
import AuxoCore

/// GitHub via the official GraphQL API's contribution calendar.
///
/// GitHub requires a token for every GraphQL call, even for public data. The token needs
/// no scopes. Private contributions are included only if the user turned on
/// "Include private contributions on my profile" in their GitHub settings.
public struct GitHubProvider: ActivityProvider {
    public let source: Source = .github

    private let transport: HTTPTransport
    private let endpoint: URL

    public init(transport: HTTPTransport = URLSessionTransport(),
                endpoint: URL = URL(string: "https://api.github.com/graphql")!) {
        self.transport = transport
        self.endpoint = endpoint
    }

    static let calendarQuery = """
    query($login: String!) {
      user(login: $login) {
        login
        contributionsCollection {
          contributionCalendar {
            weeks { contributionDays { date contributionCount } }
          }
        }
      }
    }
    """

    static let viewerQuery = "query { viewer { login } }"

    struct CalendarResponse: Decodable {
        struct Payload: Decodable { let user: User? }
        struct User: Decodable {
            let login: String
            let contributionsCollection: Collection
        }
        struct Collection: Decodable { let contributionCalendar: ContributionCalendar }
        struct ContributionCalendar: Decodable { let weeks: [Week] }
        struct Week: Decodable { let contributionDays: [Day] }
        struct Day: Decodable {
            let date: String
            let contributionCount: Int
        }
        let data: Payload?
        let errors: [GraphQLError]?
    }

    struct ViewerResponse: Decodable {
        struct Payload: Decodable { let viewer: Viewer? }
        struct Viewer: Decodable { let login: String }
        let data: Payload?
        let errors: [GraphQLError]?
    }

    public func fetch(handle: String, since: LocalDay, options: FetchOptions) async throws -> ProviderResult {
        guard let token = options.githubToken, !token.isEmpty else {
            throw ProviderError.signInRequired
        }
        let login = handle.trimmingCharacters(in: .whitespacesAndNewlines)
        let data = try await post(query: Self.calendarQuery, variables: ["login": login], token: token)

        let response: CalendarResponse
        do {
            response = try JSONDecoder().decode(CalendarResponse.self, from: data)
        } catch {
            throw ProviderError.unavailable("GitHub sent an unexpected response.")
        }
        if let errors = response.errors, !errors.isEmpty {
            if errors.contains(where: { $0.type == "NOT_FOUND" }) {
                throw ProviderError.notFound(login)
            }
            throw ProviderError.unavailable("GitHub: \(errors[0].message)")
        }
        guard let user = response.data?.user else {
            throw ProviderError.notFound(login)
        }

        var series = ActivitySeries()
        for week in user.contributionsCollection.contributionCalendar.weeks {
            for day in week.contributionDays where day.contributionCount > 0 {
                if let parsed = LocalDay(string: day.date), parsed >= since {
                    series[parsed] = day.contributionCount
                }
            }
        }
        return ProviderResult(series: series, rating: nil, canonicalHandle: user.login)
    }

    /// The username that owns `token`, used right after sign-in.
    public func viewerLogin(token: String) async throws -> String {
        let data = try await post(query: Self.viewerQuery, variables: [:], token: token)
        guard let response = try? JSONDecoder().decode(ViewerResponse.self, from: data),
              let login = response.data?.viewer?.login else {
            throw ProviderError.unauthorized
        }
        return login
    }

    private func post(query: String, variables: [String: String], token: String) async throws -> Data {
        let request = try HTTP.jsonPOST(endpoint,
                                        body: ["query": query, "variables": variables],
                                        headers: ["Authorization": "bearer \(token)"])
        let (data, response) = try await transport.send(request)
        switch response.statusCode {
        case 200..<300:
            return data
        case 401:
            throw ProviderError.unauthorized
        case 403, 429:
            throw ProviderError.rateLimited
        default:
            throw ProviderError.unavailable("GitHub returned HTTP \(response.statusCode).")
        }
    }
}

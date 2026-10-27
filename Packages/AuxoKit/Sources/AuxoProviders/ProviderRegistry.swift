import Foundation
import AuxoCore

/// Maps each `Source` to its provider. Adding a site means adding one case here.
public enum ProviderRegistry {
    public static func provider(for source: Source,
                                transport: HTTPTransport = URLSessionTransport()) -> any ActivityProvider {
        switch source {
        case .github: return GitHubProvider(transport: transport)
        case .leetcode: return LeetCodeProvider(transport: transport)
        case .codeforces: return CodeforcesProvider(transport: transport)
        }
    }
}

import Foundation

/// A site Auxo can read a streak from. Adding a site starts here (see docs/ADDING_A_SOURCE.md).
public enum Source: String, Codable, CaseIterable, Sendable, Identifiable {
    case github
    case leetcode
    case codeforces

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .github: return "GitHub"
        case .leetcode: return "LeetCode"
        case .codeforces: return "Codeforces"
        }
    }

    public var shortName: String {
        switch self {
        case .github: return "GH"
        case .leetcode: return "LC"
        case .codeforces: return "CF"
        }
    }

    /// What one unit of activity is called on this site.
    public func unit(codeforcesAcceptedOnly: Bool = true) -> String {
        switch self {
        case .github: return "contributions"
        case .leetcode: return "submissions"
        case .codeforces: return codeforcesAcceptedOnly ? "accepted" : "submissions"
        }
    }

    public var handleLabel: String {
        self == .codeforces ? "Handle" : "Username"
    }

    public var handleHint: String {
        switch self {
        case .github:
            return "GitHub usernames use letters, digits and hyphens, up to 39 characters."
        case .leetcode:
            return "Your LeetCode username, as it appears in leetcode.com/u/username."
        case .codeforces:
            return "Codeforces handles are 3 to 24 characters: letters, digits, _ - and ."
        }
    }

    /// GitHub needs a token even for public contribution data.
    public var requiresSignIn: Bool { self == .github }

    /// Whether the site has a contest rating.
    public var hasRating: Bool { self != .github }

    /// Activity counts at which a day moves to shade 1, 2, 3 (4 is anything above the last).
    public var levelThresholds: [Int] {
        switch self {
        case .github: return [1, 3, 6]
        case .leetcode, .codeforces: return [1, 2, 4]
        }
    }

    /// Heatmap shade 0…4 for a day's count.
    public func level(for count: Int) -> Int {
        guard count > 0 else { return 0 }
        let t = levelThresholds
        if count <= t[0] { return 1 }
        if count <= t[1] { return 2 }
        if count <= t[2] { return 3 }
        return 4
    }

    public func isValidHandle(_ raw: String) -> Bool {
        let handle = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        func allowed(_ extra: Set<Character>) -> Bool {
            handle.allSatisfy { $0.isASCII && ($0.isLetter || $0.isNumber || extra.contains($0)) }
        }
        switch self {
        case .github:
            return (1...39).contains(handle.count)
                && allowed(["-"])
                && !handle.hasPrefix("-") && !handle.hasSuffix("-")
        case .leetcode:
            return (1...40).contains(handle.count) && allowed(["_", "-", "."])
        case .codeforces:
            return (3...24).contains(handle.count) && allowed(["_", "-", "."])
        }
    }

    public func profileURL(handle: String) -> URL? {
        let encoded = handle.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? handle
        switch self {
        case .github: return URL(string: "https://github.com/\(encoded)")
        case .leetcode: return URL(string: "https://leetcode.com/u/\(encoded)/")
        case .codeforces: return URL(string: "https://codeforces.com/profile/\(encoded)")
        }
    }
}

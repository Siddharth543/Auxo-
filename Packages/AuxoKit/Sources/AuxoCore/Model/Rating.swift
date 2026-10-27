import Foundation

/// Contest rating for sites that have one. GitHub has none.
public struct RatingInfo: Codable, Equatable, Sendable {
    public enum Kind: String, Codable, Sendable {
        case codeforces
        case leetcode
    }

    public var kind: Kind
    public var rating: Int
    /// Codeforces only.
    public var maxRating: Int?
    public var contests: Int?
    /// LeetCode badge name ("Knight", "Guardian"), nil if none earned.
    public var badge: String?
    /// LeetCode "top x%" of contest participants.
    public var topPercentage: Double?

    public init(kind: Kind, rating: Int, maxRating: Int? = nil, contests: Int? = nil,
                badge: String? = nil, topPercentage: Double? = nil) {
        self.kind = kind
        self.rating = rating
        self.maxRating = maxRating
        self.contests = contests
        self.badge = badge
        self.topPercentage = topPercentage
    }

    public var codeforcesRank: CodeforcesRank? {
        kind == .codeforces ? CodeforcesRank(rating: rating) : nil
    }

    public var maxCodeforcesRank: CodeforcesRank? {
        guard kind == .codeforces, let maxRating else { return nil }
        return CodeforcesRank(rating: maxRating)
    }

    /// "Expert", "Knight", or nil when the site has no title for this rating.
    public var title: String? {
        switch kind {
        case .codeforces: return codeforcesRank?.title
        case .leetcode: return badge
        }
    }
}

/// The Codeforces rank ladder, using the official rating thresholds.
public enum CodeforcesRank: Int, CaseIterable, Comparable, Sendable {
    case newbie
    case pupil
    case specialist
    case expert
    case candidateMaster
    case master
    case internationalMaster
    case grandmaster
    case internationalGrandmaster
    case legendaryGrandmaster

    public init(rating: Int) {
        self = Self.allCases.last(where: { rating >= $0.minRating }) ?? .newbie
    }

    public var minRating: Int {
        switch self {
        case .newbie: return Int.min
        case .pupil: return 1200
        case .specialist: return 1400
        case .expert: return 1600
        case .candidateMaster: return 1900
        case .master: return 2100
        case .internationalMaster: return 2300
        case .grandmaster: return 2400
        case .internationalGrandmaster: return 2600
        case .legendaryGrandmaster: return 3000
        }
    }

    public var title: String {
        switch self {
        case .newbie: return "Newbie"
        case .pupil: return "Pupil"
        case .specialist: return "Specialist"
        case .expert: return "Expert"
        case .candidateMaster: return "Candidate Master"
        case .master: return "Master"
        case .internationalMaster: return "International Master"
        case .grandmaster: return "Grandmaster"
        case .internationalGrandmaster: return "International Grandmaster"
        case .legendaryGrandmaster: return "Legendary Grandmaster"
        }
    }

    public static func < (lhs: CodeforcesRank, rhs: CodeforcesRank) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

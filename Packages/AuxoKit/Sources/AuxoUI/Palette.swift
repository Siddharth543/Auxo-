import SwiftUI
import AuxoCore

/// Heatmap shades. Every palette has 5 levels (0 = no activity … 4 = most);
/// the combined view uses 4 (0, 1, 2, 3+ sources active).
public enum Palette {
    /// The dark surface every heatmap sits on (widget, app cards, share cards).
    public static let surfaceHex = "#0D1117"
    public static let surface = Color(hex: surfaceHex)

    public static func hexLevels(for source: Source, settings: AppSettings) -> [String] {
        switch settings.theme {
        case .perSource: return sourceLevels(source)
        case .custom: return custom(accent: settings.customAccentHex)
        case .classic, .ocean, .ember, .mono: return themeLevels(settings.theme)
        }
    }

    public static func levels(for source: Source, settings: AppSettings) -> [Color] {
        hexLevels(for: source, settings: settings).map(Color.init(hex:))
    }

    public static func combinedHexLevels(settings: AppSettings) -> [String] {
        if settings.theme == .perSource {
            return ["#171A22", "#33295E", "#5641A3", "#8A6CF0"]
        }
        let p = hexLevels(for: .github, settings: settings)
        return [p[0], p[1], p[3], p[4]]
    }

    public static func combinedLevels(settings: AppSettings) -> [Color] {
        combinedHexLevels(settings: settings).map(Color.init(hex:))
    }

    /// Shades used when the system dims a widget (desktop widgets behind an app, tinted icons).
    public static let dimmedOpacities: [Double] = [0.10, 0.30, 0.50, 0.75, 1.0]
    public static let dimmedCombinedOpacities: [Double] = [0.10, 0.30, 0.75, 1.0]

    public static func sourceLevels(_ source: Source) -> [String] {
        switch source {
        case .github: return ["#161B22", "#0E4429", "#006D32", "#26A641", "#39D353"]
        case .leetcode: return ["#1A1814", "#5A3B06", "#946108", "#D18C12", "#FFB224"]
        case .codeforces: return ["#151A23", "#12386A", "#1B58A5", "#2F7FE9", "#6EA9FF"]
        }
    }

    public static func themeLevels(_ theme: ThemeID) -> [String] {
        switch theme {
        case .classic: return ["#161B22", "#0E4429", "#006D32", "#26A641", "#39D353"]
        case .ocean: return ["#151A23", "#0C3B5E", "#13609A", "#1F8FD6", "#5CC3FF"]
        case .ember: return ["#1A1614", "#5C2A0F", "#9A4214", "#E06A1F", "#FFA05C"]
        case .mono: return ["#1B1E24", "#3B4048", "#6B717B", "#A3A8B0", "#F0F2F5"]
        case .perSource: return sourceLevels(.github)
        case .custom: return custom(accent: "#E05D8A")
        }
    }

    /// Five shades built from one accent color, blended up from the empty-cell color.
    public static func custom(accent: String) -> [String] {
        let base = "#161B22"
        let safeAccent = HexColor.isValid(accent) ? accent : "#E05D8A"
        return [0, 0.3, 0.55, 0.8, 1].map { HexColor.mix(base, safeAccent, $0) }
    }

    /// Swatch colors for a theme picker.
    public static func swatch(_ theme: ThemeID, customAccent: String) -> [Color] {
        switch theme {
        case .perSource: return Source.allCases.map { Color(hex: sourceLevels($0)[4]) }
        case .custom: return custom(accent: customAccent).map(Color.init(hex:))
        default: return themeLevels(theme).map(Color.init(hex:))
        }
    }
}

public enum SourceStyle {
    public static func hex(_ source: Source) -> String {
        switch source {
        case .github: return "#2EA043"
        case .leetcode: return "#E6A020"
        case .codeforces: return "#3B82F6"
        }
    }

    public static func color(_ source: Source) -> Color { Color(hex: hex(source)) }

    public static let combinedHex = "#8A6CF0"
}

/// Codeforces rank colors (official on light backgrounds, brightened on dark ones)
/// and LeetCode badge colors.
public enum RankStyle {
    public static func hex(for rank: CodeforcesRank, onDark: Bool) -> String {
        switch rank {
        case .newbie: return onDark ? "#A3A3A3" : "#808080"
        case .pupil: return onDark ? "#55C955" : "#008000"
        case .specialist: return onDark ? "#20C4B5" : "#03A89E"
        case .expert: return onDark ? "#5B8CFF" : "#0000FF"
        case .candidateMaster: return onDark ? "#C85CFF" : "#AA00AA"
        case .master, .internationalMaster: return onDark ? "#FFA03A" : "#FF8C00"
        case .grandmaster, .internationalGrandmaster, .legendaryGrandmaster: return onDark ? "#FF4D4D" : "#FF0000"
        }
    }

    public static func leetCodeHex(badge: String?, onDark: Bool) -> String {
        switch badge?.lowercased() {
        case "guardian": return onDark ? "#E0B84D" : "#B8860B"
        case "knight": return onDark ? "#4FC3A1" : "#1E8C6E"
        default: return onDark ? "#C9D1D9" : "#57606A"
        }
    }

    public static func hex(for rating: RatingInfo, onDark: Bool) -> String {
        switch rating.kind {
        case .codeforces: return hex(for: CodeforcesRank(rating: rating.rating), onDark: onDark)
        case .leetcode: return leetCodeHex(badge: rating.badge, onDark: onDark)
        }
    }

    public static func color(for rating: RatingInfo, onDark: Bool) -> Color {
        Color(hex: hex(for: rating, onDark: onDark))
    }
}

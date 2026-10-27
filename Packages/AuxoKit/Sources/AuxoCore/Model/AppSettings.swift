import Foundation

public enum ThemeID: String, Codable, CaseIterable, Sendable, Identifiable {
    case perSource
    case classic
    case ocean
    case ember
    case mono
    case custom

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .perSource: return "Per source"
        case .classic: return "Classic"
        case .ocean: return "Ocean"
        case .ember: return "Ember"
        case .mono: return "Mono"
        case .custom: return "Custom"
        }
    }
}

/// App-wide settings, shared with the widget through the App Group.
public struct AppSettings: Codable, Equatable, Sendable {
    public var theme: ThemeID
    /// "#RRGGBB", used when `theme == .custom`.
    public var customAccentHex: String
    public var weekStartsOnMonday: Bool
    public var codeforcesAcceptedOnly: Bool
    /// Account IDs hidden on the app dashboard (widgets have their own selection).
    public var hiddenOnDashboard: [String]

    public init(theme: ThemeID = .perSource,
                customAccentHex: String = "#E05D8A",
                weekStartsOnMonday: Bool = false,
                codeforcesAcceptedOnly: Bool = true,
                hiddenOnDashboard: [String] = []) {
        self.theme = theme
        self.customAccentHex = customAccentHex
        self.weekStartsOnMonday = weekStartsOnMonday
        self.codeforcesAcceptedOnly = codeforcesAcceptedOnly
        self.hiddenOnDashboard = hiddenOnDashboard
    }

    enum CodingKeys: String, CodingKey {
        case theme, customAccentHex, weekStartsOnMonday, codeforcesAcceptedOnly, hiddenOnDashboard
    }

    // Tolerant decoding: settings written by an older or newer version never fail to load.
    public init(from decoder: Decoder) throws {
        let defaults = AppSettings()
        let c = try decoder.container(keyedBy: CodingKeys.self)
        theme = (try? c.decode(ThemeID.self, forKey: .theme)) ?? defaults.theme
        customAccentHex = (try? c.decode(String.self, forKey: .customAccentHex)) ?? defaults.customAccentHex
        weekStartsOnMonday = (try? c.decode(Bool.self, forKey: .weekStartsOnMonday)) ?? defaults.weekStartsOnMonday
        codeforcesAcceptedOnly = (try? c.decode(Bool.self, forKey: .codeforcesAcceptedOnly)) ?? defaults.codeforcesAcceptedOnly
        hiddenOnDashboard = (try? c.decode([String].self, forKey: .hiddenOnDashboard)) ?? defaults.hiddenOnDashboard
    }
}

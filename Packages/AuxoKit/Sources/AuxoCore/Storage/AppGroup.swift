import Foundation

/// The shared container that lets the app and the widget see the same accounts and data.
///
/// The App Group identifier comes from the `AuxoAppGroup` key in each target's Info.plist,
/// which the build fills in from `Config/Base.xcconfig` + your `Config/Local.xcconfig`.
public enum AppGroup {
    public static let infoPlistKey = "AuxoAppGroup"

    public static var identifier: String? {
        guard let raw = Bundle.main.object(forInfoDictionaryKey: infoPlistKey) as? String else { return nil }
        let value = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        // An unconfigured build leaves "", "$(…)" or a value starting with "." (empty team ID).
        guard !value.isEmpty, !value.hasPrefix("."), !value.contains("$(") else { return nil }
        return value
    }

    /// Directory for Auxo's files. Falls back to Application Support when no App Group is
    /// configured (the app still works; the widget just can't see its data).
    public static var containerURL: URL {
        #if canImport(Darwin)
        if let id = identifier,
           let url = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: id) {
            return url.appendingPathComponent("Auxo", isDirectory: true)
        }
        #endif
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        return base.appendingPathComponent("Auxo", isDirectory: true)
    }
}

import Foundation
#if canImport(Security)
import Security

/// Stores the GitHub token in the Keychain, never in plain files.
///
/// The item lives in the App Group's keychain access group so the widget can read it too.
/// If that group isn't available (an unsigned local build), it falls back to the app's
/// own keychain: the app works, but the widget can't refresh GitHub data by itself.
public enum TokenStore {
    private static let service = "auxo.github"
    private static let account = "token"

    private static func query(accessGroup: String?) -> [String: Any] {
        var q: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
        if let accessGroup {
            q[kSecAttrAccessGroup as String] = accessGroup
        }
        #if os(macOS)
        q[kSecUseDataProtectionKeychain as String] = true
        #endif
        return q
    }

    private static var groups: [String?] {
        if let group = AppGroup.identifier { return [group, nil] }
        return [nil]
    }

    public static func githubToken() -> String? {
        for group in groups {
            var q = query(accessGroup: group)
            q[kSecReturnData as String] = true
            q[kSecMatchLimit as String] = kSecMatchLimitOne
            var item: CFTypeRef?
            if SecItemCopyMatching(q as CFDictionary, &item) == errSecSuccess,
               let data = item as? Data,
               let token = String(data: data, encoding: .utf8),
               !token.isEmpty {
                return token
            }
        }
        return nil
    }

    /// Saves the token, or deletes it when `token` is nil. Returns false if saving failed.
    @discardableResult
    public static func setGitHubToken(_ token: String?) -> Bool {
        for group in groups {
            SecItemDelete(query(accessGroup: group) as CFDictionary)
        }
        guard let token, let data = token.data(using: .utf8), !token.isEmpty else { return true }

        for group in groups {
            var q = query(accessGroup: group)
            q[kSecValueData as String] = data
            q[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
            if SecItemAdd(q as CFDictionary, nil) == errSecSuccess {
                return true
            }
        }
        return false
    }
}
#endif

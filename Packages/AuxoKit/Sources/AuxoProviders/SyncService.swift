import Foundation
import AuxoCore

/// Fetches fresh data for accounts and saves snapshots. Used by both the app and the widget.
///
/// Each account is synced independently: one site failing never blocks the others, and a
/// failed sync keeps the previous data and records the error instead of wiping the heatmap.
public final class SyncService: @unchecked Sendable {
    public static let shared = SyncService()

    /// Don't re-fetch an account more often than this unless forced.
    public static let freshness: TimeInterval = 25 * 60
    /// History kept per account: a full 53-week grid.
    public static let historyDays = 371

    private let store: SharedStore
    private let providerFor: @Sendable (Source) -> any ActivityProvider
    private let tokenProvider: @Sendable () -> String?

    public init(store: SharedStore = .shared,
                providerFor: @escaping @Sendable (Source) -> any ActivityProvider = { ProviderRegistry.provider(for: $0) },
                tokenProvider: @escaping @Sendable () -> String? = { SyncService.keychainToken() }) {
        self.store = store
        self.providerFor = providerFor
        self.tokenProvider = tokenProvider
    }

    public static func keychainToken() -> String? {
        #if canImport(Security)
        return TokenStore.githubToken()
        #else
        return nil
        #endif
    }

    public func needsSync(_ account: Account, now: Date = Date()) -> Bool {
        guard let last = store.snapshot(for: account.id)?.lastAttempt else { return true }
        return now.timeIntervalSince(last) > Self.freshness
    }

    /// Syncs the given accounts one after another and returns their snapshots.
    @discardableResult
    public func sync(_ accounts: [Account], force: Bool = false) async -> [String: AccountSnapshot] {
        let settings = store.settings()
        let since = LocalDay.today().adding(days: -Self.historyDays)
        var results: [String: AccountSnapshot] = [:]

        for account in accounts {
            if Task.isCancelled { break }
            if !force && !needsSync(account) {
                if let existing = store.snapshot(for: account.id) {
                    results[account.id] = existing
                }
                continue
            }

            var snapshot = store.snapshot(for: account.id) ?? AccountSnapshot(accountID: account.id)
            snapshot.lastAttempt = Date()
            do {
                let result = try await fetch(account, since: since, settings: settings)
                snapshot.series = result.series
                snapshot.rating = result.rating
                snapshot.lastSuccess = Date()
                snapshot.lastError = nil
            } catch is CancellationError {
                break
            } catch {
                snapshot.lastError = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
            }
            store.saveSnapshot(snapshot)
            results[account.id] = snapshot
        }
        return results
    }

    /// One fetch with the current settings and sign-in. Used when adding an account.
    public func fetch(_ account: Account, since: LocalDay, settings: AppSettings) async throws -> ProviderResult {
        let options = FetchOptions(codeforcesAcceptedOnly: settings.codeforcesAcceptedOnly,
                                   githubToken: tokenProvider(),
                                   calendar: .current)
        return try await providerFor(account.source).fetch(handle: account.handle, since: since, options: options)
    }
}

import SwiftUI
import WidgetKit
import AuxoCore
import AuxoProviders

enum AddAccountError: LocalizedError {
    case invalidHandle(Source)
    case duplicate(Source, String)

    var errorDescription: String? {
        switch self {
        case .invalidHandle(let source): return source.handleHint
        case .duplicate(let source, let handle): return "\(source.displayName) · \(handle) is already added."
        }
    }
}

/// App state. Everything persistent goes through `SharedStore` so the widget sees it too.
@MainActor
final class AppModel: ObservableObject {
    @Published private(set) var accounts: [Account] = []
    @Published private(set) var snapshots: [String: AccountSnapshot] = [:]
    @Published private(set) var isSyncing = false
    @Published private(set) var hasGitHubToken = false
    /// Set by a widget tap (auxo://account/<id>); the dashboard scrolls to it and clears it.
    @Published var focusedAccountID: String?
    @Published var settings = AppSettings() {
        didSet {
            guard settings != oldValue else { return }
            store.saveSettings(settings)
            reloadWidgets()
        }
    }

    private let store: SharedStore
    private let sync: SyncService

    init(store: SharedStore = .shared, sync: SyncService = .shared) {
        self.store = store
        self.sync = sync
        load()
    }

    func load() {
        accounts = store.accounts()
        let saved = store.settings()
        if saved != settings { settings = saved }
        var loaded: [String: AccountSnapshot] = [:]
        for account in accounts {
            if let snapshot = store.snapshot(for: account.id) {
                loaded[account.id] = snapshot
            }
        }
        snapshots = loaded
        hasGitHubToken = TokenStore.githubToken() != nil
    }

    // MARK: Sync

    func refresh(force: Bool = false) async {
        guard !isSyncing, !accounts.isEmpty else { return }
        isSyncing = true
        defer { isSyncing = false }
        let results = await sync.sync(accounts, force: force)
        snapshots.merge(results) { _, new in new }
        reloadWidgets()
    }

    // MARK: Accounts

    func addAccount(source: Source, handle rawHandle: String) async throws {
        let handle = rawHandle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard source.isValidHandle(handle) else { throw AddAccountError.invalidHandle(source) }
        if isDuplicate(source, handle) { throw AddAccountError.duplicate(source, handle) }

        // Fetch first: this validates the handle and gets its exact spelling and data.
        var account = Account(source: source, handle: handle)
        let since = LocalDay.today().adding(days: -SyncService.historyDays)
        let result = try await sync.fetch(account, since: since, settings: settings)
        account.handle = result.canonicalHandle
        if isDuplicate(source, account.handle) { throw AddAccountError.duplicate(source, account.handle) }

        let now = Date()
        let snapshot = AccountSnapshot(accountID: account.id, series: result.series, rating: result.rating,
                                       lastSuccess: now, lastAttempt: now, lastError: nil)
        store.saveSnapshot(snapshot)
        accounts.append(account)
        store.saveAccounts(accounts)
        snapshots[account.id] = snapshot
        reloadWidgets()
    }

    func remove(_ account: Account) {
        accounts.removeAll { $0.id == account.id }
        store.saveAccounts(accounts)
        store.removeSnapshot(for: account.id)
        snapshots[account.id] = nil
        settings.hiddenOnDashboard.removeAll { $0 == account.id }
        reloadWidgets()
    }

    func move(from offsets: IndexSet, to destination: Int) {
        accounts.move(fromOffsets: offsets, toOffset: destination)
        store.saveAccounts(accounts)
        reloadWidgets()
    }

    private func isDuplicate(_ source: Source, _ handle: String) -> Bool {
        accounts.contains { $0.source == source && $0.handle.caseInsensitiveCompare(handle) == .orderedSame }
    }

    // MARK: Dashboard visibility

    func isShownOnDashboard(_ account: Account) -> Bool {
        !settings.hiddenOnDashboard.contains(account.id)
    }

    func toggleDashboard(_ account: Account) {
        if let index = settings.hiddenOnDashboard.firstIndex(of: account.id) {
            settings.hiddenOnDashboard.remove(at: index)
        } else {
            settings.hiddenOnDashboard.append(account.id)
        }
    }

    // MARK: GitHub sign-in

    /// Saves (or clears) the GitHub token. Returns false if the Keychain refused it.
    @discardableResult
    func setGitHubToken(_ token: String?) -> Bool {
        let ok = TokenStore.setGitHubToken(token)
        hasGitHubToken = TokenStore.githubToken() != nil
        if ok { reloadWidgets() }
        return ok
    }

    // MARK: Links

    func handle(url: URL) {
        guard url.scheme == "auxo" else { return }
        if url.host == "account", let id = url.pathComponents.last, accounts.contains(where: { $0.id == id }) {
            focusedAccountID = id
        } else {
            focusedAccountID = "all"
        }
    }

    func reloadWidgets() {
        WidgetCenter.shared.reloadAllTimelines()
    }
}

enum AuxoLinks {
    static let repository = URL(string: "https://github.com/Siddharth543/Auxo")!
}

enum GitHubConfig {
    /// OAuth App client ID for the device flow, from `AUXO_GITHUB_CLIENT_ID` in Config/Local.xcconfig.
    static var clientID: String? {
        guard let raw = Bundle.main.object(forInfoDictionaryKey: "AuxoGitHubClientID") as? String else { return nil }
        let value = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        return value.isEmpty || value.contains("$(") ? nil : value
    }
}

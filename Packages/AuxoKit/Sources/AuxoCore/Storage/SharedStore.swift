import Foundation

/// File-based storage shared by the app and the widget extension.
///
/// Layout inside the container:
///   accounts.json            – written by the app
///   settings.json            – written by the app
///   snapshots/<id>.json      – written by whichever process synced last
///
/// Separate files keep the two processes from overwriting each other's changes.
/// Every write is atomic, and reads always go to disk so each process sees the latest data.
public final class SharedStore: @unchecked Sendable {
    public static let shared = SharedStore(directory: AppGroup.containerURL)

    public let directory: URL
    private let lock = NSLock()
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    public init(directory: URL) {
        self.directory = directory
        // Default date strategy (seconds since 2001 as a Double) round-trips exactly.
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        self.encoder = encoder
        self.decoder = JSONDecoder()
    }

    private var accountsURL: URL { directory.appendingPathComponent("accounts.json") }
    private var settingsURL: URL { directory.appendingPathComponent("settings.json") }
    private var snapshotsDirectory: URL { directory.appendingPathComponent("snapshots", isDirectory: true) }

    private func snapshotURL(for accountID: String) -> URL {
        let safe = accountID.filter { $0.isLetter || $0.isNumber || $0 == "-" }
        return snapshotsDirectory.appendingPathComponent("\(safe).json")
    }

    // MARK: Accounts

    public func accounts() -> [Account] {
        read([Account].self, from: accountsURL) ?? []
    }

    public func saveAccounts(_ accounts: [Account]) {
        write(accounts, to: accountsURL)
    }

    // MARK: Settings

    public func settings() -> AppSettings {
        read(AppSettings.self, from: settingsURL) ?? AppSettings()
    }

    public func saveSettings(_ settings: AppSettings) {
        write(settings, to: settingsURL)
    }

    // MARK: Snapshots

    public func snapshot(for accountID: String) -> AccountSnapshot? {
        read(AccountSnapshot.self, from: snapshotURL(for: accountID))
    }

    public func saveSnapshot(_ snapshot: AccountSnapshot) {
        write(snapshot, to: snapshotURL(for: snapshot.accountID))
    }

    public func removeSnapshot(for accountID: String) {
        lock.lock()
        defer { lock.unlock() }
        try? FileManager.default.removeItem(at: snapshotURL(for: accountID))
    }

    // MARK: Plumbing

    private func read<T: Decodable>(_ type: T.Type, from url: URL) -> T? {
        lock.lock()
        defer { lock.unlock() }
        guard let data = try? Data(contentsOf: url) else { return nil }
        return try? decoder.decode(T.self, from: data)
    }

    private func write<T: Encodable>(_ value: T, to url: URL) {
        lock.lock()
        defer { lock.unlock() }
        do {
            try FileManager.default.createDirectory(at: url.deletingLastPathComponent(),
                                                    withIntermediateDirectories: true)
            let data = try encoder.encode(value)
            try data.write(to: url, options: .atomic)
        } catch {
            // Storage failures are not fatal: the next sync rewrites the file.
        }
    }
}

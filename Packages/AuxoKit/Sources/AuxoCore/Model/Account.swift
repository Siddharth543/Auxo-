import Foundation

/// One profile on one site, added by the user in the app.
public struct Account: Codable, Hashable, Identifiable, Sendable {
    public var id: String
    public var source: Source
    public var handle: String
    public var addedAt: Date

    public init(id: String = UUID().uuidString, source: Source, handle: String, addedAt: Date = Date()) {
        self.id = id
        self.source = source
        self.handle = handle
        self.addedAt = addedAt
    }
}

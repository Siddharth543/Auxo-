import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// The one seam between providers and the network, so tests can feed recorded responses.
public protocol HTTPTransport: Sendable {
    func send(_ request: URLRequest) async throws -> (Data, HTTPURLResponse)
}

public struct URLSessionTransport: HTTPTransport {
    private let session: URLSession

    public init(session: URLSession = .shared) {
        self.session = session
    }

    public func send(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw ProviderError.invalidResponse
        }
        return (data, http)
    }
}

/// Spaces out requests to one site. Safe to call concurrently: each caller reserves the
/// next free slot before sleeping, so callers never bunch up.
public actor RateLimiter {
    private let interval: TimeInterval
    private var nextSlot: Date = .distantPast

    public init(interval: TimeInterval) {
        self.interval = interval
    }

    public func wait() async {
        let now = Date()
        let slot = max(now, nextSlot)
        nextSlot = slot.addingTimeInterval(interval)
        let delay = slot.timeIntervalSince(now)
        if delay > 0 {
            try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
        }
    }
}

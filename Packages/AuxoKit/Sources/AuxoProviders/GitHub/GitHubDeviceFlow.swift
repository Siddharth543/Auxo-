import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
import AuxoCore

/// GitHub's OAuth device flow: the user types a short code at github.com/login/device.
/// Needs only a public client ID (no secret), so it's safe for an open-source app.
/// Setup: create an OAuth App on GitHub, tick "Enable Device Flow", and put its client ID
/// in `Config/Local.xcconfig` as `AUXO_GITHUB_CLIENT_ID`.
public struct GitHubDeviceFlow: Sendable {
    public struct Code: Sendable, Equatable {
        public let deviceCode: String
        public let userCode: String
        public let verificationURL: URL
        public let expiresIn: Int
        public let interval: Int
    }

    public enum FlowError: Error, LocalizedError, Equatable {
        case expired
        case denied
        case failed(String)

        public var errorDescription: String? {
            switch self {
            case .expired: return "The sign-in code expired. Start again."
            case .denied: return "Sign-in was cancelled on GitHub."
            case .failed(let message): return "GitHub sign-in failed: \(message)"
            }
        }
    }

    private let clientID: String
    private let transport: HTTPTransport

    public init(clientID: String, transport: HTTPTransport = URLSessionTransport()) {
        self.clientID = clientID
        self.transport = transport
    }

    struct CodeResponse: Decodable {
        let device_code: String?
        let user_code: String?
        let verification_uri: String?
        let expires_in: Int?
        let interval: Int?
        let error: String?
        let error_description: String?
    }

    struct TokenResponse: Decodable {
        let access_token: String?
        let error: String?
        let error_description: String?
        let interval: Int?
    }

    public func start() async throws -> Code {
        guard let url = URL(string: "https://github.com/login/device/code") else { throw ProviderError.invalidResponse }
        let request = HTTP.formPOST(url, fields: [("client_id", clientID), ("scope", "")])
        let (data, _) = try await transport.send(request)
        guard let response = try? JSONDecoder().decode(CodeResponse.self, from: data) else {
            throw FlowError.failed("unexpected response")
        }
        guard let deviceCode = response.device_code,
              let userCode = response.user_code,
              let verification = response.verification_uri.flatMap(URL.init(string:)) else {
            throw FlowError.failed(response.error_description ?? response.error ?? "no code returned")
        }
        return Code(deviceCode: deviceCode,
                    userCode: userCode,
                    verificationURL: verification,
                    expiresIn: response.expires_in ?? 900,
                    interval: response.interval ?? 5)
    }

    /// Polls until the user approves, then returns the access token. Cancellable.
    public func waitForToken(_ code: Code) async throws -> String {
        guard let url = URL(string: "https://github.com/login/oauth/access_token") else { throw ProviderError.invalidResponse }
        var interval = max(code.interval, 5)
        let deadline = Date().addingTimeInterval(TimeInterval(code.expiresIn))

        while Date() < deadline {
            try await Task.sleep(nanoseconds: UInt64(interval) * 1_000_000_000)
            let request = HTTP.formPOST(url, fields: [
                ("client_id", clientID),
                ("device_code", code.deviceCode),
                ("grant_type", "urn:ietf:params:oauth:grant-type:device_code"),
            ])
            let (data, _) = try await transport.send(request)
            guard let response = try? JSONDecoder().decode(TokenResponse.self, from: data) else { continue }
            if let token = response.access_token, !token.isEmpty {
                return token
            }
            switch response.error {
            case "authorization_pending", nil:
                continue
            case "slow_down":
                interval = response.interval ?? (interval + 5)
            case "expired_token":
                throw FlowError.expired
            case "access_denied":
                throw FlowError.denied
            default:
                throw FlowError.failed(response.error_description ?? response.error ?? "unknown error")
            }
        }
        throw FlowError.expired
    }
}

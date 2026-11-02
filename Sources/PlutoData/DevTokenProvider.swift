#if DEBUG
import Foundation
import PlutoDomain

/// Debug builds only: signing in asks the development issuer on the web origin (`/dev/token`) for a token. The token lives in
/// memory, is never logged, and nothing here exists in a release build.
public actor DevTokenProvider: TokenProvider {
    public typealias Fetch = @Sendable (URL) async throws -> Data

    public static let path = "/dev/token"

    private let endpoint: URL
    private let fetch: Fetch
    private var token: Token?
    private var signedIn = false

    public init(startURL: URL, fetch: @escaping Fetch = DevTokenProvider.postOverHTTPS) {
        var parts = URLComponents()
        parts.scheme = startURL.scheme
        parts.host = startURL.host
        parts.port = startURL.port
        parts.path = Self.path
        endpoint = parts.url ?? startURL
        self.fetch = fetch
    }

    public func current() -> Token? { signedIn ? token : nil }

    /// A new token, nil when signed out or when the issuer answers something that is not a token; throws when it cannot be reached.
    public func refresh() async throws -> Token? {
        guard signedIn else { return nil }
        let body = try await fetch(endpoint)
        guard let next = Self.parse(body) else { return nil }
        token = next
        return next
    }

    /// Signing in asks once in the background, so the first call of the page already has a token.
    public func signIn() {
        signedIn = true
        Task { _ = try? await self.refresh() }
    }

    public func signOut() {
        signedIn = false
        token = nil
    }

    static func parse(_ body: Data) -> Token? {
        guard let object = try? JSONSerialization.jsonObject(with: body) as? [String: Any],
              let accessToken = object["accessToken"] as? String, !accessToken.isEmpty,
              let expiresAt = (object["expiresAt"] as? NSNumber)?.int64Value else { return nil }
        return Token(accessToken: accessToken, expiresAt: expiresAt)
    }

    /// POST with short timeouts; only a 200 with a small body counts.
    @Sendable
    public static func postOverHTTPS(_ url: URL) async throws -> Data {
        var request = URLRequest(url: url, timeoutInterval: 5)
        request.httpMethod = "POST"
        let (data, response) = try await URLSession.shared.data(for: request)
        guard (response as? HTTPURLResponse)?.statusCode == 200, data.count <= 4096 else { throw URLError(.badServerResponse) }
        return data
    }
}
#endif

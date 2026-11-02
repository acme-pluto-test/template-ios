import Foundation

/// An access token and the second (epoch seconds) it expires at.
public struct Token: Equatable, Sendable, CustomStringConvertible, CustomDebugStringConvertible {
    public let accessToken: String
    public let expiresAt: Int64

    public init(accessToken: String, expiresAt: Int64) {
        self.accessToken = accessToken
        self.expiresAt = expiresAt
    }

    // keeps the credential out of logs and dumps (FR-MOB-01)
    public var description: String { "Token(accessToken: <redacted>, expiresAt: \(expiresAt))" }
    public var debugDescription: String { description }
}

/// Where the app gets the token it hands to the web app. It lives in memory only: no defaults, no URL, no log.
/// The real login (FR-MOB-01) replaces the fake implementation in PlutoData.
public protocol TokenProvider: Sendable {
    /// The token held now, or nil when signed out.
    func current() async -> Token?
    /// A new token, or nil when none can be had. May throw (the network is down).
    func refresh() async throws -> Token?
    func signIn() async
    func signOut() async
}

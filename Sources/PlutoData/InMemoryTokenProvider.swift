import Foundation
import PlutoDomain

/// A fake login for the template: signing in makes a token that expires in an hour. Held in memory only.
public actor InMemoryTokenProvider: TokenProvider {
    private var token: Token?
    private var counter = 0

    public init() {}

    public func current() -> Token? { token }

    public func refresh() -> Token? {
        guard token != nil else { return nil }
        let next = makeToken()
        token = next
        return next
    }

    public func signIn() { token = makeToken() }

    public func signOut() { token = nil }

    private func makeToken() -> Token {
        counter += 1
        return Token(accessToken: "demo-token-\(counter)", expiresAt: Int64(Date().timeIntervalSince1970) + 3600)
    }
}

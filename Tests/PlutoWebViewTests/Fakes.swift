import Foundation
import PlutoDomain
import PlutoWebView

@MainActor
final class RecordingChannel: PageChannel {
    var posted: [String] = []
    func post(_ text: String) { posted.append(text) }
}

struct Failure: Error {}

actor FakeTokens: TokenProvider {
    var token: Token?
    var next: Token?
    var failure: (any Error)?
    private(set) var refreshes = 0

    init(token: Token? = nil, next: Token? = nil, failure: (any Error)? = nil) {
        self.token = token
        self.next = next
        self.failure = failure
    }

    func current() -> Token? { token }

    func refresh() throws -> Token? {
        refreshes += 1
        if let failure { throw failure }
        if let next { token = next }
        return next
    }

    func signIn() { token = Token(accessToken: "signed-in-token", expiresAt: 1_900_000_000) }
    func signOut() { token = nil }
    func set(failure: (any Error)?, next: Token?) { self.failure = failure; self.next = next }
}

let appOrigin = "https://app.example.com"
let ready = #"{"version":1,"type":"navigation.ready","payload":{"route":"/"}}"#
let refreshRequest = #"{"version":1,"type":"auth.refresh.request","payload":{}}"#

func allowlist(_ entries: String...) throws -> Allowlist { try Allowlist(entries) }

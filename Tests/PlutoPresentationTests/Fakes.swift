import Foundation
import PlutoDomain
import PlutoWebView

@MainActor
final class RecordingChannel: PageChannel {
    var posted: [String] = []
    func post(_ text: String) { posted.append(text) }
}

actor FakeTokens: TokenProvider {
    var token: Token?
    init(token: Token? = nil) { self.token = token }
    func current() -> Token? { token }
    func refresh() -> Token? { token }
    func signIn() { token = Token(accessToken: "signed-in-token", expiresAt: 1_900_000_000) }
    func signOut() { token = nil }
}

let appOrigin = "https://app.example.com"
let ready = #"{"version":1,"type":"navigation.ready","payload":{"route":"/"}}"#
func config() throws -> WebConfig { try WebConfig(startURL: "\(appOrigin)/", allowlist: try Allowlist([appOrigin])) }

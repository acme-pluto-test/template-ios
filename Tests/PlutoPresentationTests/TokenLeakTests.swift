import Foundation
import PlutoBridge
import PlutoData
import PlutoDomain
import PlutoPresentation
import PlutoWebView
import Testing

@MainActor
@Suite struct TokenLeakTests {
    @Test("keeps the token out of URLs, logs, defaults and descriptions")
    func noLeak() async throws {
        let tokens = InMemoryTokenProvider()
        await tokens.signIn()
        let real = try #require(await tokens.current()).accessToken
        var logs: [String] = []
        let box = LogBox()
        let model = WebViewModel(tokens: tokens, config: try config()) { box.lines.append($0) }
        let channel = RecordingChannel()

        await model.host.onPageMessage(ready, sourceOrigin: appOrigin, reply: channel)
        await model.host.onPageMessage(#"{"version":1,"type":"auth.refresh.request","payload":{}}"#, sourceOrigin: appOrigin, reply: channel)
        await model.host.onPageMessage("garbage with \(real) inside", sourceOrigin: appOrigin, reply: channel)
        await model.host.onPageMessage(ready, sourceOrigin: "https://evil.com", reply: channel)
        logs = box.lines
        #expect(channel.posted.contains { $0.contains("demo-token") }, "the token goes out through the bridge, and only there")

        // no URL the web screen loads, no log line
        #expect(!model.state.url.contains(real))
        #expect(!logs.isEmpty && logs.allSatisfy { !$0.contains(real) }, "logs: \(logs)")
        // no state a screen holds, and no state restoration: none of the state types is Codable
        let home = HomeViewModel(tokens: tokens)
        await home.load()
        #expect(!"\(home.state)".contains(real) && !"\(model.state)".contains(real))
        #expect(!(model.state is any Codable) && !(home.state is any Codable) && !(Token(accessToken: real, expiresAt: 1) is any Codable))
        // no defaults written
        #expect(UserDefaults.standard.dictionaryRepresentation().values.allSatisfy { !"\($0)".contains(real) })
        // no description of a token or of a message that carries one
        let message = NativeToWebMessage.authToken(accessToken: real, expiresAt: 1)
        #expect(!"\(message)".contains(real) && !String(reflecting: message).contains(real))
        #expect(!"\(Token(accessToken: real, expiresAt: 1))".contains(real))
    }

    @Test("forgets the token when the process is recreated")
    func recreated() async throws {
        let before = InMemoryTokenProvider()
        await before.signIn()
        #expect(await before.current() != nil)
        let after = InMemoryTokenProvider() // a new process builds a new provider
        #expect(await after.current() == nil)
        let home = HomeViewModel(tokens: after)
        await home.load()
        #expect(!home.state.signedIn)
    }
}

@MainActor
final class LogBox { var lines: [String] = [] }

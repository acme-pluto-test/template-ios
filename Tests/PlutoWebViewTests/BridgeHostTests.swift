import Foundation
import PlutoBridge
import PlutoDomain
import PlutoWebView
import Testing

@MainActor
@Suite struct BridgeHostTests {
    let tokens = FakeTokens()
    let channel = RecordingChannel()
    let host: BridgeHost
    let box = LogBox()

    init() throws {
        host = BridgeHost(policy: OriginPolicy(try Allowlist([appOrigin])), tokens: tokens) { [box] in box.lines.append($0) }
    }

    func sent() throws -> [NativeToWebMessage] { try channel.posted.map { try Bridge.parseNativeToWeb(Data($0.utf8)) } }
    func makeReady(origin: String = appOrigin) async { await host.onPageMessage(ready, sourceOrigin: origin, reply: channel) }

    @Test("sends dark theme with the accent colour")
    func dark() async throws {
        await makeReady()
        host.sendTheme(dark: true, accentRGB: 0x0A84FF)
        #expect(try sent() == [.themeChanged(mode: .dark, accentColor: "#0A84FF")])
    }

    @Test("sends light theme")
    func light() async throws {
        await makeReady()
        host.sendTheme(dark: false, accentRGB: 0x0B57D0)
        host.sendTheme(dark: false, accentRGB: 0x0B57D0)
        #expect(try sent() == [.themeChanged(mode: .light, accentColor: "#0B57D0")])
    }

    @Test("sends the safe area and again when it changes")
    func safeArea() async throws {
        await makeReady()
        host.sendSafeArea(top: 47, right: 0, bottom: 34, left: 0)
        host.sendSafeArea(top: 47, right: 0, bottom: 34, left: 0)
        host.sendSafeArea(top: 24, right: 0, bottom: 0, left: 0)
        #expect(try sent() == [.safeAreaChanged(top: 47, right: 0, bottom: 34, left: 0), .safeAreaChanged(top: 24, right: 0, bottom: 0, left: 0)])
    }

    @Test("answers navigation ready with theme, safe area and token")
    func readyWithToken() async throws {
        await tokens.set(failure: nil, next: nil)
        let withToken = FakeTokens(token: Token(accessToken: "secret-token-1", expiresAt: 1_900_000_000))
        let host = BridgeHost(policy: OriginPolicy(try Allowlist([appOrigin])), tokens: withToken)
        host.sendTheme(dark: true, accentRGB: 0x0A84FF)
        host.sendSafeArea(top: 47, right: 0, bottom: 34, left: 0)
        #expect(channel.posted.isEmpty, "nothing is sent before the page is ready")
        await host.onPageMessage(ready, sourceOrigin: appOrigin, reply: channel)
        #expect(try sent() == [
            .themeChanged(mode: .dark, accentColor: "#0A84FF"),
            .safeAreaChanged(top: 47, right: 0, bottom: 34, left: 0),
            .authToken(accessToken: "secret-token-1", expiresAt: 1_900_000_000),
        ])
    }

    @Test("answers navigation ready without a token when there is none")
    func readyWithoutToken() async throws {
        host.sendTheme(dark: false, accentRGB: 0x0B57D0)
        await makeReady()
        #expect(try sent() == [.themeChanged(mode: .light, accentColor: "#0B57D0")])
    }

    @Test("answers auth refresh request with the new token")
    func refresh() async throws {
        await makeReady()
        await tokens.set(failure: nil, next: Token(accessToken: "secret-token-2", expiresAt: 1_900_000_100))
        await host.onPageMessage(#"{"version":1,"type":"auth.refresh.request","payload":{"reason":"expired"}}"#, sourceOrigin: appOrigin, reply: channel)
        #expect(await tokens.refreshes == 1)
        #expect(try sent() == [.authToken(accessToken: "secret-token-2", expiresAt: 1_900_000_100)])
    }

    @Test("sends nothing when refresh returns no token")
    func refreshNothing() async throws {
        await makeReady()
        await host.onPageMessage(refreshRequest, sourceOrigin: appOrigin, reply: channel)
        #expect(await tokens.refreshes == 1)
        #expect(channel.posted.isEmpty)
    }

    @Test("survives a refresh that throws")
    func refreshThrows() async throws {
        await makeReady()
        await tokens.set(failure: Failure(), next: nil)
        await host.onPageMessage(refreshRequest, sourceOrigin: appOrigin, reply: channel)
        #expect(await tokens.refreshes == 1)
        #expect(channel.posted.isEmpty, "the page gets no token")
        #expect(box.lines.contains { $0.contains("token refresh failed") })
        await tokens.set(failure: nil, next: Token(accessToken: "secret-token-10", expiresAt: 1_900_000_200))
        await host.onPageMessage(refreshRequest, sourceOrigin: appOrigin, reply: channel)
        #expect(try sent() == [.authToken(accessToken: "secret-token-10", expiresAt: 1_900_000_200)], "the page may ask again")
    }

    @Test("ignores invalid, oversized and foreign-origin messages")
    func ignores() async throws {
        host.sendTheme(dark: true, accentRGB: 0x0A84FF)
        await makeReady()
        channel.posted.removeAll()
        let bad = [
            "an auth.token sent by the page": #"{"version":1,"type":"auth.token","payload":{"accessToken":"x","expiresAt":1}}"#,
            "65537 bytes": padded(65_537),
            "not JSON": "this is not json",
            "an unknown field": #"{"version":1,"type":"navigation.ready","payload":{"route":"/","extra":1}}"#,
            "version 2": #"{"version":2,"type":"navigation.ready","payload":{"route":"/"}}"#,
        ]
        for (what, text) in bad {
            await host.onPageMessage(text, sourceOrigin: appOrigin, reply: channel)
            #expect(channel.posted.isEmpty, "\(what) must send nothing")
        }
        for origin in ["https://evil.com", "http://app.example.com", "https://app.example.com.evil.com", "null", ""] {
            await makeReady(origin: origin)
            await host.onPageMessage(refreshRequest, sourceOrigin: origin, reply: channel)
            #expect(channel.posted.isEmpty, "a message from '\(origin)' must send nothing")
        }
        #expect(await tokens.refreshes == 0, "a refused message must not ask for a token")
        #expect(!box.lines.isEmpty)
    }

    @Test("accepts a message of exactly 65536 bytes and ignores one more byte")
    func boundary() async throws {
        host.sendTheme(dark: true, accentRGB: 0x0A84FF)
        #expect(padded(65_536).utf8.count == 65_536)
        await host.onPageMessage(padded(65_536), sourceOrigin: appOrigin, reply: channel)
        #expect(channel.posted.count == 1, "the largest allowed message is answered")
        channel.posted.removeAll()
        await host.onPageMessage(padded(65_537), sourceOrigin: appOrigin, reply: channel)
        #expect(channel.posted.isEmpty, "one byte more is ignored")
        // 65536 characters but 65537 bytes: a count of characters would let it through
        var wide = padded(65_536)
        if let first = wide.range(of: "aaaa") { wide.replaceSubrange(first, with: "éaaa") }
        #expect(wide.count == 65_536 && wide.utf8.count == 65_537)
        await host.onPageMessage(wide, sourceOrigin: appOrigin, reply: channel)
        #expect(channel.posted.isEmpty, "bytes are counted, not characters")
    }

    func padded(_ bytes: Int) -> String {
        let frame = #"{"version":1,"type":"navigation.ready","payload":{"route":""}}"#
        return frame.replacingOccurrences(of: #""route":"""#, with: #""route":"\#(String(repeating: "a", count: bytes - frame.utf8.count))""#)
    }
}

@MainActor
final class LogBox { var lines: [String] = [] }

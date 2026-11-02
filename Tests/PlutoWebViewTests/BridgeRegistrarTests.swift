import PlutoDomain
import PlutoWebView
import Testing

@MainActor
final class FakeRegistry: ScriptHandlerRegistry {
    var added: [(name: String, handler: @MainActor (PageMessage, any PageChannel) async -> Void)] = []
    func add(name: String, handler: @escaping @MainActor (PageMessage, any PageChannel) async -> Void) { added.append((name, handler)) }
}

@MainActor
@Suite struct BridgeRegistrarTests {
    @Test("registers the handler under the name pluto and forwards the main frame only")
    func registers() async throws {
        let registry = FakeRegistry()
        let host = BridgeHost(policy: OriginPolicy(try Allowlist([appOrigin])), tokens: FakeTokens())
        BridgeRegistrar(registry: registry).register(host: host)
        #expect(registry.added.count == 1)
        #expect(registry.added.first?.name == "pluto")
        #expect(BridgeRegistrar.handlerName == "pluto")

        let channel = RecordingChannel()
        host.sendTheme(dark: true, accentRGB: 0x0A84FF)
        let handler = try #require(registry.added.first?.handler)
        await handler(PageMessage(text: ready, scheme: "https", host: "app.example.com", port: 443, isMainFrame: false), channel)
        #expect(channel.posted.isEmpty, "a message from a subframe is not even looked at")
        await handler(PageMessage(text: ready, scheme: "https", host: "evil.com", port: 443, isMainFrame: true), channel)
        #expect(channel.posted.isEmpty)
        await handler(PageMessage(text: ready, scheme: "https", host: "app.example.com", port: 443, isMainFrame: true), channel)
        #expect(channel.posted.count == 1)
    }

    @Test("the sender origin joins scheme, host and a non default port")
    func origin() {
        #expect(PageMessage(text: "", scheme: "https", host: "a.example.com", port: 443, isMainFrame: true).origin == "https://a.example.com")
        #expect(PageMessage(text: "", scheme: "https", host: "a.example.com", port: 0, isMainFrame: true).origin == "https://a.example.com")
        #expect(PageMessage(text: "", scheme: "https", host: "a.example.com", port: 8443, isMainFrame: true).origin == "https://a.example.com:8443")
        #expect(PageMessage(text: "", scheme: "http", host: "a.example.com", port: 80, isMainFrame: true).origin == "http://a.example.com")
    }
}

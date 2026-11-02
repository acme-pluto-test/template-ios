import PlutoWebView
import Testing

@Suite struct OriginPolicyTests {
    let policy: OriginPolicy

    init() throws { policy = OriginPolicy(try Allowlist(["https://app.example.com"])) }

    @Test("allows an https origin of the allowlist")
    func allows() throws {
        for url in ["https://app.example.com", "https://app.example.com/a", "https://APP.example.com/x?y=1#z", "https://app.example.com:443/"] {
            #expect(policy.allows(url), "\(url)")
        }
        let withPort = OriginPolicy(try Allowlist(["https://app.example.com:8443"]))
        #expect(withPort.allows("https://app.example.com:8443/path"))
        #expect(!withPort.allows("https://app.example.com/path"))
        #expect(policy.allowsOrigin("https://app.example.com"))
        #expect(!policy.allowsOrigin("https://evil.com"))
        #expect(!policy.allowsOrigin("https://app.example.com/"), "an origin has no path, a trailing slash fails closed")
        #expect(!policy.allowsOrigin("null"))
    }

    @Test("drops every URL outside the allowlist")
    func drops() {
        let dropped = [
            "http://app.example.com", "https://app.example.com.evil.com", "https://evil.com/?https://app.example.com",
            "https://evil.com#https://app.example.com", "https://app.example.com@evil.com/",
            "https://user:pass@app.example.com/",
            "https://app.example.com:8443", "https://sub.app.example.com", "file:///var/mobile/index.html", "javascript:alert(1)",
            "data:text/html,hi", "about:blank", "", "   ", " https://app.example.com", "not a url",
            "https://app.example.com:0", "https://app.example.com:65536",
            "https://[::1]/", "https://app.example.com./", "https://exämple.com/", "https://xn--bcher-kva.example/",
        ]
        for url in dropped { #expect(!policy.allows(url), "should drop '\(url)'") }
        #expect(!policy.allowsOrigin("*"))
    }

    @Test("rejects an allowlist entry that is not an exact https origin")
    func rejects() throws {
        let entries = [
            "*", "https://*.example.com", "http://app.example.com", "https://app.example.com/path", "app.example.com", "https://", "",
            "https://app.example.com:0", "https://app.example.com:65536", "https://app.example.com:99999",
            "https://[::1]", "https://app.example.com.", "https://exämple.com",
        ]
        for entry in entries { #expect(throws: ConfigError.self) { try Allowlist([entry]) }; _ = entry }
        #expect(throws: ConfigError.empty) { try Allowlist([]) }
        let parsed = try Allowlist(parsing: " https://A.example.com , https://b.example.com:8443,")
        #expect(parsed.origins == ["https://a.example.com", "https://b.example.com:8443"])
        #expect(try !Allowlist(["https://app.example.com:65535"]).origins.isEmpty)
    }

    @Test("a start URL outside the allowlist is refused and the Info.plist is read")
    func config() throws {
        #expect(throws: ConfigError.self) { try WebConfig(startURL: "https://evil.com/", allowlist: try Allowlist(["https://app.example.com"])) }
        _ = try WebConfig(startURL: "https://app.example.com/", allowlist: try Allowlist(["https://app.example.com"]))
        let info: [String: Any] = ["PlutoWebAllowlist": "https://app.example.com", "PlutoWebStartURL": "https://app.example.com/"]
        #expect(try WebConfig(infoDictionary: info).startURL == "https://app.example.com/")
        #expect(throws: ConfigError.missing("PlutoWebAllowlist")) { try WebConfig(infoDictionary: [:]) }
        #expect(throws: ConfigError.missing("PlutoWebStartURL")) { try WebConfig(infoDictionary: ["PlutoWebAllowlist": "https://app.example.com"]) }
    }
}

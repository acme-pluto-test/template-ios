import Foundation

/// The exact https origins the web view may load and talk to. An entry is `https://host` or `https://host:port`:
/// no path, no wildcard, no other scheme (door 4).
public struct Allowlist: Equatable, Sendable {
    public let origins: Set<String>

    public init(_ entries: [String]) throws {
        var set = Set<String>()
        for entry in entries {
            guard let origin = normalise(entry) else { throw ConfigError.notAnExactOrigin(entry) }
            set.insert(origin)
        }
        guard !set.isEmpty else { throw ConfigError.empty }
        origins = set
    }

    /// Parses a comma separated list.
    public init(parsing list: String) throws {
        try self.init(list.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty })
    }
}

public enum ConfigError: Error, Equatable {
    case notAnExactOrigin(String)
    case empty
    case startOutsideAllowlist(String)
    case missing(String)
}

/// Decides every navigation: allowed only when the URL's origin equals an entry of the allowlist.
public struct OriginPolicy: Sendable {
    public let allowlist: Allowlist

    public init(_ allowlist: Allowlist) { self.allowlist = allowlist }

    public func allows(_ url: String) -> Bool {
        guard let origin = originOf(url) else { return false }
        return allowlist.origins.contains(origin)
    }

    /// True when `origin` (as a web view reports it: scheme, host, optional port) is one of the allowed origins.
    public func allowsOrigin(_ origin: String) -> Bool {
        guard let normal = normalise(origin) else { return false }
        return allowlist.origins.contains(normal)
    }
}

/// What the web screen needs to know about the web app: where it starts and which origins it may use.
public struct WebConfig: Equatable, Sendable {
    public let startURL: String
    public let allowlist: Allowlist

    public init(startURL: String, allowlist: Allowlist) throws {
        guard OriginPolicy(allowlist).allows(startURL) else { throw ConfigError.startOutsideAllowlist(startURL) }
        self.startURL = startURL
        self.allowlist = allowlist
    }

    /// Reads `PlutoWebAllowlist` and `PlutoWebStartURL` from an Info.plist dictionary.
    public init(infoDictionary: [String: Any]?) throws {
        guard let list = infoDictionary?["PlutoWebAllowlist"] as? String else { throw ConfigError.missing("PlutoWebAllowlist") }
        guard let start = infoDictionary?["PlutoWebStartURL"] as? String else { throw ConfigError.missing("PlutoWebStartURL") }
        try self.init(startURL: start, allowlist: try Allowlist(parsing: list))
    }
}

private let httpsPort = 443
private let maxPort = 65535

/// The origin of an https URL as `https://host` or `https://host:port`, or nil for anything else.
func originOf(_ url: String) -> String? {
    guard !url.isEmpty, url == url.trimmingCharacters(in: .whitespacesAndNewlines),
          let components = URLComponents(string: url),
          components.scheme?.lowercased() == "https",
          components.user == nil, components.password == nil,
          let host = components.host, isDNSName(host) else { return nil }
    let port = components.port
    if let port, !(1...maxPort).contains(port) { return nil }
    let suffix = (port == nil || port == httpsPort) ? "" : ":\(port!)"
    return "https://" + host.lowercased() + suffix
}

/// An exact origin (no path, no query) normalised, or nil when it is not one.
func normalise(_ origin: String) -> String? {
    let lower = origin.lowercased()
    guard lower.hasPrefix("https://"), !lower.dropFirst(8).contains("/"), !lower.contains("?"), !lower.contains("#"), !lower.contains("@"),
          !lower.contains("*") else { return nil }
    return originOf(lower)
}

/// An ASCII DNS name: letters, digits and hyphens in labels joined by dots, no trailing dot. IPv6 literals, unicode and
/// trailing-dot hosts are refused because the sender's origin could never be matched against them reliably (fail closed).
private func isDNSName(_ host: String) -> Bool {
    host.range(of: #"^[A-Za-z0-9]([A-Za-z0-9-]*[A-Za-z0-9])?(\.[A-Za-z0-9]([A-Za-z0-9-]*[A-Za-z0-9])?)*$"#, options: .regularExpression) != nil
}

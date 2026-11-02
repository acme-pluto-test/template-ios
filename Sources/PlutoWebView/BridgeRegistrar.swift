import Foundation

/// A message from the page as the WKScriptMessage glue reports it: the text and who sent it.
public struct PageMessage: Sendable, Equatable {
    public let text: String
    public let scheme: String
    public let host: String
    public let port: Int
    public let isMainFrame: Bool

    public init(text: String, scheme: String, host: String, port: Int, isMainFrame: Bool) {
        self.text = text
        self.scheme = scheme
        self.host = host
        self.port = port
        self.isMainFrame = isMainFrame
    }

    /// The sender's origin as scheme, host and optional port joined (the port is left out when it is the scheme's default).
    public var origin: String {
        let defaultPort = scheme == "https" ? 443 : 80
        return port == 0 || port == defaultPort ? "\(scheme)://\(host)" : "\(scheme)://\(host):\(port)"
    }
}

/// The WKUserContentController side, behind a protocol so the registration rule can be proven on the Mac.
@MainActor
public protocol ScriptHandlerRegistry {
    func add(name: String, handler: @escaping @MainActor (PageMessage, any PageChannel) async -> Void)
}

/// Registers the bridge handler under the name `pluto` and hands the host the messages of the main frame only.
@MainActor
public struct BridgeRegistrar {
    public static let handlerName = "pluto"
    private let registry: any ScriptHandlerRegistry

    public init(registry: any ScriptHandlerRegistry) { self.registry = registry }

    public func register(host: BridgeHost) {
        registry.add(name: Self.handlerName) { message, reply in
            guard message.isMainFrame else { return }
            await host.onPageMessage(message.text, sourceOrigin: message.origin, reply: reply)
        }
    }
}

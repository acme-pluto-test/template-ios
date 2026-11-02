import PlutoPresentation
import PlutoWebView
import SwiftUI
import WebKit

/// The only place a WKWebView is created (door 4): JavaScript on, every navigation decided by the origin policy, one script
/// message handler in the page world, answers sent with callAsyncJavaScript and never with an interpolated script.
/// A device proves it (see the plan).
@MainActor
enum WebViewFactory {
    static func make(model: WebViewModel, coordinator: WebCoordinator) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.defaultWebpagePreferences.allowsContentJavaScript = true
        let registry = ScriptRegistry(controller: configuration.userContentController)
        BridgeRegistrar(registry: registry).register(host: model.host)

        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.navigationDelegate = coordinator
        #if DEBUG
        webView.isInspectable = true
        #endif
        return webView
    }
}

/// Gives the WKUserContentController to the registrar: the handler is added to the page world, the one the web app can reach.
@MainActor
final class ScriptRegistry: ScriptHandlerRegistry {
    private let controller: WKUserContentController
    private var handlers: [ScriptHandler] = []

    init(controller: WKUserContentController) { self.controller = controller }

    func add(name: String, handler: @escaping @MainActor (PageMessage, any PageChannel) async -> Void) {
        let scriptHandler = ScriptHandler(handler: handler)
        handlers.append(scriptHandler)
        controller.add(scriptHandler, contentWorld: .page, name: name)
    }
}

@MainActor
final class ScriptHandler: NSObject, WKScriptMessageHandler {
    private let handler: @MainActor (PageMessage, any PageChannel) async -> Void

    init(handler: @escaping @MainActor (PageMessage, any PageChannel) async -> Void) { self.handler = handler }

    func userContentController(_ controller: WKUserContentController, didReceive message: WKScriptMessage) {
        guard let text = message.body as? String else { return }
        let origin = message.frameInfo.securityOrigin
        let page = PageMessage(text: text, scheme: origin.protocol, host: origin.host, port: origin.port, isMainFrame: message.frameInfo.isMainFrame)
        let reply = WebViewReply(webView: message.webView)
        Task { await handler(page, reply) }
    }
}

/// Answers the page: the encoded message goes in as an argument, never into the script text.
@MainActor
final class WebViewReply: PageChannel {
    private weak var webView: WKWebView?

    init(webView: WKWebView?) { self.webView = webView }

    func post(_ text: String) {
        webView?.callAsyncJavaScript(
            "window.pluto && window.pluto.receive && window.pluto.receive(message)",
            arguments: ["message": text],
            in: nil,
            in: .page,
            completionHandler: nil
        )
    }
}

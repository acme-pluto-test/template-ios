import PlutoPresentation
import PlutoWebView
import WebKit

/// The navigation delegate: the origin policy decides every navigation, and the page's progress goes to the view model.
@MainActor
final class WebCoordinator: NSObject, WKNavigationDelegate {
    private let model: WebViewModel

    init(model: WebViewModel) { self.model = model }

    func webView(
        _ webView: WKWebView,
        decidePolicyFor navigationAction: WKNavigationAction,
        decisionHandler: @escaping @MainActor (WKNavigationActionPolicy) -> Void
    ) {
        let allowed = navigationAction.request.url.map { model.policy.allows($0.absoluteString) } ?? false
        decisionHandler(allowed ? .allow : .cancel)
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) { model.pageFinished() }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: any Error) { model.loadFailed() }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: any Error) { model.loadFailed() }
}

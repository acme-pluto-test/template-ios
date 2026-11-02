import PlutoPresentation
import SwiftUI
import UIKit
import WebKit

/// The real page, drawn by the WKWebView the factory builds. It also feeds the theme and the safe area to the bridge.
struct PlutoWebViewRepresentable: UIViewRepresentable {
    let model: WebViewModel
    @Environment(\.colorScheme) private var colorScheme

    func makeCoordinator() -> WebCoordinator { WebCoordinator(model: model) }

    func makeUIView(context: Context) -> WKWebView {
        WebViewFactory.make(model: model, coordinator: context.coordinator)
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        model.host.sendTheme(dark: colorScheme == .dark, accentRGB: 0x0A84FF)
        let insets = webView.window?.safeAreaInsets ?? .zero
        model.host.sendSafeArea(top: insets.top, right: insets.right, bottom: insets.bottom, left: insets.left)
        if webView.tag != model.state.reloads + 1 {
            webView.tag = model.state.reloads + 1
            if let url = URL(string: model.state.url) { webView.load(URLRequest(url: url)) }
        }
    }
}

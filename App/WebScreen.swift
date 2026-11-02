import PlutoPresentation
import SwiftUI

/// The web screen. `-ui-testing` swaps the page for a stand-in so the UI test needs no network.
struct WebScreen: View {
    let model: WebViewModel

    var body: some View {
        ZStack {
            if ProcessInfo.processInfo.arguments.contains("-ui-testing") {
                Color.clear.accessibilityIdentifier("web-page-stand-in")
            } else {
                PlutoWebViewRepresentable(model: model)
            }
            if model.state.status == .failed {
                VStack(spacing: 16) {
                    Text("The page could not be loaded")
                    Button("Try again") { model.retry() }
                        .buttonStyle(.borderedProminent)
                }
                .padding()
            }
        }
        .accessibilityIdentifier("web-screen")
        .onAppear {
            // the UI test asks for a page that fails, to see the failure state and the retry without a network
            if ProcessInfo.processInfo.arguments.contains("-ui-testing-failed") { model.loadFailed() }
        }
        .navigationTitle("Web")
        .navigationBarTitleDisplayMode(.inline)
    }
}

import Foundation
import PlutoData
import PlutoDomain
import PlutoPresentation
import PlutoWebView
import SwiftUI

@main
struct PlutoApp: App {
    private let tokens: any TokenProvider
    private let config: WebConfig?

    init() {
        let parsed = try? WebConfig(infoDictionary: Bundle.main.infoDictionary)
        config = parsed
        #if DEBUG
        // Debug builds ask the development issuer of the reference scenario on the web origin; release builds never contain it.
        if let parsed, let start = URL(string: parsed.startURL) {
            tokens = DevTokenProvider(startURL: start)
        } else {
            tokens = InMemoryTokenProvider()
        }
        #else
        tokens = InMemoryTokenProvider()
        #endif
    }

    var body: some Scene {
        WindowGroup {
            if let config {
                RootView(tokens: tokens, config: config)
            } else {
                // a missing or wrong allowlist is a build mistake: the app shows it instead of loading anything
                Text("The web allowlist is missing or not an exact https origin.").padding()
            }
        }
    }
}

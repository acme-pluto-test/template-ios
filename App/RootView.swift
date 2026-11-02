import PlutoDomain
import PlutoPresentation
import PlutoWebView
import SwiftUI

struct RootView: View {
    @State private var home: HomeViewModel
    @State private var web: WebViewModel
    @State private var path: [Route] = []

    enum Route: Hashable { case web }

    init(tokens: any TokenProvider, config: WebConfig) {
        _home = State(initialValue: HomeViewModel(tokens: tokens))
        _web = State(initialValue: WebViewModel(tokens: tokens, config: config))
    }

    var body: some View {
        NavigationStack(path: $path) {
            HomeView(model: home) { path.append(.web) }
                .navigationDestination(for: Route.self) { _ in WebScreen(model: web) }
        }
    }
}

import PlutoPresentation
import SwiftUI

struct HomeView: View {
    let model: HomeViewModel
    let openWeb: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Text(model.state.title).font(.largeTitle).accessibilityIdentifier("home-title")
            Text(model.state.signedIn ? "Signed in" : "Signed out")
            Button("Open web app", action: openWeb)
                .buttonStyle(.borderedProminent)
            Button(model.state.signedIn ? "Sign out" : "Sign in") {
                Task { if model.state.signedIn { await model.signOut() } else { await model.signIn() } }
            }
        }
        .padding()
        .task { await model.load() }
    }
}

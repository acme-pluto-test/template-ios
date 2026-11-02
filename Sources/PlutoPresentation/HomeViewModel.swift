import Observation
import PlutoDomain

/// Everything the home screen shows; immutable, replaced as a whole.
public struct HomeState: Equatable, Sendable {
    public var title: String
    public var signedIn: Bool

    public init(title: String = "Pluto", signedIn: Bool = false) {
        self.title = title
        self.signedIn = signedIn
    }
}

@MainActor
@Observable
public final class HomeViewModel {
    public private(set) var state: HomeState
    private let tokens: any TokenProvider

    public init(tokens: any TokenProvider) {
        self.tokens = tokens
        state = HomeState()
    }

    public func load() async {
        state = HomeState(title: state.title, signedIn: await tokens.current() != nil)
    }

    public func signIn() async {
        await tokens.signIn()
        state = HomeState(title: state.title, signedIn: true)
    }

    public func signOut() async {
        await tokens.signOut()
        state = HomeState(title: state.title, signedIn: false)
    }
}

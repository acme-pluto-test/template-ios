import PlutoDomain
import PlutoPresentation
import Testing

@MainActor
@Suite struct HomeViewModelTests {
    @Test("home view model exposes one immutable state")
    func state() async {
        let tokens = FakeTokens()
        let model = HomeViewModel(tokens: tokens)
        let first = model.state
        #expect(first == HomeState(title: "Pluto", signedIn: false))

        await model.signIn()
        #expect(model.state.signedIn)
        #expect(await tokens.current() != nil)
        #expect(!first.signedIn, "the earlier state is a value: it is not changed, a new one replaces it")

        await model.signOut()
        #expect(!model.state.signedIn)
        #expect(await tokens.current() == nil)

        let signedIn = HomeViewModel(tokens: FakeTokens(token: Token(accessToken: "t", expiresAt: 1)))
        #expect(!signedIn.state.signedIn)
        await signedIn.load()
        #expect(signedIn.state.signedIn)
    }
}

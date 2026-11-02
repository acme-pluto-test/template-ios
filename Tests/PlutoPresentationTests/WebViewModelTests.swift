import PlutoPresentation
import Testing

@MainActor
@Suite struct WebViewModelTests {
    @Test("web view model exposes one immutable state")
    func state() throws {
        let model = WebViewModel(tokens: FakeTokens(), config: try config())
        let first = model.state
        #expect(first == WebState(url: "\(appOrigin)/", status: .loading, reloads: 0))

        model.pageFinished()
        #expect(model.state.status == .loaded)
        model.pageFinished()
        #expect(model.state.status == .loaded)

        model.loadFailed()
        #expect(model.state.status == .failed)
        model.pageFinished()
        #expect(model.state.status == .failed, "a failed page stays failed until the user retries")

        model.retry()
        #expect(model.state == WebState(url: "\(appOrigin)/", status: .loading, reloads: 1))
        #expect(first == WebState(url: "\(appOrigin)/", status: .loading, reloads: 0), "the first state is not changed")
    }

    @Test("shows the failed state and loads again on retry")
    func retry() throws {
        let model = WebViewModel(tokens: FakeTokens(), config: try config())
        model.loadFailed()
        #expect(model.state.status == .failed)
        let before = model.state.reloads
        model.retry()
        #expect(model.state.status == .loading)
        #expect(model.state.reloads == before + 1)
        model.loadFailed()
        model.retry()
        #expect(model.state.reloads == before + 2)
    }
}

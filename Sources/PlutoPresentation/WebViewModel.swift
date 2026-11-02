import Observation
import PlutoDomain
import PlutoWebView

public enum PageStatus: Equatable, Sendable { case loading, loaded, failed }

/// Everything the web screen shows; `reloads` changes to make the page load again.
public struct WebState: Equatable, Sendable {
    public var url: String
    public var status: PageStatus
    public var reloads: Int

    public init(url: String, status: PageStatus = .loading, reloads: Int = 0) {
        self.url = url
        self.status = status
        self.reloads = reloads
    }
}

@MainActor
@Observable
public final class WebViewModel {
    public private(set) var state: WebState
    public let policy: OriginPolicy
    public let host: BridgeHost

    public init(tokens: any TokenProvider, config: WebConfig, log: @escaping @MainActor (String) -> Void = { _ in }) {
        policy = OriginPolicy(config.allowlist)
        host = BridgeHost(policy: policy, tokens: tokens, log: log)
        state = WebState(url: config.startURL)
    }

    public func pageFinished() {
        if state.status == .loading { state = WebState(url: state.url, status: .loaded, reloads: state.reloads) }
    }

    public func loadFailed() {
        state = WebState(url: state.url, status: .failed, reloads: state.reloads)
    }

    public func retry() {
        state = WebState(url: state.url, status: .loading, reloads: state.reloads + 1)
    }
}

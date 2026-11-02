import Foundation
import PlutoBridge
import PlutoDomain

/// Where the host answers: the page, through the WKWebView glue in the app, or a fake in tests.
public protocol PageChannel: Sendable {
    @MainActor func post(_ text: String)
}

/// The native side of the bridge. It parses what the page sends with the generated codec, answers `navigation.ready`
/// with the theme, the safe area and the token, answers `auth.refresh.request` with a new token, and ignores the rest.
/// Nothing here touches WebKit, so the tests on the Mac prove it (door 4).
@MainActor
public final class BridgeHost {
    private let policy: OriginPolicy
    private let tokens: any TokenProvider
    private let log: @MainActor (String) -> Void
    private var channel: (any PageChannel)?
    private var theme: NativeToWebMessage?
    private var safeArea: NativeToWebMessage?

    public init(policy: OriginPolicy, tokens: any TokenProvider, log: @escaping @MainActor (String) -> Void = { _ in }) {
        self.policy = policy
        self.tokens = tokens
        self.log = log
    }

    /// A message the page posted. `sourceOrigin` is what the web view reports as the sender's origin.
    public func onPageMessage(_ text: String, sourceOrigin: String, reply: any PageChannel) async {
        guard policy.allowsOrigin(sourceOrigin) else {
            log("ignored a message from an origin outside the allowlist")
            return
        }
        let message: WebToNativeMessage
        do {
            message = try Bridge.parseWebToNative(Data(text.utf8))
        } catch {
            log("ignored a message: \((error as? BridgeError)?.reason ?? "unreadable")")
            return
        }
        channel = reply
        switch message {
        case .navigationReady:
            await answerReady()
        case .authRefreshRequest:
            await refreshAndSend()
        }
    }

    /// The system theme changed (or is known for the first time). Sent when it differs from the last one.
    public func sendTheme(dark: Bool, accentRGB: UInt32) {
        let next = NativeToWebMessage.themeChanged(mode: dark ? .dark : .light, accentColor: String(format: "#%06X", accentRGB & 0xFFFFFF))
        guard next != theme else { return }
        theme = next
        send(next)
    }

    /// The window insets, in points (CSS pixels). Sent when they differ from the last ones.
    public func sendSafeArea(top: Double, right: Double, bottom: Double, left: Double) {
        let next = NativeToWebMessage.safeAreaChanged(top: top, right: right, bottom: bottom, left: left)
        guard next != safeArea else { return }
        safeArea = next
        send(next)
    }

    private func answerReady() async {
        if let theme { send(theme) }
        if let safeArea { send(safeArea) }
        if let token = await tokens.current() { send(.authToken(accessToken: token.accessToken, expiresAt: token.expiresAt)) }
    }

    // A login that fails (the network is down) must not take the app down: the page gets no token and may ask again.
    private func refreshAndSend() async {
        do {
            if let token = try await tokens.refresh() { send(.authToken(accessToken: token.accessToken, expiresAt: token.expiresAt)) }
        } catch {
            log("token refresh failed: \(type(of: error))")
        }
    }

    private func send(_ message: NativeToWebMessage) {
        channel?.post(Bridge.encode(message))
    }
}

#if DEBUG
import Foundation
import PlutoData
import PlutoDomain
import Testing

/// Records what the provider asked for; the answer is whatever the test sets.
private actor Issuer {
    var asked: [URL] = []
    var answer: Result<Data, any Error> = .success(Data(#"{"accessToken":"abc.def.ghi","expiresAt":1900000000}"#.utf8))
    func set(_ next: Result<Data, any Error>) { answer = next }
    func ask(_ url: URL) throws -> Data {
        asked.append(url)
        return try answer.get()
    }
}

@Suite struct DevTokenProviderTests {
    private func make(_ issuer: Issuer) -> DevTokenProvider {
        DevTokenProvider(startURL: URL(string: "https://localhost:8443/home?x=1")!) { url in try await issuer.ask(url) }
    }

    @Test("asks the issuer on the web origin only after signing in")
    func asksAfterSignIn() async throws {
        let issuer = Issuer()
        let tokens = make(issuer)
        #expect(try await tokens.refresh() == nil)
        #expect(await tokens.current() == nil)
        #expect(await issuer.asked.isEmpty)

        await tokens.signIn()
        try await Task.sleep(for: .milliseconds(200))
        #expect(await issuer.asked == [URL(string: "https://localhost:8443/dev/token")!], "signing in asks once, in the background")
        let first = try #require(await tokens.current())
        #expect(first.accessToken == "abc.def.ghi" && first.expiresAt == 1_900_000_000)

        await issuer.set(.success(Data(#"{"accessToken":"second","expiresAt":1900000100}"#.utf8)))
        #expect(try await tokens.refresh()?.accessToken == "second")
        #expect(await tokens.current()?.accessToken == "second")
    }

    @Test("answers nil and keeps what it held when the issuer answers badly, and throws when it cannot be reached")
    func badAnswers() async throws {
        let issuer = Issuer()
        let tokens = make(issuer)
        await tokens.signIn()
        try await Task.sleep(for: .milliseconds(200))
        let before = await tokens.current()
        for bad in ["not json", "{}", #"{"accessToken":"","expiresAt":1}"#, #"{"accessToken":"x"}"#, "[]"] {
            await issuer.set(.success(Data(bad.utf8)))
            #expect(try await tokens.refresh() == nil, "\(bad)")
        }
        await issuer.set(.failure(URLError(.cannotConnectToHost)))
        await #expect(throws: URLError.self) { try await tokens.refresh() }
        #expect(await tokens.current() == before)
    }

    @Test("forgets the token on sign out and never prints it")
    func signOut() async throws {
        let issuer = Issuer()
        let tokens = make(issuer)
        await tokens.signIn()
        try await Task.sleep(for: .milliseconds(200))
        let held = try #require(await tokens.current())
        #expect(!"\(held)".contains("abc.def.ghi"))
        await tokens.signOut()
        #expect(await tokens.current() == nil)
        #expect(try await tokens.refresh() == nil)
    }
}
#endif

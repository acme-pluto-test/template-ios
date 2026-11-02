import PlutoData
import PlutoDomain
import Testing

@Suite struct InMemoryTokenProviderTests {
    @Test("holds a token only after sign in and hands out a new one on refresh")
    func holds() async throws {
        let tokens = InMemoryTokenProvider()
        #expect(await tokens.current() == nil)
        #expect(await tokens.refresh() == nil)
        await tokens.signIn()
        let first = try #require(await tokens.current())
        let second = try #require(await tokens.refresh())
        #expect(first.accessToken != second.accessToken)
        #expect(await tokens.current() == second)
        await tokens.signOut()
        #expect(await tokens.current() == nil)
        #expect(second.description == "Token(accessToken: <redacted>, expiresAt: \(second.expiresAt))")
        #expect(!"\(second)".contains(second.accessToken))
        #expect(!second.debugDescription.contains(second.accessToken))
    }
}

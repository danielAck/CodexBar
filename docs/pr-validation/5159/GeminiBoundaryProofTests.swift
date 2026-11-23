import Foundation
import Testing
@testable import CodexBarCore

@Suite(.serialized)
struct GeminiBoundaryProofTests {
    @Test(arguments: BundledPluginTestSupport.engines)
    func `native cookie transport sign in rejection advances candidate`(
        engine: ProviderPluginEngineKind) async throws
    {
        GeminiBoundaryProofProtocol.reset(location: "https://accounts.google.com/ServiceLogin")
        let candidates = Candidates()
        let rejected = Counter()
        let runtime = try BundledPluginTestSupport.runtime(
            "gemini-web", engine: engine, transport: ProviderHTTPClient.shared,
            contextOptions: .production)
        let usage = try await runtime.fetchUsage(
            cookieSessionResolver: { _, _ in await candidates.next() },
            cookieSessionInvalidator: { _, _ in rejected.increment() })
        let receipt = GeminiBoundaryProofProtocol.receipt()
        #expect(usage.primary?.usedPercent == 24)
        #expect(usage.secondary?.usedPercent == 2)
        #expect(receipt.requests == 2)
        #expect(receipt.productionCalls == 2)
        #expect(receipt.validRequests)
        #expect(await candidates.count == 2)
        #expect(rejected.value == 1)
        print("NATIVE_PROOF sign-in engine=\(engine) native-cookie-calls=\(receipt.productionCalls) " +
            "requests=\(receipt.requests) rejected=\(rejected.value) usage=24/2 used; synthetic/no-network")
    }

    @Test(arguments: BundledPluginTestSupport.engines)
    func `native cookie transport verification keeps current candidate`(
        engine: ProviderPluginEngineKind) async throws
    {
        GeminiBoundaryProofProtocol.reset(location: "https://www.google.com/sorry/index?private=do-not-print")
        let candidates = Candidates()
        let rejected = Counter()
        let runtime = try BundledPluginTestSupport.runtime(
            "gemini-web", engine: engine, transport: ProviderHTTPClient.shared,
            contextOptions: .production)
        let error = await #expect(throws: ProviderFetchClassifiedError.self) {
            try await runtime.fetchUsage(
                cookieSessionResolver: { _, _ in await candidates.next() },
                cookieSessionInvalidator: { _, _ in rejected.increment() })
        }
        #expect(error?.kind == .providerUnavailable)
        let message = error?.localizedDescription ?? ""
        #expect(message.contains("Google requires browser verification"))
        #expect(!message.contains("private="))
        #expect(!message.contains("do-not-print"))
        let receipt = GeminiBoundaryProofProtocol.receipt()
        #expect(receipt.requests == 1)
        #expect(receipt.productionCalls == 1)
        #expect(receipt.validRequests)
        #expect(await candidates.count == 1)
        #expect(rejected.value == 0)
        print("NATIVE_PROOF verification engine=\(engine) native-cookie-calls=\(receipt.productionCalls) " +
            "requests=\(receipt.requests) rejected=\(rejected.value) message=\(message); synthetic/no-network")
    }

    @Test
    func `native cookie redirect delegate blocks other origins`() throws {
        let jar = ProviderPluginCookieJar()
        let session = ProviderPluginCookieSession(
            header: "SID=synthetic-proof", source: "Synthetic", origin: "https://gemini.google.com")
        jar.register(session)
        let delegate = ProviderPluginCookieTransport.CookieRedirectDelegate(jar: jar, id: session.id)
        let source = URL(string: "https://gemini.google.com/usage")!
        for target in ["https://accounts.google.com/ServiceLogin", "https://www.google.com/sorry/index"] {
            #expect(delegate.redirectedRequest(originalURL: source, request: URLRequest(url: URL(string: target)!)) == nil)
        }
        let allowed = try #require(delegate.redirectedRequest(
            originalURL: source, request: URLRequest(url: URL(string: "https://gemini.google.com/app")!)))
        #expect(allowed.value(forHTTPHeaderField: "Cookie") == "SID=synthetic-proof")
        print("NATIVE_PROOF delegate cross-origin=blocked same-origin=allowed")
    }

    private actor Candidates {
        var count = 0
        func next() -> ProviderPluginCookieSession? {
            guard self.count < 2 else { return nil }
            self.count += 1
            return .init(header: "SID=proof-\(self.count)", source: "Synthetic", origin: "https://gemini.google.com")
        }
    }
}

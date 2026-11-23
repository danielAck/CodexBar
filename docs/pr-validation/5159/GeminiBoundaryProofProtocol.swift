import Foundation

/// Verification overlay only: intercepts every request before network I/O.
final class GeminiBoundaryProofProtocol: URLProtocol, @unchecked Sendable {
    final class State: @unchecked Sendable {
        let lock = NSLock()
        var location = ""
        var requests = 0
        var productionCalls = 0
        var validRequests = true
    }

    static let state = State()

    static func reset(location: String) {
        self.state.lock.withLock {
            self.state.location = location
            self.state.requests = 0
            self.state.productionCalls = 0
            self.state.validRequests = true
        }
    }

    static func enteredProductionTransport() {
        self.state.lock.withLock { self.state.productionCalls += 1 }
    }

    static func receipt() -> (requests: Int, productionCalls: Int, validRequests: Bool) {
        self.state.lock.withLock {
            (self.state.requests, self.state.productionCalls, self.state.validRequests)
        }
    }

    override class func canInit(with _: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        let (index, location, valid) = Self.state.lock.withLock {
            Self.state.requests += 1
            let index = Self.state.requests
            let valid = self.request.url?.scheme == "https"
                && self.request.url?.host == "gemini.google.com"
                && self.request.url?.path == "/_/BardChatUi/graphql/schemas/GEMINI_WEB_GRAPHQL/executeQuery"
                && self.request.httpMethod == "GET"
                && self.request.value(forHTTPHeaderField: "Cookie") == "SID=proof-\(index)"
                && index <= 2
            Self.state.validRequests = Self.state.validRequests && valid
            return (index, Self.state.location, valid)
        }
        guard valid, let url = self.request.url else {
            self.client?.urlProtocol(self, didFailWithError: URLError(.unsupportedURL))
            return
        }
        let status = index == 1 ? 302 : 200
        let response = HTTPURLResponse(
            url: url, statusCode: status, httpVersion: "HTTP/1.1",
            headerFields: index == 1 ? ["Location": location] : ["Content-Type": "application/json"])!
        self.client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        if index == 2 {
            let body = #"[{"data":{"viewer":{"rpcs":{"getUsageInfo":{"subscriptionTier":"TIER1","pools":[{"poolType":"GXU_FIVE_HOURLY","percentageUsed":0.24},{"poolType":"GXU_WEEKLY","percentageUsed":0.02}]}}}}}]"#
            self.client?.urlProtocol(self, didLoad: Data(body.utf8))
        }
        self.client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}

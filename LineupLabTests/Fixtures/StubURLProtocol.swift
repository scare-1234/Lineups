import Foundation

/// URLProtocol stub so the API client can be tested without a network.
final class StubURLProtocol: URLProtocol {

    struct Stub {
        let statusCode: Int
        let data: Data
        let error: Error?
        let headers: [String: String]

        init(statusCode: Int = 200, data: Data = Data(), error: Error? = nil, headers: [String: String] = [:]) {
            self.statusCode = statusCode
            self.data = data
            self.error = error
            self.headers = headers
        }
    }

    /// Responses are handed out in order; the last one repeats once the queue runs dry.
    static var stubs: [Stub] = []
    static var requestCount = 0

    static func reset() {
        stubs = []
        requestCount = 0
    }

    static func enqueue(_ stub: Stub, times: Int = 1) {
        stubs.append(contentsOf: Array(repeating: stub, count: times))
    }

    private static func nextStub() -> Stub {
        requestCount += 1
        if stubs.count > 1 {
            return stubs.removeFirst()
        }
        return stubs.first ?? Stub(statusCode: 500)
    }

    static func makeSession() -> URLSession {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [StubURLProtocol.self]
        configuration.urlCache = nil
        configuration.requestCachePolicy = .reloadIgnoringLocalAndRemoteCacheData
        return URLSession(configuration: configuration)
    }

    override class func canInit(with request: URLRequest) -> Bool { true }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        let stub = StubURLProtocol.nextStub()

        if let error = stub.error {
            client?.urlProtocol(self, didFailWithError: error)
            return
        }

        let response = HTTPURLResponse(
            url: request.url ?? URL(fileURLWithPath: "/"),
            statusCode: stub.statusCode,
            httpVersion: "HTTP/1.1",
            headerFields: stub.headers
        )
        if let response {
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        }
        client?.urlProtocol(self, didLoad: stub.data)
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}

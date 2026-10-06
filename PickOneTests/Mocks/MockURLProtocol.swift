import Foundation
import Synchronization

/// Owns one fixture's handlers and request history. Keep it alive while using its sessions.
final class MockHTTPTransport: Sendable {
    typealias RequestHandler = @Sendable (URLRequest) throws -> (HTTPURLResponse, Data)

    fileprivate struct State: Sendable {
        var requestHandler: RequestHandler?
        var capturedRequests: [URLRequest] = []
    }

    fileprivate final class Context: Sendable {
        let state = Mutex(State())
    }

    private let identifier = UUID().uuidString
    private let context = Context()

    init() {
        MockURLProtocol.contexts.withLock { $0[identifier] = context }
    }

    deinit {
        MockURLProtocol.contexts.withLock { $0[identifier] = nil }
    }

    var requestHandler: RequestHandler? {
        get { context.state.withLock { $0.requestHandler } }
        set { context.state.withLock { $0.requestHandler = newValue } }
    }

    var capturedRequests: [URLRequest] {
        context.state.withLock { $0.capturedRequests }
    }

    func makeConfiguration() -> URLSessionConfiguration {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [MockURLProtocol.self]
        configuration.httpAdditionalHeaders = [MockURLProtocol.contextHeader: identifier]
        return configuration
    }

    func createMockSession() -> URLSession {
        URLSession(configuration: makeConfiguration())
    }

    /// Convenience method to set up a successful JSON response.
    func setSuccessResponse(
        data: Data,
        statusCode: Int = 200,
        headers: [String: String] = ["Content-Type": "application/json"]
    ) {
        requestHandler = { request in
            let response = try Self.makeResponse(
                for: request,
                statusCode: statusCode,
                headers: headers
            )
            return (response, data)
        }
    }

    /// Convenience method to set up an error response.
    func setErrorResponse(_ error: any Error & Sendable) {
        requestHandler = { _ in
            throw error
        }
    }

    /// Convenience method to set up an HTTP error response.
    func setHTTPErrorResponse(statusCode: Int, data: Data = Data()) {
        requestHandler = { request in
            let response = try Self.makeResponse(
                for: request,
                statusCode: statusCode,
                headers: ["Content-Type": "application/json"]
            )
            return (response, data)
        }
    }

    private static func makeResponse(
        for request: URLRequest,
        statusCode: Int,
        headers: [String: String]
    ) throws -> HTTPURLResponse {
        guard let url = request.url else {
            throw URLError(.badURL)
        }
        guard let response = HTTPURLResponse(
            url: url,
            statusCode: statusCode,
            httpVersion: nil,
            headerFields: headers
        ) else {
            throw URLError(.badServerResponse)
        }
        return response
    }
}

/// Routes every intercepted request to its fixture, including callbacks from older sessions.
final class MockURLProtocol: URLProtocol {
    fileprivate static let contextHeader = "X-PickOne-Test-Transport"
    fileprivate static let contexts = Mutex([String: MockHTTPTransport.Context]())

    private let context: MockHTTPTransport.Context?
    private let stopped = Mutex(false)

    override init(request: URLRequest, cachedResponse: CachedURLResponse?, client: (any URLProtocolClient)?) {
        let identifier = request.value(forHTTPHeaderField: Self.contextHeader)
        context = Self.contexts.withLock { contexts in
            identifier.flatMap { contexts[$0] }
        }
        super.init(request: request, cachedResponse: cachedResponse, client: client)
    }

    // swiftlint:disable:next static_over_final_class - URLProtocol requires this class override point
    override class func canInit(with request: URLRequest) -> Bool {
        // Fail closed even when a fixture has not registered its context.
        true
    }

    // swiftlint:disable:next static_over_final_class - URLProtocol requires this class override point
    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        guard !stopped.withLock({ $0 }) else { return }
        guard let context else {
            client?.urlProtocol(self, didFailWithError: MockHTTPTransportError.missingContext)
            return
        }
        let handler = context.state.withLock { state in
            state.capturedRequests.append(request)
            return state.requestHandler
        }
        guard let handler else {
            client?.urlProtocol(self, didFailWithError: MockHTTPTransportError.missingHandler)
            return
        }

        do {
            let (response, data) = try handler(request)
            guard !stopped.withLock({ $0 }) else { return }
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            guard !stopped.withLock({ $0 }) else { return }
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {
        stopped.withLock { $0 = true }
    }
}

enum MockHTTPTransportError: Error, Equatable {
    case missingContext
    case missingHandler
}

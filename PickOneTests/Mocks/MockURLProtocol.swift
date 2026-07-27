//
//  MockURLProtocol.swift
//  PickOneTests
//
//  A URLProtocol subclass that intercepts network requests for testing.
//  This allows us to test URLSessionHTTPClient without making real network calls.
//

import Foundation
import Synchronization

final class MockURLProtocol: URLProtocol {
    typealias RequestHandler =
        @Sendable (URLRequest) throws -> (HTTPURLResponse, Data)

    private struct State: Sendable {
        var requestHandler: RequestHandler?
        var capturedRequests: [URLRequest] = []
    }

    private static let state = Mutex(
        State(requestHandler: nil)
    )

    // MARK: - Mock Configuration
    
    /// The handler that processes intercepted requests and returns mock responses.
    /// Set this before running tests to define expected behavior.
    static var requestHandler: RequestHandler? {
        get {
            state.withLock { $0.requestHandler }
        }
        set {
            state.withLock { $0.requestHandler = newValue }
        }
    }
    
    /// Tracks all requests made during tests for verification.
    static var capturedRequests: [URLRequest] {
        state.withLock { $0.capturedRequests }
    }
    
    /// Resets all mock state. Call this in test teardown.
    static func reset() {
        state.withLock {
            $0.requestHandler = nil
            $0.capturedRequests = []
        }
    }
    
    // MARK: - URLProtocol Overrides
    
    override class func canInit(with request: URLRequest) -> Bool {
        // Intercept all requests
        return true
    }
    
    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        return request
    }
    
    override func startLoading() {
        let handler = MockURLProtocol.state.withLock { state in
            state.capturedRequests.append(request)
            return state.requestHandler
        }

        guard let handler else {
            fatalError("MockURLProtocol.requestHandler not set. Set it before running tests.")
        }
        
        do {
            let (response, data) = try handler(request)
            
            // Send response to client
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
            
        } catch {
            // Send error to client
            client?.urlProtocol(self, didFailWithError: error)
        }
    }
    
    override func stopLoading() {
        // Required override, but nothing to do here
    }
}

// MARK: - Test Helpers

extension MockURLProtocol {
    
    /// Creates a URLSession configured to use this mock protocol.
    static func createMockSession() -> URLSession {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [MockURLProtocol.self]
        return URLSession(configuration: configuration)
    }
    
    /// Convenience method to set up a successful JSON response.
    static func setSuccessResponse(
        data: Data,
        statusCode: Int = 200,
        headers: [String: String] = ["Content-Type": "application/json"]
    ) {
        requestHandler = { request in
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: statusCode,
                httpVersion: nil,
                headerFields: headers
            )!
            return (response, data)
        }
    }
    
    /// Convenience method to set up an error response.
    static func setErrorResponse(_ error: any Error & Sendable) {
        requestHandler = { _ in
            throw error
        }
    }
    
    /// Convenience method to set up an HTTP error response.
    static func setHTTPErrorResponse(statusCode: Int, data: Data = Data()) {
        requestHandler = { request in
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: statusCode,
                httpVersion: nil,
                headerFields: ["Content-Type": "application/json"]
            )!
            return (response, data)
        }
    }
}

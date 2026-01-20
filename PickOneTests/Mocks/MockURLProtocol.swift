//
//  MockURLProtocol.swift
//  PickOneTests
//
//  A URLProtocol subclass that intercepts network requests for testing.
//  This allows us to test URLSessionHTTPClient without making real network calls.
//

import Foundation

final class MockURLProtocol: URLProtocol {
    
    // MARK: - Mock Configuration
    
    /// The handler that processes intercepted requests and returns mock responses.
    /// Set this before running tests to define expected behavior.
    static var requestHandler: ((URLRequest) throws -> (HTTPURLResponse, Data))?
    
    /// Tracks all requests made during tests for verification.
    static var capturedRequests: [URLRequest] = []
    
    /// Resets all mock state. Call this in test teardown.
    static func reset() {
        requestHandler = nil
        capturedRequests = []
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
        // Capture the request for later verification
        MockURLProtocol.capturedRequests.append(request)
        
        guard let handler = MockURLProtocol.requestHandler else {
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
    static func setErrorResponse(_ error: Error) {
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

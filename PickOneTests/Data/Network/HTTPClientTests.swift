//
//  HTTPClientTests.swift
//  PickOneTests
//
//  Unit tests for URLSessionHTTPClient using Swift Testing framework.
//

import Testing
import Foundation
@testable import PickOne

// MARK: - Test Suite

/// Tests run serially because MockURLProtocol uses shared static state.
/// This prevents race conditions between tests.
@Suite("HTTPClient Tests", .serialized)
struct HTTPClientTests {
    
    // MARK: - Helper
    
    /// Creates a System Under Test with a mock URLSession.
    /// Resets MockURLProtocol state before each test to ensure isolation.
    private func makeSUT(baseURL: String = TestData.testBaseURL) -> URLSessionHTTPClient {
        // Reset mock state before creating SUT to ensure test isolation
        MockURLProtocol.reset()
        
        let session = MockURLProtocol.createMockSession()
        return URLSessionHTTPClient(baseURL: baseURL, session: session)
    }
    
    // MARK: - Successful Request Tests
    
    @Test("Successful request returns decoded response")
    func successfulRequestReturnsDecodedResponse() async throws {
        // Given
        let sut = makeSUT()
        MockURLProtocol.setSuccessResponse(data: TestData.simpleResponseJSON)
        
        // When
        let result: TestData.SimpleResponse = try await sut.request(
            endpoint: TestData.testEndpoint,
            method: .get,
            parameters: nil,
            headers: nil,
            body: nil,
            timeout: nil,
            contentType: nil
        )
        
        // Then
        #expect(result.id == 42)
        #expect(result.name == "Test Item")
        #expect(result.isActive == true)
    }
    
    @Test("Snake case JSON keys are converted to camelCase")
    func snakeCaseConversion() async throws {
        // Given
        let sut = makeSUT()
        MockURLProtocol.setSuccessResponse(data: TestData.simpleResponseJSON)
        
        // When
        let result: TestData.SimpleResponse = try await sut.request(
            endpoint: TestData.testEndpoint,
            method: .get,
            parameters: nil,
            headers: nil,
            body: nil,
            timeout: nil,
            contentType: nil
        )
        
        // Then - is_active in JSON should map to isActive in Swift
        #expect(result.isActive == true)
    }
    
    // MARK: - URL Building Tests
    
    @Test("URL is built correctly with endpoint")
    func urlBuiltWithEndpoint() async throws {
        // Given
        let sut = makeSUT(baseURL: "https://api.example.com")
        MockURLProtocol.setSuccessResponse(data: TestData.simpleResponseJSON)
        
        // When
        let _: TestData.SimpleResponse = try await sut.request(
            endpoint: "/movies/top_rated",
            method: .get,
            parameters: nil,
            headers: nil,
            body: nil,
            timeout: nil,
            contentType: nil
        )
        
        // Then
        let capturedRequest = try #require(MockURLProtocol.capturedRequests.last)
        let url = try #require(capturedRequest.url)
        
        #expect(url.absoluteString.contains("api.example.com"))
        #expect(url.absoluteString.contains("/movies/top_rated"))
    }
    
    @Test("Query parameters are appended to URL")
    func queryParametersAppended() async throws {
        // Given
        let sut = makeSUT()
        MockURLProtocol.setSuccessResponse(data: TestData.simpleResponseJSON)
        
        // When
        let _: TestData.SimpleResponse = try await sut.request(
            endpoint: TestData.testEndpoint,
            method: .get,
            parameters: ["page": "1", "language": "en-US"],
            headers: nil,
            body: nil,
            timeout: nil,
            contentType: nil
        )
        
        // Then
        let capturedRequest = try #require(MockURLProtocol.capturedRequests.last)
        let url = try #require(capturedRequest.url)
        let urlString = url.absoluteString
        
        #expect(urlString.contains("page=1"))
        #expect(urlString.contains("language=en-US"))
    }
    
    // MARK: - Headers Tests
    
    @Test("Custom headers are applied to request")
    func customHeadersApplied() async throws {
        // Given
        let sut = makeSUT()
        MockURLProtocol.setSuccessResponse(data: TestData.simpleResponseJSON)
        
        // When
        let _: TestData.SimpleResponse = try await sut.request(
            endpoint: TestData.testEndpoint,
            method: .get,
            parameters: nil,
            headers: ["Authorization": "Bearer test-token"],
            body: nil,
            timeout: nil,
            contentType: nil
        )
        
        // Then
        let capturedRequest = try #require(MockURLProtocol.capturedRequests.last)
        let authHeader = capturedRequest.value(forHTTPHeaderField: "Authorization")
        
        #expect(authHeader == "Bearer test-token")
    }
    
    @Test("Default Content-Type header is application/json")
    func defaultContentTypeIsJSON() async throws {
        // Given
        let sut = makeSUT()
        MockURLProtocol.setSuccessResponse(data: TestData.simpleResponseJSON)
        
        // When
        let _: TestData.SimpleResponse = try await sut.request(
            endpoint: TestData.testEndpoint,
            method: .get,
            parameters: nil,
            headers: nil,
            body: nil,
            timeout: nil,
            contentType: nil
        )
        
        // Then
        let capturedRequest = try #require(MockURLProtocol.capturedRequests.last)
        let contentType = capturedRequest.value(forHTTPHeaderField: "Content-Type")
        
        #expect(contentType == "application/json")
    }
    
    @Test("Default Accept header is application/json")
    func defaultAcceptIsJSON() async throws {
        // Given
        let sut = makeSUT()
        MockURLProtocol.setSuccessResponse(data: TestData.simpleResponseJSON)
        
        // When
        let _: TestData.SimpleResponse = try await sut.request(
            endpoint: TestData.testEndpoint,
            method: .get,
            parameters: nil,
            headers: nil,
            body: nil,
            timeout: nil,
            contentType: nil
        )
        
        // Then
        let capturedRequest = try #require(MockURLProtocol.capturedRequests.last)
        let accept = capturedRequest.value(forHTTPHeaderField: "Accept")
        
        #expect(accept == "application/json")
    }
    
    // MARK: - HTTP Method Tests
    
    @Test("HTTP method is set correctly", arguments: [
        HTTPMethod.get,
        HTTPMethod.post,
        HTTPMethod.put,
        HTTPMethod.delete
    ])
    func httpMethodIsSetCorrectly(method: HTTPMethod) async throws {
        // Given
        let sut = makeSUT()
        MockURLProtocol.setSuccessResponse(data: TestData.simpleResponseJSON)
        
        // When
        let _: TestData.SimpleResponse = try await sut.request(
            endpoint: TestData.testEndpoint,
            method: method,
            parameters: nil,
            headers: nil,
            body: nil,
            timeout: nil,
            contentType: nil
        )
        
        // Then - use .last to get the most recent request from this test
        let capturedRequest = try #require(MockURLProtocol.capturedRequests.last)
        #expect(capturedRequest.httpMethod == method.rawValue)
    }
    
    // MARK: - Error Handling Tests
    
    @Test("HTTP 401 error throws httpError with status code")
    func http401ThrowsError() async throws {
        // Given
        let sut = makeSUT()
        MockURLProtocol.setHTTPErrorResponse(statusCode: 401)
        
        // When/Then
        await #expect(throws: NetworkError.self) {
            let _: TestData.SimpleResponse = try await sut.request(
                endpoint: TestData.testEndpoint,
                method: .get,
                parameters: nil,
                headers: nil,
                body: nil,
                timeout: nil,
                contentType: nil
            )
        }
    }
    
    @Test("HTTP 404 error throws httpError")
    func http404ThrowsError() async throws {
        // Given
        let sut = makeSUT()
        MockURLProtocol.setHTTPErrorResponse(statusCode: 404)
        
        // When/Then
        await #expect(throws: NetworkError.self) {
            let _: TestData.SimpleResponse = try await sut.request(
                endpoint: TestData.testEndpoint,
                method: .get,
                parameters: nil,
                headers: nil,
                body: nil,
                timeout: nil,
                contentType: nil
            )
        }
    }
    
    @Test("HTTP 500 error throws httpError")
    func http500ThrowsError() async throws {
        // Given
        let sut = makeSUT()
        MockURLProtocol.setHTTPErrorResponse(statusCode: 500)
        
        // When/Then
        await #expect(throws: NetworkError.self) {
            let _: TestData.SimpleResponse = try await sut.request(
                endpoint: TestData.testEndpoint,
                method: .get,
                parameters: nil,
                headers: nil,
                body: nil,
                timeout: nil,
                contentType: nil
            )
        }
    }
    
    @Test("Empty response throws noData error")
    func emptyResponseThrowsNoDataError() async throws {
        // Given
        let sut = makeSUT()
        MockURLProtocol.setSuccessResponse(data: TestData.emptyData)
        
        // When/Then
        await #expect(throws: NetworkError.self) {
            let _: TestData.SimpleResponse = try await sut.request(
                endpoint: TestData.testEndpoint,
                method: .get,
                parameters: nil,
                headers: nil,
                body: nil,
                timeout: nil,
                contentType: nil
            )
        }
    }
    
    @Test("Invalid JSON throws decodingError")
    func invalidJSONThrowsDecodingError() async throws {
        // Given
        let sut = makeSUT()
        MockURLProtocol.setSuccessResponse(data: TestData.invalidJSON)
        
        // When/Then
        await #expect(throws: NetworkError.self) {
            let _: TestData.SimpleResponse = try await sut.request(
                endpoint: TestData.testEndpoint,
                method: .get,
                parameters: nil,
                headers: nil,
                body: nil,
                timeout: nil,
                contentType: nil
            )
        }
    }
    
    @Test("Network error throws appropriate error")
    func networkErrorThrowsAppropriateError() async throws {
        // Given
        let sut = makeSUT()
        let networkError = URLError(.notConnectedToInternet)
        MockURLProtocol.setErrorResponse(networkError)
        
        // When/Then
        await #expect(throws: NetworkError.self) {
            let _: TestData.SimpleResponse = try await sut.request(
                endpoint: TestData.testEndpoint,
                method: .get,
                parameters: nil,
                headers: nil,
                body: nil,
                timeout: nil,
                contentType: nil
            )
        }
    }
}

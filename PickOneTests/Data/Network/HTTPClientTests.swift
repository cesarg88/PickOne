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
            timeout: nil,
            body: nil
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
            timeout: nil,
            body: nil
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
            timeout: nil,
            body: nil
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
            timeout: nil,
            body: nil
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
            timeout: nil,
            body: nil
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
            timeout: nil,
            body: nil
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
            timeout: nil,
            body: nil
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
            timeout: nil,
            body: nil
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
                timeout: nil,
                body: nil
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
                timeout: nil,
                body: nil
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
                timeout: nil,
                body: nil
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
                timeout: nil,
                body: nil
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
                timeout: nil,
                body: nil
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
                timeout: nil,
                body: nil
            )
        }
    }
    
    // MARK: - Endpoint Normalization Tests
    
    @Test("Endpoint with leading slash is normalized correctly")
    func endpointWithLeadingSlashNormalized() async throws {
        // Given
        let sut = makeSUT(baseURL: "https://api.example.com")
        MockURLProtocol.setSuccessResponse(data: TestData.simpleResponseJSON)
        
        // When - endpoint WITH leading slash
        let _: TestData.SimpleResponse = try await sut.request(
            endpoint: "/movies/top_rated",
            method: .get,
            parameters: nil,
            headers: nil,
            timeout: nil,
            body: nil
        )
        
        // Then - should NOT have double slash
        let capturedRequest = try #require(MockURLProtocol.capturedRequests.last)
        let url = try #require(capturedRequest.url)
        
        #expect(!url.absoluteString.contains("//movies"))
        #expect(url.absoluteString.contains("/movies/top_rated"))
    }
    
    @Test("Endpoint without leading slash works correctly")
    func endpointWithoutLeadingSlashWorks() async throws {
        // Given
        let sut = makeSUT(baseURL: "https://api.example.com")
        MockURLProtocol.setSuccessResponse(data: TestData.simpleResponseJSON)
        
        // When - endpoint WITHOUT leading slash
        let _: TestData.SimpleResponse = try await sut.request(
            endpoint: "movies/top_rated",
            method: .get,
            parameters: nil,
            headers: nil,
            timeout: nil,
            body: nil
        )
        
        // Then
        let capturedRequest = try #require(MockURLProtocol.capturedRequests.last)
        let url = try #require(capturedRequest.url)
        
        #expect(url.absoluteString.contains("/movies/top_rated"))
    }
    
    @Test("Endpoints with and without leading slash produce same URL")
    func endpointNormalizationProducesSameURL() async throws {
        // Given
        let sut1 = makeSUT(baseURL: "https://api.example.com")
        let sut2 = makeSUT(baseURL: "https://api.example.com")
        MockURLProtocol.setSuccessResponse(data: TestData.simpleResponseJSON)
        
        // When - with leading slash
        let _: TestData.SimpleResponse = try await sut1.request(
            endpoint: "/movies/top_rated",
            method: .get,
            parameters: nil,
            headers: nil,
            timeout: nil,
            body: nil
        )
        let url1 = MockURLProtocol.capturedRequests.last?.url?.absoluteString
        
        // Reset and test without leading slash
        MockURLProtocol.reset()
        MockURLProtocol.setSuccessResponse(data: TestData.simpleResponseJSON)
        
        let _: TestData.SimpleResponse = try await sut2.request(
            endpoint: "movies/top_rated",
            method: .get,
            parameters: nil,
            headers: nil,
            timeout: nil,
            body: nil
        )
        let url2 = MockURLProtocol.capturedRequests.last?.url?.absoluteString
        
        // Then - both should produce the same URL
        #expect(url1 == url2)
    }
    
    // MARK: - Percent Encoding Tests
    
    @Test("Query parameters with spaces are percent-encoded")
    func queryParamsWithSpacesAreEncoded() async throws {
        // Given
        let sut = makeSUT()
        MockURLProtocol.setSuccessResponse(data: TestData.simpleResponseJSON)
        
        // When
        let _: TestData.SimpleResponse = try await sut.request(
            endpoint: TestData.testEndpoint,
            method: .get,
            parameters: ["query": "hello world"],
            headers: nil,
            timeout: nil,
            body: nil
        )
        
        // Then
        let capturedRequest = try #require(MockURLProtocol.capturedRequests.last)
        let urlString = try #require(capturedRequest.url?.absoluteString)
        
        // Space should be encoded as %20 or +
        #expect(urlString.contains("hello%20world") || urlString.contains("hello+world"))
    }
    
    @Test("Query parameters with special characters are percent-encoded")
    func queryParamsWithSpecialCharsAreEncoded() async throws {
        // Given
        let sut = makeSUT()
        MockURLProtocol.setSuccessResponse(data: TestData.simpleResponseJSON)
        
        // When
        let _: TestData.SimpleResponse = try await sut.request(
            endpoint: TestData.testEndpoint,
            method: .get,
            parameters: ["name": "José", "filter": "a&b=c"],
            headers: nil,
            timeout: nil,
            body: nil
        )
        
        // Then
        let capturedRequest = try #require(MockURLProtocol.capturedRequests.last)
        let url = try #require(capturedRequest.url)
        
        // Parse query items to verify encoding worked correctly
        let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        let queryItems = components?.queryItems ?? []
        
        // Verify values are correctly decoded back (proves encoding worked)
        let nameValue = queryItems.first { $0.name == "name" }?.value
        let filterValue = queryItems.first { $0.name == "filter" }?.value
        
        #expect(nameValue == "José")
        #expect(filterValue == "a&b=c")
        
        // Also verify raw URL string doesn't contain unencoded special chars
        let urlString = url.absoluteString
        #expect(!urlString.contains("a&b=c")) // Raw ampersand should be encoded
    }
    
    // MARK: - Timeout Tests
    
    @Test("Default timeout is applied to all requests")
    func defaultTimeoutIsApplied() async throws {
        // Given
        let sut = makeSUT()
        MockURLProtocol.setSuccessResponse(data: TestData.simpleResponseJSON)
        
        // When
        let _: TestData.SimpleResponse = try await sut.request(
            endpoint: TestData.testEndpoint,
            method: .get,
            parameters: nil,
            headers: nil,
            timeout: nil,
            body: nil
        )
        
        // Then
        let capturedRequest = try #require(MockURLProtocol.capturedRequests.last)
        #expect(capturedRequest.timeoutInterval == 10)
    }
    
    @Test("Custom timeout is applied when provided")
    func customTimeoutIsApplied() async throws {
        // Given
        let sut = makeSUT()
        MockURLProtocol.setSuccessResponse(data: TestData.simpleResponseJSON)
        let customTimeout: TimeInterval = 5.0
        
        // When
        let _: TestData.SimpleResponse = try await sut.request(
            endpoint: TestData.testEndpoint,
            method: .get,
            parameters: nil,
            headers: nil,
            timeout: customTimeout,
            body: nil
        )
        
        // Then
        let capturedRequest = try #require(MockURLProtocol.capturedRequests.last)
        #expect(capturedRequest.timeoutInterval == customTimeout)
    }
}

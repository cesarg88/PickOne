import Foundation
import Synchronization
import Testing

@Suite("Mock HTTP transport isolation")
struct MockHTTPTransportTests {
    @Test("a late callback retains its original context after fixture disposal")
    func lateCallbackRetainsOriginalContext() throws {
        var original: MockHTTPTransport? = MockHTTPTransport()
        weak var originalReference = original
        original?.setSuccessResponse(data: Data("original".utf8), statusCode: 201)
        let configuration = try #require(original?.makeConfiguration())
        let request = try makeRequest(configuration: configuration)
        let client = RecordingURLProtocolClient()
        let callback = MockURLProtocol(request: request, cachedResponse: nil, client: client)
        original = nil
        #expect(originalReference == nil)

        let next = MockHTTPTransport()
        next.setSuccessResponse(data: Data("next".utf8), statusCode: 202)
        callback.startLoading()

        #expect(client.result.data == Data("original".utf8))
        #expect(client.result.statusCode == 201)
        #expect(client.result.finished)
        #expect(client.result.error == nil)
        #expect(next.capturedRequests.isEmpty)
    }

    @Test("a stopped callback cannot invoke either fixture's handler")
    func stoppedCallbackDoesNotLoad() throws {
        let original = MockHTTPTransport()
        original.setSuccessResponse(data: Data("original".utf8))
        let request = try makeRequest(configuration: original.makeConfiguration())
        let client = RecordingURLProtocolClient()
        let callback = MockURLProtocol(request: request, cachedResponse: nil, client: client)
        callback.stopLoading()

        let next = MockHTTPTransport()
        next.setSuccessResponse(data: Data("next".utf8))
        callback.startLoading()

        #expect(original.capturedRequests.isEmpty)
        #expect(next.capturedRequests.isEmpty)
        #expect(client.result.data.isEmpty)
        #expect(!client.result.finished)
        #expect(client.result.error == nil)
    }

    @Test("missing fixture configuration returns an error through URLSession")
    func missingHandlerReturnsError() async throws {
        let transport = MockHTTPTransport()
        let session = transport.createMockSession()
        defer { session.invalidateAndCancel() }
        let url = try #require(URL(string: "https://api.test.com/unconfigured"))

        do {
            _ = try await session.data(from: url)
            Issue.record("An unconfigured fixture must fail the request")
        } catch {
            // URLSession bridges URLProtocol errors to NSError.
            let actual = error as NSError
            let expected = MockHTTPTransportError.missingHandler as NSError
            #expect(actual.domain == expected.domain)
            #expect(actual.code == expected.code)
        }
        #expect(transport.capturedRequests.count == 1)
    }

    @Test("a callback created after fixture disposal fails without reaching the network")
    func disposedContextReturnsError() throws {
        var original: MockHTTPTransport? = MockHTTPTransport()
        let configuration = try #require(original?.makeConfiguration())
        let request = try makeRequest(configuration: configuration)
        original = nil
        let client = RecordingURLProtocolClient()
        let callback = MockURLProtocol(request: request, cachedResponse: nil, client: client)

        callback.startLoading()

        #expect(client.result.error as? MockHTTPTransportError == .missingContext)
        #expect(client.result.data.isEmpty)
        #expect(!client.result.finished)
    }

    private func makeRequest(configuration: URLSessionConfiguration) throws -> URLRequest {
        var request = try URLRequest(url: #require(URL(string: "https://api.test.com/pending")))
        request.allHTTPHeaderFields = try #require(configuration.httpAdditionalHeaders as? [String: String])
        return request
    }
}

private final class RecordingURLProtocolClient: NSObject, URLProtocolClient {
    struct Result: Sendable {
        var data = Data()
        var statusCode: Int?
        var error: (any Error)?
        var finished = false
    }

    private let state = Mutex(Result())

    var result: Result {
        state.withLock { $0 }
    }

    func urlProtocol(
        _ protocol: URLProtocol,
        didReceive response: URLResponse,
        cacheStoragePolicy policy: URLCache.StoragePolicy
    ) {
        state.withLock { $0.statusCode = (response as? HTTPURLResponse)?.statusCode }
    }

    func urlProtocol(_ protocol: URLProtocol, didLoad data: Data) {
        state.withLock { $0.data.append(data) }
    }

    func urlProtocol(_ protocol: URLProtocol, didFailWithError error: any Error) {
        state.withLock { $0.error = error }
    }

    func urlProtocolDidFinishLoading(_ protocol: URLProtocol) {
        state.withLock { $0.finished = true }
    }

    func urlProtocol(_ protocol: URLProtocol, wasRedirectedTo request: URLRequest, redirectResponse: URLResponse) {}
    func urlProtocol(_ protocol: URLProtocol, cachedResponseIsValid cachedResponse: CachedURLResponse) {}
    func urlProtocol(_ protocol: URLProtocol, didReceive challenge: URLAuthenticationChallenge) {}
    func urlProtocol(_ protocol: URLProtocol, didCancel challenge: URLAuthenticationChallenge) {}
}

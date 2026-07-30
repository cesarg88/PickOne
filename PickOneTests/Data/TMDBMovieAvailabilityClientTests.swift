import Foundation
import Testing
@testable import PickOne

@Suite("TMDBMovieAvailabilityClient tests", .serialized)
struct TMDBMovieAvailabilityClientTests {
    @Test("requests the movie-level watch providers endpoint")
    func requestsExpectedEndpoint() async throws {
        MockURLProtocol.reset()
        defer { MockURLProtocol.reset() }
        MockURLProtocol.setSuccessResponse(
            data: Data(
                """
                {"id":42,"results":{"ES":{"flatrate":[]}}}
                """.utf8
            )
        )
        let httpClient = URLSessionHTTPClient(
            baseURL: "https://api.themoviedb.org/3",
            session: MockURLProtocol.createMockSession()
        )
        let sut = TMDBMovieAvailabilityClient(
            httpClient: httpClient,
            apiKey: "test-token"
        )

        let response = try await sut.getWatchProviders(movieID: 42)

        #expect(response.id == 42)
        let request = try #require(MockURLProtocol.capturedRequests.first)
        #expect(request.url?.path == "/3/movie/42/watch/providers")
        #expect(
            request.value(forHTTPHeaderField: "Authorization")
                == "Bearer test-token"
        )
    }
}

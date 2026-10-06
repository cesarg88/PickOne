import Foundation
@testable import PickOne
import Testing

@Suite("TMDBMovieAvailabilityClient tests")
struct TMDBMovieAvailabilityClientTests {
    private let transport = MockHTTPTransport()

    @Test("requests the movie-level watch providers endpoint")
    func requestsExpectedEndpoint() async throws {
        transport.setSuccessResponse(
            data: Data(
                """
                {"id":42,"results":{"ES":{"flatrate":[]}}}
                """.utf8
            )
        )
        let httpClient = URLSessionHTTPClient(
            baseURL: "https://api.themoviedb.org/3",
            session: transport.createMockSession()
        )
        let sut = TMDBMovieAvailabilityClient(
            httpClient: httpClient,
            apiKey: "test-token"
        )

        let response = try await sut.getWatchProviders(movieID: 42)

        #expect(response.id == 42)
        let request = try #require(transport.capturedRequests.first)
        #expect(request.url?.path == "/3/movie/42/watch/providers")
        #expect(
            request.value(forHTTPHeaderField: "Authorization")
                == "Bearer test-token"
        )
    }
}

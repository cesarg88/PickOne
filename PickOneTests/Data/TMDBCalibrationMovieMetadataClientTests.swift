import Foundation
@testable import PickOne
import Testing

@Suite("TMDB calibration metadata client tests", .serialized)
struct TMDBCalibrationMovieMetadataClientTests {
    @Test("calibration metadata requests Spanish localization")
    func calibrationUsesSpanishLocalization() async throws {
        let httpClient = makeHTTPClient()
        let sut = TMDBCalibrationMovieMetadataClient(
            httpClient: httpClient,
            apiKey: "test-token"
        )

        let response = try await sut.getMovieDetail(id: 278)

        #expect(response.id == 278)
        let request = try #require(MockURLProtocol.capturedRequests.first)
        #expect(request.url?.path == "/3/movie/278")
        #expect(queryValue(named: "language", in: request) == "es-ES")
        #expect(
            request.value(forHTTPHeaderField: "Authorization")
                == "Bearer test-token"
        )
    }

    @Test("the shared movie catalog keeps its previous English localization")
    func sharedCatalogKeepsEnglishLocalization() async throws {
        let httpClient = makeHTTPClient()
        let sut = TMDBMovieCatalogClient(
            httpClient: httpClient,
            apiKey: "test-token"
        )

        _ = try await sut.getMovieDetail(id: 278)

        let request = try #require(MockURLProtocol.capturedRequests.first)
        #expect(queryValue(named: "language", in: request) == "en-US")
    }

    private func makeHTTPClient() -> URLSessionHTTPClient {
        MockURLProtocol.reset()
        MockURLProtocol.setSuccessResponse(data: TestData.movieDetailResponseJSON)
        return URLSessionHTTPClient(
            baseURL: "https://api.themoviedb.org/3",
            session: MockURLProtocol.createMockSession()
        )
    }

    private func queryValue(
        named name: String,
        in request: URLRequest
    ) -> String? {
        guard let url = request.url else { return nil }
        return URLComponents(url: url, resolvingAgainstBaseURL: false)?
            .queryItems?
            .first { $0.name == name }?
            .value
    }
}

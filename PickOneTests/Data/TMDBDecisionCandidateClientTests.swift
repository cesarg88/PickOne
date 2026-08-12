import Foundation
@testable import PickOne
import Testing

@Suite("TMDB decision candidate client tests", .serialized)
struct TMDBDecisionCandidateClientTests {
    @Test("Discover uses accepted Spanish region and provider recall filters")
    func requestsAcceptedRecallFilters() async throws {
        MockURLProtocol.reset()
        defer { MockURLProtocol.reset() }
        MockURLProtocol.setSuccessResponse(data: responseData)
        let sut = TMDBDecisionCandidateClient(
            httpClient: URLSessionHTTPClient(
                baseURL: "https://api.themoviedb.org/3",
                session: MockURLProtocol.createMockSession()
            ),
            apiKey: "test-token"
        )
        let context = try #require(DecisionCandidateContext(
            region: .spain,
            selectedProviderIDs: [337, 8, 337]
        ))

        let response = try await sut.discoverPage(4, context: context)

        #expect(response.results.first?.id == 42)
        #expect(response.results.first?.popularity == 999)
        let request = try #require(MockURLProtocol.capturedRequests.first)
        let requestURL = try #require(request.url)
        let query = try #require(
            URLComponents(url: requestURL, resolvingAgainstBaseURL: false)?
                .queryItems
        )
        let values = Dictionary(uniqueKeysWithValues: query.compactMap { item in
            item.value.map { (item.name, $0) }
        })
        #expect(request.url?.path == "/3/discover/movie")
        #expect(request.value(forHTTPHeaderField: "Authorization") == "Bearer test-token")
        #expect(values["language"] == "es-ES")
        #expect(values["region"] == "ES")
        #expect(values["watch_region"] == "ES")
        #expect(values["page"] == "4")
        #expect(values["include_adult"] == "false")
        #expect(values["include_video"] == "false")
        #expect(values["with_watch_monetization_types"] == "flatrate")
        #expect(values["with_watch_providers"] == "8|337")
        #expect(values["sort_by"] == "popularity.desc")
    }

    private var responseData: Data {
        Data(
            """
            {
              "page": 4,
              "results": [
                {
                  "id": 42,
                  "title": "Título localizado",
                  "popularity": 999,
                  "genre_ids": [18],
                  "release_date": "2024-06-10",
                  "vote_average": 7.8,
                  "vote_count": 1200
                }
              ]
            }
            """.utf8
        )
    }
}

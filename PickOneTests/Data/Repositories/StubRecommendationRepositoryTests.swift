import Foundation
@testable import PickOne
import Testing

@MainActor
@Suite("StubRecommendationRepository Tests", .serialized)
struct StubRecommendationRepositoryTests {
    @Test("returns sci-fi scenario for science fiction queries")
    func returnsSciFiScenarioForScienceFictionQueries() async throws {
        let sut = StubRecommendationRepository()

        let result = try await sut.getRecommendations(
            query: "smart sci-fi like Arrival",
            maxResults: 3
        )

        #expect(result.candidates.count == 3)
        #expect(result.candidates.first?.title == "Interstellar")
        #expect(result.explanation.contains("science fiction"))
    }

    @Test("returns comedy scenario for funny queries")
    func returnsComedyScenarioForFunnyQueries() async throws {
        let sut = StubRecommendationRepository()

        let result = try await sut.getRecommendations(
            query: "something funny but not dumb",
            maxResults: 4
        )

        #expect(result.candidates.count == 4)
        #expect(result.candidates.first?.title == "Parasite")
    }

    @Test("falls back to general scenario")
    func fallsBackToGeneralScenario() async throws {
        let sut = StubRecommendationRepository()

        let result = try await sut.getRecommendations(
            query: "give me a solid movie night pick",
            maxResults: 5
        )

        #expect(result.candidates.count == 5)
        #expect(result.candidates.first?.title == "The Shawshank Redemption")
    }
}

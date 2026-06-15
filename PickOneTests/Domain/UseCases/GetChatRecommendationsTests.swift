import Foundation
import Testing
@testable import PickOne

@Suite("GetChatRecommendations Tests", .serialized)
struct GetChatRecommendationsTests {
    @Test("trims query and clamps max results")
    func trimsQueryAndClampsMaxResults() async throws {
        let repository = MockRecommendationRepository()
        repository.result = .success(
            ChatRecommendationResult(
                query: "smart sci-fi",
                recommendations: RecommendationFixtures.recommendations,
                explanation: "A focused set of intelligent science fiction picks."
            )
        )
        let sut = GetChatRecommendations(repository: repository)
        
        let snapshot = try await sut.execute(
            query: "  smart sci-fi  ",
            maxResults: 10
        )
        
        #expect(repository.capturedQuery == "smart sci-fi")
        #expect(repository.capturedMaxResults == 5)
        #expect(snapshot.query == "smart sci-fi")
        #expect(snapshot.recommendations.count == 2)
    }
    
    @Test("uses minimum result clamp when value is too small")
    func usesMinimumClampWhenValueTooSmall() async throws {
        let repository = MockRecommendationRepository()
        repository.result = .success(
            ChatRecommendationResult(
                query: "thriller",
                recommendations: RecommendationFixtures.recommendations,
                explanation: "Tense thrillers with clear hooks."
            )
        )
        let sut = GetChatRecommendations(repository: repository)
        
        _ = try await sut.execute(query: "thriller", maxResults: 1)
        
        #expect(repository.capturedMaxResults == 3)
    }
    
    @Test("throws for empty query")
    func throwsForEmptyQuery() async throws {
        let repository = MockRecommendationRepository()
        let sut = GetChatRecommendations(repository: repository)
        
        await #expect(throws: ChatRecommendationError.self) {
            _ = try await sut.execute(query: "   ", maxResults: 3)
        }
        
        #expect(repository.callCount == 0)
    }
    
    @Test("propagates repository failures")
    func propagatesRepositoryFailures() async throws {
        let repository = MockRecommendationRepository()
        repository.result = .failure(TestError.fetchFailed)
        let sut = GetChatRecommendations(repository: repository)
        
        await #expect(throws: TestError.self) {
            _ = try await sut.execute(query: "funny movie", maxResults: 4)
        }
    }
    
    @Test("throws when repository returns no recommendations")
    func throwsWhenRepositoryReturnsNoRecommendations() async throws {
        let repository = MockRecommendationRepository()
        repository.result = .success(
            ChatRecommendationResult(
                query: "crime",
                recommendations: [],
                explanation: "No resolvable picks."
            )
        )
        let sut = GetChatRecommendations(repository: repository)
        
        await #expect(throws: ChatRecommendationError.self) {
            _ = try await sut.execute(query: "crime", maxResults: 3)
        }
    }
}

private final class MockRecommendationRepository: RecommendationRepository, @unchecked Sendable {
    var result: Result<ChatRecommendationResult, Error> = .success(
        ChatRecommendationResult(
            query: "smart sci-fi",
            recommendations: RecommendationFixtures.recommendations,
            explanation: "A focused set of intelligent science fiction picks."
        )
    )
    var capturedQuery: String?
    var capturedMaxResults: Int?
    var callCount = 0
    
    func getRecommendations(
        query: String,
        maxResults: Int
    ) async throws -> ChatRecommendationResult {
        callCount += 1
        capturedQuery = query
        capturedMaxResults = maxResults
        return try result.get()
    }
}

private enum TestError: Error {
    case fetchFailed
}

private enum RecommendationFixtures {
    static let recommendations = [
        Recommendation(
            id: 157336,
            movie: MovieSummary(
                id: 157336,
                title: "Interstellar",
                posterPath: nil,
                releaseYear: 2014,
                rating: 8.4
            ),
            reason: "Large-scale science fiction with emotional depth."
        ),
        Recommendation(
            id: 329865,
            movie: MovieSummary(
                id: 329865,
                title: "Arrival",
                posterPath: nil,
                releaseYear: 2016,
                rating: 7.6
            ),
            reason: "Thoughtful science fiction grounded in character and mood."
        )
    ]
}

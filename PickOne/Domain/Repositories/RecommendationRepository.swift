import Foundation

protocol RecommendationRepository: Sendable {
    func getRecommendations(
        query: String,
        maxResults: Int
    ) async throws -> ChatRecommendationResult
}

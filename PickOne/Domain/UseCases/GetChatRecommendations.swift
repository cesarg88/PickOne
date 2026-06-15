import Foundation

protocol GetChatRecommendationsUseCase: Sendable {
    func execute(query: String, maxResults: Int) async throws -> ChatRecommendationSnapshot
}

final class GetChatRecommendations: GetChatRecommendationsUseCase, Sendable {
    private let repository: RecommendationRepository
    private let minResults: Int
    private let maxAllowedResults: Int
    
    init(
        repository: RecommendationRepository,
        minResults: Int = 3,
        maxAllowedResults: Int = 5
    ) {
        self.repository = repository
        self.minResults = minResults
        self.maxAllowedResults = maxAllowedResults
    }
    
    func execute(query: String, maxResults: Int) async throws -> ChatRecommendationSnapshot {
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard !trimmedQuery.isEmpty else {
            throw ChatRecommendationError.emptyQuery
        }
        
        let clampedMaxResults = min(
            max(maxResults, minResults),
            maxAllowedResults
        )
        
        let result = try await repository.getRecommendations(
            query: trimmedQuery,
            maxResults: clampedMaxResults
        )
        
        guard !result.recommendations.isEmpty else {
            throw ChatRecommendationError.noRecommendations
        }
        
        return ChatRecommendationSnapshot(
            query: result.query,
            recommendations: result.recommendations,
            explanation: result.explanation,
            asOf: Date()
        )
    }
}

enum ChatRecommendationError: Error, LocalizedError {
    case emptyQuery
    case noRecommendations
    
    var errorDescription: String? {
        switch self {
        case .emptyQuery:
            return "Recommendation query cannot be empty."
        case .noRecommendations:
            return "No recommendations were available."
        }
    }
}

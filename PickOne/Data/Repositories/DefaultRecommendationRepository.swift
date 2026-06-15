import Foundation

final class DefaultRecommendationRepository: RecommendationRepository, @unchecked Sendable {
    private let client: AIRecommendationClientProtocol
    
    init(client: AIRecommendationClientProtocol) {
        self.client = client
    }
    
    func getRecommendations(
        query: String,
        maxResults: Int
    ) async throws -> ChatRecommendationCandidateResult {
        let response = try await client.getRecommendations(
            request: AIRecommendationRequestDTO(
                query: query,
                maxResults: maxResults
            )
        )
        
        return RecommendationMapper.mapResult(
            query: query,
            response: response
        )
    }
}

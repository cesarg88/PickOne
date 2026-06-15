import Foundation

enum RecommendationMapper {
    static func mapResult(
        query: String,
        response: AIRecommendationResponseDTO
    ) -> ChatRecommendationResult {
        ChatRecommendationResult(
            query: query,
            recommendations: response.recommendations.compactMap(mapRecommendation),
            explanation: response.explanation
        )
    }
    
    private static func mapRecommendation(
        from dto: AIRecommendationItemDTO
    ) -> Recommendation? {
        guard let id = dto.id, id > 0 else {
            return nil
        }
        
        let title = dto.title?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        
        guard !title.isEmpty else {
            return nil
        }
        
        let reason = dto.reason?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        
        return Recommendation(
            id: id,
            movie: MovieSummary(
                id: id,
                title: title,
                posterPath: nil,
                releaseYear: dto.year,
                rating: 0
            ),
            reason: reason?.isEmpty == true ? nil : reason
        )
    }
}

import Foundation

enum RecommendationMapper {
    nonisolated static func mapResult(
        query: String,
        response: AIRecommendationResponseDTO
    ) -> ChatRecommendationCandidateResult {
        ChatRecommendationCandidateResult(
            query: query,
            candidates: response.recommendations.compactMap(mapCandidate),
            explanation: response.explanation
        )
    }
    
    nonisolated private static func mapCandidate(
        from dto: AIRecommendationItemDTO
    ) -> RecommendationCandidate? {
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
        
        return RecommendationCandidate(
            id: id,
            title: title,
            year: dto.year,
            reason: reason?.isEmpty == true ? nil : reason
        )
    }
}

import Foundation

struct AIRecommendationRequestDTO: Codable {
    let query: String
    let maxResults: Int
}

struct AIRecommendationResponseDTO: Codable {
    let recommendations: [AIRecommendationItemDTO]
    let explanation: String
}

struct AIRecommendationItemDTO: Codable {
    let id: Int?
    let title: String?
    let year: Int?
    let reason: String?
}

import Foundation

struct AIRecommendationRequestDTO: Codable, Sendable {
    let query: String
    let maxResults: Int
}

struct AIRecommendationResponseDTO: Codable, Sendable {
    let recommendations: [AIRecommendationItemDTO]
    let explanation: String
}

struct AIRecommendationItemDTO: Codable, Sendable {
    let id: Int?
    let title: String?
    let year: Int?
    let reason: String?
}

import Testing
import Foundation
@testable import PickOne

@Suite("RecommendationRepository Tests", .serialized)
struct RecommendationRepositoryTests {
    @Test("maps valid recommendations into domain result")
    func mapsValidRecommendationsIntoDomainResult() async throws {
        let client = MockAIRecommendationClient()
        client.response = AIRecommendationResponseDTO(
            recommendations: [
                AIRecommendationItemDTO(
                    id: 157336,
                    title: "Interstellar",
                    year: 2014,
                    reason: "Epic science fiction with emotional stakes."
                ),
                AIRecommendationItemDTO(
                    id: 329865,
                    title: "Arrival",
                    year: 2016,
                    reason: "Thoughtful sci-fi with a human core."
                )
            ],
            explanation: "A tight set of cerebral sci-fi recommendations."
        )
        
        let sut = DefaultRecommendationRepository(client: client)
        
        let result = try await sut.getRecommendations(
            query: "smart sci-fi",
            maxResults: 5
        )
        
        #expect(client.capturedRequest?.query == "smart sci-fi")
        #expect(client.capturedRequest?.maxResults == 5)
        #expect(result.query == "smart sci-fi")
        #expect(result.recommendations.count == 2)
        #expect(result.recommendations[0].id == 157336)
        #expect(result.recommendations[0].movie.title == "Interstellar")
        #expect(result.recommendations[0].movie.releaseYear == 2014)
        #expect(result.recommendations[0].reason == "Epic science fiction with emotional stakes.")
        #expect(result.explanation == "A tight set of cerebral sci-fi recommendations.")
    }
    
    @Test("filters unusable recommendations without tmdb identity")
    func filtersUnusableRecommendationsWithoutTMDBIdentity() async throws {
        let client = MockAIRecommendationClient()
        client.response = AIRecommendationResponseDTO(
            recommendations: [
                AIRecommendationItemDTO(
                    id: nil,
                    title: "Unknown Pick",
                    year: 1999,
                    reason: "No id available."
                ),
                AIRecommendationItemDTO(
                    id: -1,
                    title: "Broken Pick",
                    year: 2001,
                    reason: "Invalid id."
                ),
                AIRecommendationItemDTO(
                    id: 603,
                    title: "  The Matrix  ",
                    year: 1999,
                    reason: "  A landmark sci-fi action film.  "
                ),
                AIRecommendationItemDTO(
                    id: 550,
                    title: "   ",
                    year: 1999,
                    reason: "Missing title."
                )
            ],
            explanation: "Only resolvable results should survive."
        )
        
        let sut = DefaultRecommendationRepository(client: client)
        
        let result = try await sut.getRecommendations(
            query: "sci-fi",
            maxResults: 3
        )
        
        #expect(result.recommendations.count == 1)
        #expect(result.recommendations[0].id == 603)
        #expect(result.recommendations[0].movie.title == "The Matrix")
        #expect(result.recommendations[0].reason == "A landmark sci-fi action film.")
    }
    
    @Test("propagates client failure")
    func propagatesClientFailure() async throws {
        let client = MockAIRecommendationClient()
        client.error = NetworkError.timeout
        let sut = DefaultRecommendationRepository(client: client)
        
        await #expect(throws: NetworkError.self) {
            _ = try await sut.getRecommendations(
                query: "thriller",
                maxResults: 4
            )
        }
    }
}

private final class MockAIRecommendationClient: AIRecommendationClientProtocol {
    var response = AIRecommendationResponseDTO(
        recommendations: [],
        explanation: ""
    )
    var error: Error?
    var capturedRequest: AIRecommendationRequestDTO?
    
    func getRecommendations(
        request: AIRecommendationRequestDTO
    ) async throws -> AIRecommendationResponseDTO {
        capturedRequest = request
        
        if let error {
            throw error
        }
        
        return response
    }
}

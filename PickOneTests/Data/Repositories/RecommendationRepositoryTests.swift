import Testing
import Foundation
@testable import PickOne

@MainActor
@Suite("RecommendationRepository Tests", .serialized)
struct RecommendationRepositoryTests {
    @Test("maps valid recommendations into candidate result")
    func mapsValidRecommendationsIntoCandidateResult() async throws {
        let client = MockAIRecommendationClient(response: AIRecommendationResponseDTO(
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
        ))
        
        let sut = DefaultRecommendationRepository(client: client)
        
        let result = try await sut.getRecommendations(
            query: "smart sci-fi",
            maxResults: 5
        )
        
        let capturedRequest = await client.capturedRequest
        #expect(capturedRequest?.query == "smart sci-fi")
        #expect(capturedRequest?.maxResults == 5)
        #expect(result.query == "smart sci-fi")
        #expect(result.candidates.count == 2)
        #expect(result.candidates[0].id == 157336)
        #expect(result.candidates[0].title == "Interstellar")
        #expect(result.candidates[0].year == 2014)
        #expect(result.candidates[0].reason == "Epic science fiction with emotional stakes.")
        #expect(result.explanation == "A tight set of cerebral sci-fi recommendations.")
    }
    
    @Test("filters unusable recommendations without tmdb identity")
    func filtersUnusableRecommendationsWithoutTMDBIdentity() async throws {
        let client = MockAIRecommendationClient(response: AIRecommendationResponseDTO(
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
        ))
        
        let sut = DefaultRecommendationRepository(client: client)
        
        let result = try await sut.getRecommendations(
            query: "sci-fi",
            maxResults: 3
        )
        
        #expect(result.candidates.count == 1)
        #expect(result.candidates[0].id == 603)
        #expect(result.candidates[0].title == "The Matrix")
        #expect(result.candidates[0].reason == "A landmark sci-fi action film.")
    }
    
    @Test("propagates client failure")
    func propagatesClientFailure() async throws {
        let client = MockAIRecommendationClient(error: .timeout)
        let sut = DefaultRecommendationRepository(client: client)
        
        await #expect(throws: NetworkError.self) {
            _ = try await sut.getRecommendations(
                query: "thriller",
                maxResults: 4
            )
        }
    }
}

private actor MockAIRecommendationClient: AIRecommendationClientProtocol {
    enum MockError: Equatable, Sendable {
        case timeout
    }

    private let response: AIRecommendationResponseDTO
    private let error: MockError?
    private(set) var capturedRequest: AIRecommendationRequestDTO?

    init(
        response: AIRecommendationResponseDTO = AIRecommendationResponseDTO(
            recommendations: [],
            explanation: ""
        ),
        error: MockError? = nil
    ) {
        self.response = response
        self.error = error
    }
    
    func getRecommendations(
        request: AIRecommendationRequestDTO
    ) async throws -> AIRecommendationResponseDTO {
        capturedRequest = request
        
        if error == .timeout {
            throw NetworkError.timeout
        }
        
        return response
    }
}

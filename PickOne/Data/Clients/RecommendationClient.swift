import Foundation

protocol RecommendationClient: Sendable {
    func getRecommendations(
        request: AIRecommendationRequestDTO
    ) async throws -> AIRecommendationResponseDTO
}

final class HTTPRecommendationClient {
    private let httpClient: HTTPClient
    private let endpointPath: String
    private let apiKey: String?
    private let timeout: TimeInterval?
    
    init(
        httpClient: HTTPClient,
        endpointPath: String = "recommendations",
        apiKey: String? = nil,
        timeout: TimeInterval? = nil
    ) {
        self.httpClient = httpClient
        self.endpointPath = endpointPath
        self.apiKey = apiKey
        self.timeout = timeout
    }
}

extension HTTPRecommendationClient: RecommendationClient {
    func getRecommendations(
        request: AIRecommendationRequestDTO
    ) async throws -> AIRecommendationResponseDTO {
        return try await httpClient.request(
            endpoint: endpointPath,
            method: .post,
            parameters: nil,
            headers: authHeaders,
            timeout: timeout,
            body: request
        )
    }
    
    private var authHeaders: [String: String]? {
        guard let apiKey, !apiKey.isEmpty else {
            return nil
        }
        return ["Authorization": "Bearer \(apiKey)"]
    }
}

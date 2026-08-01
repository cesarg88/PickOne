import Foundation

protocol GetChatRecommendationsUseCase: Sendable {
    func execute(query: String, maxResults: Int) async throws -> ChatRecommendationSnapshot
}

final class GetChatRecommendations: GetChatRecommendationsUseCase, Sendable {
    private let repository: RecommendationRepository
    private let movieRepository: MovieRepository
    private let minResults: Int
    private let maxAllowedResults: Int

    init(
        repository: RecommendationRepository,
        movieRepository: MovieRepository,
        minResults: Int = 3,
        maxAllowedResults: Int = 5
    ) {
        self.repository = repository
        self.movieRepository = movieRepository
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

        let recommendations = try await enrichCandidates(result.candidates)

        guard !recommendations.isEmpty else {
            throw ChatRecommendationError.noRecommendations
        }

        return ChatRecommendationSnapshot(
            query: result.query,
            recommendations: recommendations,
            explanation: result.explanation,
            asOf: Date()
        )
    }

    private func enrichCandidates(
        _ candidates: [RecommendationCandidate]
    ) async throws -> [Recommendation] {
        var recommendations: [Recommendation] = []
        recommendations.reserveCapacity(candidates.count)

        for candidate in candidates {
            try Task.checkCancellation()

            do {
                let movie = try await movieRepository
                    .getMovieDetail(id: candidate.id, policy: .returnCacheElseLoad)
                    .value

                recommendations.append(
                    Recommendation(
                        id: candidate.id,
                        movie: movie.summary,
                        reason: candidate.reason
                    )
                )
            } catch is CancellationError {
                throw CancellationError()
            } catch {
                continue
            }
        }

        return recommendations
    }
}

enum ChatRecommendationError: Error, LocalizedError, Sendable {
    case emptyQuery
    case noRecommendations

    var errorDescription: String? {
        switch self {
            case .emptyQuery:
                "Recommendation query cannot be empty."
            case .noRecommendations:
                "No recommendations were available."
        }
    }
}

import Foundation

struct StubRecommendationRepository: RecommendationRepository, Sendable {
    nonisolated func getRecommendations(
        query: String,
        maxResults: Int
    ) async throws -> ChatRecommendationResult {
        let scenario = RecommendationStubCatalog.scenario(for: query)
        let recommendations = Array(scenario.recommendations.prefix(maxResults))
        
        return ChatRecommendationResult(
            query: query,
            recommendations: recommendations,
            explanation: scenario.explanation
        )
    }
}

private enum RecommendationStubCatalog {
    nonisolated static func scenario(for query: String) -> RecommendationScenario {
        let normalized = query.lowercased()
        
        if normalized.contains("sci-fi") || normalized.contains("science fiction") || normalized.contains("arrival") {
            return sciFi
        }
        
        if normalized.contains("funny") || normalized.contains("comedy") || normalized.contains("laugh") {
            return comedy
        }
        
        if normalized.contains("thriller") || normalized.contains("tense") || normalized.contains("crime") {
            return thriller
        }
        
        return general
    }
    
    nonisolated static let sciFi = RecommendationScenario(
        explanation: "These picks lean into intelligent science fiction with emotional stakes and a strong sense of atmosphere.",
        recommendations: [
            Recommendation(
                id: 157336,
                movie: MovieSummary(id: 157336, title: "Interstellar", posterPath: nil, releaseYear: 2014, rating: 8.4),
                reason: "Large-scale science fiction with emotional depth."
            ),
            Recommendation(
                id: 329865,
                movie: MovieSummary(id: 329865, title: "Arrival", posterPath: nil, releaseYear: 2016, rating: 7.9),
                reason: "Thoughtful and intimate sci-fi grounded in character."
            ),
            Recommendation(
                id: 335984,
                movie: MovieSummary(id: 335984, title: "Blade Runner 2049", posterPath: nil, releaseYear: 2017, rating: 8.0),
                reason: "Patient, atmospheric science fiction with striking visuals."
            ),
            Recommendation(
                id: 264660,
                movie: MovieSummary(id: 264660, title: "Ex Machina", posterPath: nil, releaseYear: 2014, rating: 7.6),
                reason: "A tense AI story with sharp ideas and minimalism."
            ),
            Recommendation(
                id: 62,
                movie: MovieSummary(id: 62, title: "2001: A Space Odyssey", posterPath: nil, releaseYear: 1968, rating: 8.1),
                reason: "Classic cerebral sci-fi with a sense of awe."
            )
        ]
    )
    
    nonisolated static let comedy = RecommendationScenario(
        explanation: "These recommendations favor witty, personality-driven comedies over broad or disposable humor.",
        recommendations: [
            Recommendation(
                id: 496243,
                movie: MovieSummary(id: 496243, title: "Parasite", posterPath: nil, releaseYear: 2019, rating: 8.5),
                reason: "Darkly funny, sharp, and constantly surprising."
            ),
            Recommendation(
                id: 13,
                movie: MovieSummary(id: 13, title: "Forrest Gump", posterPath: nil, releaseYear: 1994, rating: 8.5),
                reason: "Warm, funny, and easy to connect with."
            ),
            Recommendation(
                id: 10625,
                movie: MovieSummary(id: 10625, title: "Mean Girls", posterPath: nil, releaseYear: 2004, rating: 7.0),
                reason: "Fast, quotable comedy with real bite."
            ),
            Recommendation(
                id: 772071,
                movie: MovieSummary(id: 772071, title: "Bottoms", posterPath: nil, releaseYear: 2023, rating: 6.8),
                reason: "Chaotic and specific in a way that feels fresh."
            ),
            Recommendation(
                id: 115,
                movie: MovieSummary(id: 115, title: "The Big Lebowski", posterPath: nil, releaseYear: 1998, rating: 7.8),
                reason: "Offbeat comedy with a famously relaxed vibe."
            )
        ]
    )
    
    nonisolated static let thriller = RecommendationScenario(
        explanation: "These picks focus on tension, momentum, and strong hooks without drifting too far into action spectacle.",
        recommendations: [
            Recommendation(
                id: 274,
                movie: MovieSummary(id: 274, title: "The Silence of the Lambs", posterPath: nil, releaseYear: 1991, rating: 8.3),
                reason: "A gripping thriller with iconic performances."
            ),
            Recommendation(
                id: 807,
                movie: MovieSummary(id: 807, title: "Se7en", posterPath: nil, releaseYear: 1995, rating: 8.4),
                reason: "Bleak, tense, and relentlessly compelling."
            ),
            Recommendation(
                id: 680,
                movie: MovieSummary(id: 680, title: "Pulp Fiction", posterPath: nil, releaseYear: 1994, rating: 8.5),
                reason: "Crime-driven tension with unforgettable dialogue."
            ),
            Recommendation(
                id: 11324,
                movie: MovieSummary(id: 11324, title: "Shutter Island", posterPath: nil, releaseYear: 2010, rating: 8.2),
                reason: "A moody psychological thriller with escalating paranoia."
            ),
            Recommendation(
                id: 49026,
                movie: MovieSummary(id: 49026, title: "The Dark Knight Rises", posterPath: nil, releaseYear: 2012, rating: 7.8),
                reason: "High-stakes tension with strong forward momentum."
            )
        ]
    )
    
    nonisolated static let general = RecommendationScenario(
        explanation: "These are broad, high-confidence picks meant to cover a few different tones while staying easy to choose from.",
        recommendations: [
            Recommendation(
                id: 278,
                movie: MovieSummary(id: 278, title: "The Shawshank Redemption", posterPath: nil, releaseYear: 1994, rating: 8.7),
                reason: "A universally loved drama with strong emotional payoff."
            ),
            Recommendation(
                id: 238,
                movie: MovieSummary(id: 238, title: "The Godfather", posterPath: nil, releaseYear: 1972, rating: 8.7),
                reason: "A classic if you want something weighty and absorbing."
            ),
            Recommendation(
                id: 155,
                movie: MovieSummary(id: 155, title: "The Dark Knight", posterPath: nil, releaseYear: 2008, rating: 8.5),
                reason: "Accessible, polished, and consistently engaging."
            ),
            Recommendation(
                id: 550,
                movie: MovieSummary(id: 550, title: "Fight Club", posterPath: nil, releaseYear: 1999, rating: 8.4),
                reason: "A bold pick if you want intensity and attitude."
            ),
            Recommendation(
                id: 603,
                movie: MovieSummary(id: 603, title: "The Matrix", posterPath: nil, releaseYear: 1999, rating: 8.2),
                reason: "A crowd-pleasing choice with a smart high concept."
            )
        ]
    )
}

private struct RecommendationScenario: Sendable {
    let explanation: String
    let recommendations: [Recommendation]
}

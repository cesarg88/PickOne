import Foundation

struct StubRecommendationRepository: RecommendationRepository, Sendable {
    nonisolated func getRecommendations(
        query: String,
        maxResults: Int
    ) async throws -> ChatRecommendationCandidateResult {
        let scenario = RecommendationStubCatalog.scenario(for: query)
        let candidates = Array(scenario.candidates.prefix(maxResults))

        return ChatRecommendationCandidateResult(
            query: query,
            candidates: candidates,
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
        candidates: [
            RecommendationCandidate(
                id: 157_336,
                title: "Interstellar",
                year: 2014,
                reason: "Large-scale science fiction with emotional depth."
            ),
            RecommendationCandidate(
                id: 329_865,
                title: "Arrival",
                year: 2016,
                reason: "Thoughtful and intimate sci-fi grounded in character."
            ),
            RecommendationCandidate(
                id: 335_984,
                title: "Blade Runner 2049",
                year: 2017,
                reason: "Patient, atmospheric science fiction with striking visuals."
            ),
            RecommendationCandidate(
                id: 264_660,
                title: "Ex Machina",
                year: 2014,
                reason: "A tense AI story with sharp ideas and minimalism."
            ),
            RecommendationCandidate(
                id: 62,
                title: "2001: A Space Odyssey",
                year: 1968,
                reason: "Classic cerebral sci-fi with a sense of awe."
            ),
        ]
    )

    nonisolated static let comedy = RecommendationScenario(
        explanation: "These recommendations favor witty, personality-driven comedies over broad or disposable humor.",
        candidates: [
            RecommendationCandidate(
                id: 496_243,
                title: "Parasite",
                year: 2019,
                reason: "Darkly funny, sharp, and constantly surprising."
            ),
            RecommendationCandidate(
                id: 13,
                title: "Forrest Gump",
                year: 1994,
                reason: "Warm, funny, and easy to connect with."
            ),
            RecommendationCandidate(
                id: 10625,
                title: "Mean Girls",
                year: 2004,
                reason: "Fast, quotable comedy with real bite."
            ),
            RecommendationCandidate(
                id: 772_071,
                title: "Bottoms",
                year: 2023,
                reason: "Chaotic and specific in a way that feels fresh."
            ),
            RecommendationCandidate(
                id: 115,
                title: "The Big Lebowski",
                year: 1998,
                reason: "Offbeat comedy with a famously relaxed vibe."
            ),
        ]
    )

    nonisolated static let thriller = RecommendationScenario(
        explanation: "These picks focus on tension, momentum, and strong hooks without drifting too far into action spectacle.",
        candidates: [
            RecommendationCandidate(
                id: 274,
                title: "The Silence of the Lambs",
                year: 1991,
                reason: "A gripping thriller with iconic performances."
            ),
            RecommendationCandidate(
                id: 807,
                title: "Se7en",
                year: 1995,
                reason: "Bleak, tense, and relentlessly compelling."
            ),
            RecommendationCandidate(
                id: 680,
                title: "Pulp Fiction",
                year: 1994,
                reason: "Crime-driven tension with unforgettable dialogue."
            ),
            RecommendationCandidate(
                id: 11324,
                title: "Shutter Island",
                year: 2010,
                reason: "A moody psychological thriller with escalating paranoia."
            ),
            RecommendationCandidate(
                id: 49026,
                title: "The Dark Knight Rises",
                year: 2012,
                reason: "High-stakes tension with strong forward momentum."
            ),
        ]
    )

    nonisolated static let general = RecommendationScenario(
        explanation: "These are broad, high-confidence picks meant to cover a few different tones while staying easy to choose from.",
        candidates: [
            RecommendationCandidate(
                id: 278,
                title: "The Shawshank Redemption",
                year: 1994,
                reason: "A universally loved drama with strong emotional payoff."
            ),
            RecommendationCandidate(
                id: 238,
                title: "The Godfather",
                year: 1972,
                reason: "A classic if you want something weighty and absorbing."
            ),
            RecommendationCandidate(
                id: 155,
                title: "The Dark Knight",
                year: 2008,
                reason: "Accessible, polished, and consistently engaging."
            ),
            RecommendationCandidate(
                id: 550,
                title: "Fight Club",
                year: 1999,
                reason: "A bold pick if you want intensity and attitude."
            ),
            RecommendationCandidate(
                id: 603,
                title: "The Matrix",
                year: 1999,
                reason: "A crowd-pleasing choice with a smart high concept."
            ),
        ]
    )
}

private struct RecommendationScenario: Sendable {
    let explanation: String
    let candidates: [RecommendationCandidate]
}

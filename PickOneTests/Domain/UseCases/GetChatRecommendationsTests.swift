import Foundation
import Testing
@testable import PickOne

@Suite("GetChatRecommendations Tests", .serialized)
struct GetChatRecommendationsTests {
    @Test("trims query and clamps max results")
    func trimsQueryAndClampsMaxResults() async throws {
        let repository = MockRecommendationRepository(outcome: .success(
            ChatRecommendationCandidateResult(
                query: "smart sci-fi",
                candidates: RecommendationFixtures.candidates,
                explanation: "A focused set of intelligent science fiction picks."
            )
        ))
        let movieRepository = MockMovieRepository(
            movieDetails: RecommendationFixtures.movieDetails
        )
        let sut = GetChatRecommendations(
            repository: repository,
            movieRepository: movieRepository
        )
        
        let snapshot = try await sut.execute(
            query: "  smart sci-fi  ",
            maxResults: 10
        )
        
        #expect(await repository.capturedQuery == "smart sci-fi")
        #expect(await repository.capturedMaxResults == 5)
        #expect(await movieRepository.capturedIDs == [157336, 329865])
        #expect(snapshot.query == "smart sci-fi")
        #expect(snapshot.recommendations.count == 2)
        #expect(snapshot.recommendations[0].movie.rating == 8.4)
    }
    
    @Test("uses minimum result clamp when value is too small")
    func usesMinimumClampWhenValueTooSmall() async throws {
        let repository = MockRecommendationRepository(outcome: .success(
            ChatRecommendationCandidateResult(
                query: "thriller",
                candidates: RecommendationFixtures.candidates,
                explanation: "Tense thrillers with clear hooks."
            )
        ))
        let movieRepository = MockMovieRepository(
            movieDetails: RecommendationFixtures.movieDetails
        )
        let sut = GetChatRecommendations(
            repository: repository,
            movieRepository: movieRepository
        )
        
        _ = try await sut.execute(query: "thriller", maxResults: 1)
        
        #expect(await repository.capturedMaxResults == 3)
    }
    
    @Test("throws for empty query")
    func throwsForEmptyQuery() async throws {
        let repository = MockRecommendationRepository()
        let movieRepository = MockMovieRepository()
        let sut = GetChatRecommendations(
            repository: repository,
            movieRepository: movieRepository
        )
        
        await #expect(throws: ChatRecommendationError.self) {
            _ = try await sut.execute(query: "   ", maxResults: 3)
        }
        
        #expect(await repository.callCount == 0)
    }
    
    @Test("propagates repository failures")
    func propagatesRepositoryFailures() async throws {
        let repository = MockRecommendationRepository(outcome: .failure)
        let movieRepository = MockMovieRepository()
        let sut = GetChatRecommendations(
            repository: repository,
            movieRepository: movieRepository
        )
        
        await #expect(throws: TestError.self) {
            _ = try await sut.execute(query: "funny movie", maxResults: 4)
        }
    }
    
    @Test("drops unresolved candidates and keeps resolved ones")
    func dropsUnresolvedCandidatesAndKeepsResolvedOnes() async throws {
        let repository = MockRecommendationRepository(outcome: .success(
            ChatRecommendationCandidateResult(
                query: "crime",
                candidates: RecommendationFixtures.candidates,
                explanation: "Mixed resolvable picks."
            )
        ))
        let movieRepository = MockMovieRepository(
            movieDetails: [
                157336: RecommendationFixtures.movieDetails[157336]
            ].compactMapValues { $0 }
        )
        let sut = GetChatRecommendations(
            repository: repository,
            movieRepository: movieRepository
        )
        
        let snapshot = try await sut.execute(query: "crime", maxResults: 3)
        
        #expect(snapshot.recommendations.count == 1)
        #expect(snapshot.recommendations[0].id == 157336)
        #expect(snapshot.recommendations[0].reason == "Large-scale science fiction with emotional depth.")
    }
    
    @Test("throws when no candidates can be enriched")
    func throwsWhenNoCandidatesCanBeEnriched() async throws {
        let repository = MockRecommendationRepository(outcome: .success(
            ChatRecommendationCandidateResult(
                query: "crime",
                candidates: RecommendationFixtures.candidates,
                explanation: "No resolvable picks."
            )
        ))
        let movieRepository = MockMovieRepository()
        let sut = GetChatRecommendations(
            repository: repository,
            movieRepository: movieRepository
        )
        
        await #expect(throws: ChatRecommendationError.self) {
            _ = try await sut.execute(query: "crime", maxResults: 3)
        }
    }
}

private actor MockRecommendationRepository: RecommendationRepository {
    enum Outcome: Sendable {
        case success(ChatRecommendationCandidateResult)
        case failure
    }

    private let outcome: Outcome
    private(set) var capturedQuery: String?
    private(set) var capturedMaxResults: Int?
    private(set) var callCount = 0

    init(
        outcome: Outcome = .success(
            ChatRecommendationCandidateResult(
                query: "smart sci-fi",
                candidates: RecommendationFixtures.candidates,
                explanation: "A focused set of intelligent science fiction picks."
            )
        )
    ) {
        self.outcome = outcome
    }
    
    func getRecommendations(
        query: String,
        maxResults: Int
    ) async throws -> ChatRecommendationCandidateResult {
        callCount += 1
        capturedQuery = query
        capturedMaxResults = maxResults
        switch outcome {
        case .success(let result):
            return result
        case .failure:
            throw TestError.fetchFailed
        }
    }
}

private actor MockMovieRepository: MovieRepository {
    private let movieDetails: [Int: Movie]
    private(set) var capturedIDs: [Int] = []

    init(movieDetails: [Int: Movie] = [:]) {
        self.movieDetails = movieDetails
    }
    
    func getTopRated(page: Int, policy: CachePolicy) async throws -> CacheResult<MoviePage> {
        fatalError("Unused in test")
    }
    
    func getMovieDetail(id: Int, policy: CachePolicy) async throws -> CacheResult<Movie> {
        capturedIDs.append(id)
        
        guard let movie = movieDetails[id] else {
            throw TestError.fetchFailed
        }
        
        return CacheResult(value: movie, isStale: false)
    }
    
    func getSimilarMovies(id: Int, page: Int, policy: CachePolicy) async throws -> CacheResult<MoviePage> {
        fatalError("Unused in test")
    }
    
    func getCredits(id: Int, policy: CachePolicy) async throws -> CacheResult<Credits> {
        fatalError("Unused in test")
    }
    
    func searchMovies(query: String, page: Int) async throws -> MoviePage {
        fatalError("Unused in test")
    }
}

private enum TestError: Error, Sendable {
    case fetchFailed
}

private enum RecommendationFixtures {
    static let candidates = [
        RecommendationCandidate(
            id: 157336,
            title: "Interstellar",
            year: 2014,
            reason: "Large-scale science fiction with emotional depth."
        ),
        RecommendationCandidate(
            id: 329865,
            title: "Arrival",
            year: 2016,
            reason: "Thoughtful science fiction grounded in character and mood."
        )
    ]
    
    static let movieDetails: [Int: Movie] = [
        157336: Movie(
            id: 157336,
            title: "Interstellar",
            originalTitle: "Interstellar",
            overview: "Space exploration with emotional stakes.",
            releaseDate: Date(timeIntervalSince1970: 1_419_292_800),
            runtime: 169,
            rating: 8.4,
            voteCount: 100,
            posterPath: "/interstellar.jpg",
            backdropPath: nil,
            genres: [],
            tagline: nil
        ),
        329865: Movie(
            id: 329865,
            title: "Arrival",
            originalTitle: "Arrival",
            overview: "First contact through language.",
            releaseDate: Date(timeIntervalSince1970: 1_478_649_600),
            runtime: 116,
            rating: 7.6,
            voteCount: 100,
            posterPath: "/arrival.jpg",
            backdropPath: nil,
            genres: [],
            tagline: nil
        )
    ]
}

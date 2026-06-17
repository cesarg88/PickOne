import Testing
import Foundation
@testable import PickOne

@MainActor
@Suite("RecommendationViewModel Tests", .serialized)
struct RecommendationViewModelTests {
    @Test("submit trims query and loads recommendations")
    func submitTrimsQueryAndLoadsRecommendations() async throws {
        let useCase = MockGetChatRecommendationsUseCase()
        useCase.result = .success(TestFixtures.snapshot)
        let sut = RecommendationViewModel(getChatRecommendations: useCase)
        sut.query = "  smart sci-fi  "
        
        await sut.submit()
        
        #expect(useCase.capturedQuery == "smart sci-fi")
        #expect(useCase.capturedMaxResults == AppConfiguration.maxAIRecommendations)
        
        guard case .loaded(let model) = sut.state else {
            Issue.record("Expected loaded state")
            return
        }
        
        #expect(sut.query == "smart sci-fi")
        #expect(model.query == "smart sci-fi")
        #expect(model.items.count == 2)
        #expect(model.items[0].title == "Interstellar")
        #expect(model.items[0].ratingText == "—")
    }
    
    @Test("submit with empty query stays idle")
    func submitWithEmptyQueryStaysIdle() async throws {
        let useCase = MockGetChatRecommendationsUseCase()
        let sut = RecommendationViewModel(getChatRecommendations: useCase)
        sut.query = "   "
        
        await sut.submit()
        
        #expect(sut.state == .idle)
        #expect(useCase.callCount == 0)
    }
    
    @Test("no recommendations maps to empty state")
    func noRecommendationsMapsToEmptyState() async throws {
        let useCase = MockGetChatRecommendationsUseCase()
        useCase.result = .failure(ChatRecommendationError.noRecommendations)
        let sut = RecommendationViewModel(getChatRecommendations: useCase)
        sut.query = "crime thrillers"
        
        await sut.submit()
        
        guard case .empty(let query) = sut.state else {
            Issue.record("Expected empty state")
            return
        }
        
        #expect(query == "crime thrillers")
    }
    
    @Test("failure maps to error and preserves query")
    func failureMapsToErrorAndPreservesQuery() async throws {
        let useCase = MockGetChatRecommendationsUseCase()
        useCase.result = .failure(TestError.requestFailed)
        let sut = RecommendationViewModel(getChatRecommendations: useCase)
        sut.query = "funny movies"
        
        await sut.submit()
        
        guard case .error(let query, let message) = sut.state else {
            Issue.record("Expected error state")
            return
        }
        
        #expect(query == "funny movies")
        #expect(message.isEmpty == false)
        #expect(sut.query == "funny movies")
    }
    
    @Test("retry resubmits current query")
    func retryResubmitsCurrentQuery() async throws {
        let useCase = MockGetChatRecommendationsUseCase()
        useCase.result = .success(TestFixtures.snapshot)
        let sut = RecommendationViewModel(getChatRecommendations: useCase)
        sut.query = "mind-bending"
        
        await sut.retry()
        
        #expect(useCase.callCount == 1)
        #expect(useCase.capturedQuery == "mind-bending")
    }
    
    @Test("older request cannot overwrite newer results")
    func olderRequestCannotOverwriteNewerResults() async throws {
        let useCase = ControlledGetChatRecommendationsUseCase()
        let sut = RecommendationViewModel(getChatRecommendations: useCase)
        
        sut.query = "first"
        let firstTask = Task { await sut.submit() }
        await useCase.waitUntilStarted(query: "first")
        
        sut.query = "second"
        let secondTask = Task { await sut.submit() }
        await useCase.waitUntilStarted(query: "second")
        
        await useCase.complete(query: "second", with: .success(TestFixtures.secondSnapshot))
        await secondTask.value
        
        guard case .loaded(let loadedAfterSecond) = sut.state else {
            Issue.record("Expected loaded state after second request")
            return
        }
        
        #expect(loadedAfterSecond.query == "second")
        #expect(loadedAfterSecond.items.first?.title == "Arrival")
        
        await useCase.complete(query: "first", with: .success(TestFixtures.snapshot))
        await firstTask.value
        
        guard case .loaded(let finalLoaded) = sut.state else {
            Issue.record("Expected loaded state to remain on latest request")
            return
        }
        
        #expect(finalLoaded.query == "second")
        #expect(finalLoaded.items.first?.title == "Arrival")
    }
}

@MainActor
private final class MockGetChatRecommendationsUseCase: GetChatRecommendationsUseCase {
    var result: Result<ChatRecommendationSnapshot, Error> = .success(TestFixtures.snapshot)
    var capturedQuery: String?
    var capturedMaxResults: Int?
    var callCount = 0
    
    func execute(query: String, maxResults: Int) async throws -> ChatRecommendationSnapshot {
        callCount += 1
        capturedQuery = query
        capturedMaxResults = maxResults
        return try result.get()
    }
}

private enum TestError: LocalizedError {
    case requestFailed
    
    var errorDescription: String? {
        "Request failed"
    }
}

private enum TestFixtures {
    static let snapshot = ChatRecommendationSnapshot(
        query: "smart sci-fi",
        recommendations: [
            Recommendation(
                id: 157336,
                movie: MovieSummary(
                    id: 157336,
                    title: "Interstellar",
                    posterPath: nil,
                    releaseYear: 2014,
                    rating: 0
                ),
                reason: "Epic science fiction with emotional weight."
            ),
            Recommendation(
                id: 329865,
                movie: MovieSummary(
                    id: 329865,
                    title: "Arrival",
                    posterPath: nil,
                    releaseYear: 2016,
                    rating: 0
                ),
                reason: "Thoughtful sci-fi grounded in character."
            )
        ],
        explanation: "These picks focus on emotionally rich science fiction.",
        asOf: Date()
    )
    
    static let secondSnapshot = ChatRecommendationSnapshot(
        query: "second",
        recommendations: [
            Recommendation(
                id: 329865,
                movie: MovieSummary(
                    id: 329865,
                    title: "Arrival",
                    posterPath: nil,
                    releaseYear: 2016,
                    rating: 7.6
                ),
                reason: "Thoughtful sci-fi grounded in character."
            )
        ],
        explanation: "Second request wins.",
        asOf: Date()
    )
}

private actor ControlledGetChatRecommendationsUseCase: GetChatRecommendationsUseCase {
    private var continuations: [String: CheckedContinuation<ChatRecommendationSnapshot, Error>] = [:]
    private var startedQueries: Set<String> = []
    
    func execute(query: String, maxResults: Int) async throws -> ChatRecommendationSnapshot {
        startedQueries.insert(query)
        
        return try await withCheckedThrowingContinuation { continuation in
            continuations[query] = continuation
        }
    }
    
    func waitUntilStarted(query: String) async {
        while startedQueries.contains(query) == false {
            await Task.yield()
        }
    }
    
    func complete(query: String, with result: Result<ChatRecommendationSnapshot, Error>) {
        guard let continuation = continuations.removeValue(forKey: query) else {
            return
        }
        
        continuation.resume(with: result)
    }
}

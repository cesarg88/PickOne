import Foundation
import Observation

enum RecommendationViewState: Equatable {
    case idle
    case loading
    case loaded(RecommendationPresentationModel)
    case empty(query: String)
    case error(query: String, message: String)
}

@MainActor
@Observable
final class RecommendationViewModel {
    private let getChatRecommendations: GetChatRecommendationsUseCase
    private let maxResults: Int
    
    var state: RecommendationViewState = .idle
    var query: String = ""
    
    init(
        getChatRecommendations: GetChatRecommendationsUseCase,
        maxResults: Int? = nil
    ) {
        self.getChatRecommendations = getChatRecommendations
        self.maxResults = maxResults ?? AppConfiguration.maxAIRecommendations
    }
    
    func submit() async {
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard !trimmedQuery.isEmpty else {
            state = .idle
            return
        }
        
        query = trimmedQuery
        state = .loading
        
        do {
            let snapshot = try await getChatRecommendations.execute(
                query: trimmedQuery,
                maxResults: maxResults
            )
            
            if snapshot.recommendations.isEmpty {
                state = .empty(query: trimmedQuery)
            } else {
                state = .loaded(RecommendationPresentationMapper.map(snapshot: snapshot))
            }
        } catch let error as ChatRecommendationError {
            switch error {
            case .emptyQuery:
                state = .idle
            case .noRecommendations:
                state = .empty(query: trimmedQuery)
            }
        } catch {
            state = .error(
                query: trimmedQuery,
                message: error.localizedDescription
            )
        }
    }
    
    func retry() async {
        await submit()
    }
    
    func clear() {
        query = ""
        state = .idle
    }
}

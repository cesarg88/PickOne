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
    private var currentTask: Task<ChatRecommendationSnapshot, Error>?
    private var latestRequestID: Int = 0
    
    var state: RecommendationViewState = .idle
    var query: String = ""
    
    var isLoading: Bool {
        if case .loading = state {
            return true
        }
        
        return false
    }
    
    var canSubmit: Bool {
        query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false && isLoading == false
    }
    
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
        currentTask?.cancel()
        latestRequestID += 1
        let requestID = latestRequestID
        state = .loading
        
        let task = Task {
            try await getChatRecommendations.execute(
                query: trimmedQuery,
                maxResults: maxResults
            )
        }
        currentTask = task
        
        do {
            let snapshot = try await task.value
            
            guard requestID == latestRequestID else {
                return
            }
            
            if snapshot.recommendations.isEmpty {
                state = .empty(query: trimmedQuery)
            } else {
                state = .loaded(RecommendationPresentationMapper.map(snapshot: snapshot))
            }
            currentTask = nil
        } catch is CancellationError {
            guard requestID == latestRequestID else {
                return
            }
            currentTask = nil
        } catch let error as ChatRecommendationError {
            guard requestID == latestRequestID else {
                return
            }
            switch error {
            case .emptyQuery:
                state = .idle
            case .noRecommendations:
                state = .empty(query: trimmedQuery)
            }
            currentTask = nil
        } catch {
            guard requestID == latestRequestID else {
                return
            }
            state = .error(
                query: trimmedQuery,
                message: error.localizedDescription
            )
            currentTask = nil
        }
    }
    
    func retry() async {
        await submit()
    }
    
    func submitSuggestedPrompt(_ prompt: String) async {
        query = prompt
        await submit()
    }
    
    func clear() {
        latestRequestID += 1
        currentTask?.cancel()
        currentTask = nil
        query = ""
        state = .idle
    }
}

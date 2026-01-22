//
//  SearchViewModel.swift
//  PickOne
//
//  ViewModel for the Search screen
//

import Foundation
import Observation

// MARK: - State

enum SearchViewState: Equatable {
    case idle(history: [String])
    case searching
    case results(SearchPresentationModel)
    case empty(query: String)
    case error(String)
}

// MARK: - ViewModel

@MainActor
@Observable
final class SearchViewModel {
    
    private let searchMovies: SearchMoviesUseCase
    private let searchHistory: SearchHistoryUseCase
    
    var state: SearchViewState = .idle(history: [])
    var query: String = ""
    
    private var currentPage: Int = 1
    private var currentQuery: String = ""
    private var searchTask: Task<Void, Never>?
    
    init(
        searchMovies: SearchMoviesUseCase,
        searchHistory: SearchHistoryUseCase
    ) {
        self.searchMovies = searchMovies
        self.searchHistory = searchHistory
    }
    
    // MARK: - Actions
    
    func loadHistory() {
        let history = searchHistory.getHistory()
        state = .idle(history: history)
    }
    
    func onQueryChange(_ newQuery: String) {
        query = newQuery
        
        // Cancel previous search
        searchTask?.cancel()
        
        let trimmed = newQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        
        if trimmed.isEmpty {
            loadHistory()
            return
        }
        
        // Debounce search
        searchTask = Task {
            try? await Task.sleep(for: .milliseconds(300))
            
            guard !Task.isCancelled else { return }
            await performSearch(query: trimmed, page: 1, append: false)
        }
    }
    
    func selectHistoryItem(_ historyQuery: String) {
        query = historyQuery
        
        searchTask?.cancel()
        searchTask = Task {
            await performSearch(query: historyQuery, page: 1, append: false)
        }
    }
    
    func clearHistory() {
        searchHistory.clear()
        loadHistory()
    }
    
    func loadNextPage() async {
        guard case .results(var data) = state,
              data.hasMorePages,
              !data.isLoadingNextPage,
              !currentQuery.isEmpty else {
            return
        }
        
        data.isLoadingNextPage = true
        state = .results(data)
        
        await performSearch(query: currentQuery, page: currentPage + 1, append: true)
    }
    
    func clearSearch() {
        query = ""
        searchTask?.cancel()
        loadHistory()
    }
    
    // MARK: - Private
    
    private func performSearch(query: String, page: Int, append: Bool) async {
        if !append {
            state = .searching
        }
        
        do {
            let snapshot = try await searchMovies.execute(query: query, page: page)
            
            if snapshot.results.isEmpty && page == 1 {
                state = .empty(query: query)
                return
            }
            
            currentQuery = query
            currentPage = snapshot.currentPage
            
            var model = SearchPresentationMapper.map(snapshot: snapshot)
            
            if append, case .results(let existing) = state {
                // Merge results, avoiding duplicates
                var seen = Set(existing.items.map(\.id))
                var merged = existing.items
                for item in model.items where !seen.contains(item.id) {
                    merged.append(item)
                    seen.insert(item.id)
                }
                model = SearchPresentationModel(
                    query: model.query,
                    items: merged,
                    hasMorePages: model.hasMorePages,
                    isLoadingNextPage: false
                )
            }
            
            state = .results(model)
            
        } catch {
            if !append {
                state = .error(error.localizedDescription)
            } else if case .results(var data) = state {
                data.isLoadingNextPage = false
                state = .results(data)
            }
        }
    }
}

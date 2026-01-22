//
//  SearchMovies.swift
//  PickOne
//
//  Use case for searching movies
//

import Foundation

protocol SearchMoviesUseCase: Sendable {
    /// Searches for movies matching the query
    /// - Parameters:
    ///   - query: The search query
    ///   - page: The page number (1-indexed)
    /// - Returns: A snapshot containing search results
    func execute(query: String, page: Int) async throws -> SearchSnapshot
}

final class SearchMovies: SearchMoviesUseCase, Sendable {
    
    private let movieRepository: MovieRepository
    private let searchHistoryRepository: SearchHistoryRepository
    
    init(movieRepository: MovieRepository, searchHistoryRepository: SearchHistoryRepository) {
        self.movieRepository = movieRepository
        self.searchHistoryRepository = searchHistoryRepository
    }
    
    func execute(query: String, page: Int) async throws -> SearchSnapshot {
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard !trimmedQuery.isEmpty else {
            return SearchSnapshot.empty
        }
        
        let moviePage = try await movieRepository.searchMovies(query: trimmedQuery, page: page)
        
        // Save to history only on first page and if we got results
        if page == 1 && !moviePage.movies.isEmpty {
            searchHistoryRepository.addQuery(trimmedQuery)
        }
        
        return SearchSnapshot(
            query: trimmedQuery,
            results: moviePage.movies,
            currentPage: moviePage.page,
            totalPages: moviePage.totalPages,
            asOf: Date()
        )
    }
}

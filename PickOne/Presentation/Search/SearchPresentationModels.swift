//
//  SearchPresentationModels.swift
//  PickOne
//
//  Presentation models for the Search screen
//

import Foundation

// MARK: - Presentation Model

struct SearchPresentationModel: Equatable {
    let query: String
    let items: [SearchMovieItem]
    let hasMorePages: Bool
    var isLoadingNextPage: Bool
    
    static let empty = SearchPresentationModel(
        query: "",
        items: [],
        hasMorePages: false,
        isLoadingNextPage: false
    )
}

struct SearchMovieItem: Identifiable, Equatable {
    let id: Int
    let title: String
    let posterURL: URL?
    let releaseYear: String?
    let rating: String
    let overview: String
    
    /// The MovieSummary for passing to use cases
    let movieSummary: MovieSummary
}

// MARK: - Mapper

@MainActor
enum SearchPresentationMapper {
    
    static func map(snapshot: SearchSnapshot) -> SearchPresentationModel {
        SearchPresentationModel(
            query: snapshot.query,
            items: snapshot.results.map(mapItem),
            hasMorePages: snapshot.hasMorePages,
            isLoadingNextPage: false
        )
    }
    
    private static func mapItem(_ movie: MovieSummary) -> SearchMovieItem {
        SearchMovieItem(
            id: movie.id,
            title: movie.title,
            posterURL: posterURL(for: movie.posterPath),
            releaseYear: movie.releaseYear.map(String.init),
            rating: String(format: "%.1f", movie.rating),
            overview: "", // Summary doesn't have overview
            movieSummary: movie
        )
    }
    
    private static func posterURL(for path: String?) -> URL? {
        guard let path = path else { return nil }
        return URL(string: "https://image.tmdb.org/t/p/w342\(path)")
    }
}

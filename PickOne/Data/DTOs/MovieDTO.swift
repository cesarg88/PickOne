//
//  MovieDTO.swift
//  PickOne
//
//  Data Transfer Objects for TMDB API responses
//  Note: No CodingKeys needed - JSONDecoder uses convertFromSnakeCase strategy
//

import Foundation

// MARK: - Movie List Response (Top Rated, Popular, etc.)

struct MovieListResponseDTO: Codable, Sendable {
    let page: Int
    let results: [MovieListItemDTO]
    let totalPages: Int
    let totalResults: Int
}

// MARK: - Movie List Item (used in lists/search)

/// Note: Several fields are optional because TMDB may return null/empty
/// depending on the movie, language, or region settings
struct MovieListItemDTO: Codable, Sendable {
    let adult: Bool
    let backdropPath: String?
    let genreIds: [Int]?          // May be missing for some entries
    let id: Int
    let originalLanguage: String?
    let originalTitle: String?
    let overview: String?         // Can be empty/null for some languages
    let popularity: Double?
    let posterPath: String?
    let releaseDate: String?      // Can be empty for unreleased/unknown dates
    let title: String
    let video: Bool?
    let voteAverage: Double?
    let voteCount: Int?
}

// MARK: - Movie Detail Response

/// Note: Several fields are optional for robustness against TMDB variations
struct MovieDetailDTO: Codable, Sendable {
    let adult: Bool
    let backdropPath: String?
    let budget: Int?              // May be 0 or missing for some movies
    let genres: [GenreDTO]?       // Usually present but play safe
    let homepage: String?
    let id: Int
    let imdbId: String?
    let originalLanguage: String?
    let originalTitle: String?
    let overview: String?         // Can be empty for some languages
    let popularity: Double?
    let posterPath: String?
    let releaseDate: String?      // Can be empty for unreleased movies
    let revenue: Int?             // May be 0 or missing
    let runtime: Int?
    let status: String?
    let tagline: String?
    let title: String
    let video: Bool?
    let voteAverage: Double?
    let voteCount: Int?
}

// MARK: - Genre

struct GenreDTO: Codable, Sendable {
    let id: Int
    let name: String
}

// MARK: - Credits Response

struct CreditsResponseDTO: Codable, Sendable {
    let id: Int
    let cast: [CastMemberDTO]
    let crew: [CrewMemberDTO]
}

struct CastMemberDTO: Codable, Sendable {
    let adult: Bool?
    let gender: Int?
    let id: Int
    let knownForDepartment: String?
    let name: String
    let originalName: String?
    let popularity: Double?
    let profilePath: String?
    let castId: Int?              // May be missing in some responses
    let character: String?        // Can be empty for uncredited roles
    let creditId: String?
    let order: Int?
}

struct CrewMemberDTO: Codable, Sendable {
    let adult: Bool?
    let gender: Int?
    let id: Int
    let knownForDepartment: String?
    let name: String
    let originalName: String?
    let popularity: Double?
    let profilePath: String?
    let creditId: String?
    let department: String?
    let job: String?
}

// MARK: - Search Response

struct SearchResponseDTO: Codable, Sendable {
    let page: Int
    let results: [MovieListItemDTO]
    let totalPages: Int
    let totalResults: Int
}

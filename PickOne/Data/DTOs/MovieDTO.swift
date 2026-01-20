//
//  MovieDTO.swift
//  PickOne
//
//  Data Transfer Objects for TMDB API responses
//  Note: No CodingKeys needed - JSONDecoder uses convertFromSnakeCase strategy
//

import Foundation

// MARK: - Movie List Response (Top Rated, Popular, etc.)

struct MovieListResponseDTO: Codable {
    let page: Int
    let results: [MovieListItemDTO]
    let totalPages: Int
    let totalResults: Int
}

// MARK: - Movie List Item (used in lists/search)

struct MovieListItemDTO: Codable {
    let adult: Bool
    let backdropPath: String?
    let genreIds: [Int]
    let id: Int
    let originalLanguage: String
    let originalTitle: String
    let overview: String
    let popularity: Double
    let posterPath: String?
    let releaseDate: String
    let title: String
    let video: Bool
    let voteAverage: Double
    let voteCount: Int
}

// MARK: - Movie Detail Response

struct MovieDetailDTO: Codable {
    let adult: Bool
    let backdropPath: String?
    let budget: Int
    let genres: [GenreDTO]
    let homepage: String?
    let id: Int
    let imdbId: String?
    let originalLanguage: String
    let originalTitle: String
    let overview: String
    let popularity: Double
    let posterPath: String?
    let releaseDate: String
    let revenue: Int
    let runtime: Int?
    let status: String
    let tagline: String?
    let title: String
    let video: Bool
    let voteAverage: Double
    let voteCount: Int
}

// MARK: - Genre

struct GenreDTO: Codable {
    let id: Int
    let name: String
}

// MARK: - Credits Response

struct CreditsResponseDTO: Codable {
    let id: Int
    let cast: [CastMemberDTO]
    let crew: [CrewMemberDTO]
}

struct CastMemberDTO: Codable {
    let adult: Bool
    let gender: Int?
    let id: Int
    let knownForDepartment: String
    let name: String
    let originalName: String
    let popularity: Double
    let profilePath: String?
    let castId: Int
    let character: String
    let creditId: String
    let order: Int
}

struct CrewMemberDTO: Codable {
    let adult: Bool
    let gender: Int?
    let id: Int
    let knownForDepartment: String
    let name: String
    let originalName: String
    let popularity: Double
    let profilePath: String?
    let creditId: String
    let department: String
    let job: String
}

// MARK: - Search Response

struct SearchResponseDTO: Codable {
    let page: Int
    let results: [MovieListItemDTO]
    let totalPages: Int
    let totalResults: Int
}

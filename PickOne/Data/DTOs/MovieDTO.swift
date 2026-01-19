//
//  MovieDTO.swift
//  PickOne
//
//  Data Transfer Objects for TMDB API responses
//

import Foundation

// MARK: - Movie List Response (Top Rated, Popular, etc.)

struct MovieListResponseDTO: Codable {
    let page: Int
    let results: [MovieListItemDTO]
    let totalPages: Int
    let totalResults: Int
    
    enum CodingKeys: String, CodingKey {
        case page, results
        case totalPages = "total_pages"
        case totalResults = "total_results"
    }
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
    
    enum CodingKeys: String, CodingKey {
        case adult
        case backdropPath = "backdrop_path"
        case genreIds = "genre_ids"
        case id
        case originalLanguage = "original_language"
        case originalTitle = "original_title"
        case overview, popularity
        case posterPath = "poster_path"
        case releaseDate = "release_date"
        case title, video
        case voteAverage = "vote_average"
        case voteCount = "vote_count"
    }
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
    
    enum CodingKeys: String, CodingKey {
        case adult
        case backdropPath = "backdrop_path"
        case budget, genres, homepage, id
        case imdbId = "imdb_id"
        case originalLanguage = "original_language"
        case originalTitle = "original_title"
        case overview, popularity
        case posterPath = "poster_path"
        case releaseDate = "release_date"
        case revenue, runtime, status, tagline, title, video
        case voteAverage = "vote_average"
        case voteCount = "vote_count"
    }
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
    
    enum CodingKeys: String, CodingKey {
        case adult, gender, id
        case knownForDepartment = "known_for_department"
        case name
        case originalName = "original_name"
        case popularity
        case profilePath = "profile_path"
        case castId = "cast_id"
        case character
        case creditId = "credit_id"
        case order
    }
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
    
    enum CodingKeys: String, CodingKey {
        case adult, gender, id
        case knownForDepartment = "known_for_department"
        case name
        case originalName = "original_name"
        case popularity
        case profilePath = "profile_path"
        case creditId = "credit_id"
        case department, job
    }
}

// MARK: - Search Response

struct SearchResponseDTO: Codable {
    let page: Int
    let results: [MovieListItemDTO]
    let totalPages: Int
    let totalResults: Int
    
    enum CodingKeys: String, CodingKey {
        case page, results
        case totalPages = "total_pages"
        case totalResults = "total_results"
    }
}

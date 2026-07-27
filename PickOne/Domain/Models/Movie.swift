//
//  Movie.swift
//  PickOne
//
//  Domain models - platform-agnostic, stable, free of UI concerns
//

import Foundation

// MARK: - Movie (Full Detail)

struct Movie: Identifiable, Equatable, Sendable {
    let id: Int
    let title: String
    let originalTitle: String
    let overview: String
    let releaseDate: Date?
    let runtime: Int?
    let rating: Double
    let voteCount: Int
    let posterPath: String?
    let backdropPath: String?
    let genres: [Genre]
    let tagline: String?
    
    var releaseYear: Int? {
        guard let releaseDate = releaseDate else { return nil }
        return Calendar.current.component(.year, from: releaseDate)
    }
    
    var runtimeFormatted: String? {
        guard let runtime = runtime else { return nil }
        let hours = runtime / 60
        let minutes = runtime % 60
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes)m"
        }
    }
}

// MARK: - MovieSummary (For lists/grids)

struct MovieSummary: Identifiable, Equatable, Sendable {
    let id: Int
    let title: String
    let posterPath: String?
    let releaseYear: Int?
    let rating: Double
}

extension Movie {
    var summary: MovieSummary {
        MovieSummary(
            id: id,
            title: title,
            posterPath: posterPath,
            releaseYear: releaseYear,
            rating: rating
        )
    }
}

// MARK: - MoviePage

struct MoviePage: Equatable, Sendable {
    let page: Int
    let totalPages: Int
    let movies: [MovieSummary]
    
    var hasMorePages: Bool {
        page < totalPages
    }
}

// MARK: - Genre

struct Genre: Identifiable, Equatable, Sendable {
    let id: Int
    let name: String
}

// MARK: - Person

struct Person: Identifiable, Equatable, Sendable {
    let id: Int
    let name: String
    let profilePath: String?
    let role: PersonRole
}

enum PersonRole: Equatable, Sendable {
    case cast(character: String)
    case director
    case writer
    case other(job: String)
}

// MARK: - Credits

struct Credits: Equatable, Sendable {
    let director: Person?
    let topCast: [Person]
}

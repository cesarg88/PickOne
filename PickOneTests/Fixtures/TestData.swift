//
//  TestData.swift
//  PickOneTests
//
//  Test fixtures and sample data for unit tests.
//

import Foundation

enum TestData {
    
    // MARK: - Sample JSON Responses
    
    /// A minimal valid movie list response (snake_case as TMDB returns it)
    static let movieListResponseJSON = """
    {
        "page": 1,
        "total_pages": 10,
        "total_results": 200,
        "results": [
            {
                "id": 278,
                "title": "The Shawshank Redemption",
                "original_title": "The Shawshank Redemption",
                "original_language": "en",
                "overview": "Framed in the 1940s for the double murder...",
                "release_date": "1994-09-23",
                "adult": false,
                "backdrop_path": "/kXfqcdQKsToO0OUXHcrrNCHDBzO.jpg",
                "poster_path": "/q6y0Go1tsGEsmtFryDOJo3dEmqu.jpg",
                "genre_ids": [18, 80],
                "popularity": 123.456,
                "vote_average": 8.7,
                "vote_count": 25000,
                "video": false
            },
            {
                "id": 238,
                "title": "The Godfather",
                "original_title": "The Godfather",
                "original_language": "en",
                "overview": "Spanning the years 1945 to 1955...",
                "release_date": "1972-03-14",
                "adult": false,
                "backdrop_path": "/tmU7GeKVybMWFButWEGl2M4GeiP.jpg",
                "poster_path": "/3bhkrj58Vtu7enYsRolD1fZdja1.jpg",
                "genre_ids": [18, 80],
                "popularity": 98.765,
                "vote_average": 8.7,
                "vote_count": 19000,
                "video": false
            }
        ]
    }
    """.data(using: .utf8)!
    
    /// A movie detail response
    static let movieDetailResponseJSON = """
    {
        "id": 278,
        "title": "The Shawshank Redemption",
        "original_title": "The Shawshank Redemption",
        "original_language": "en",
        "overview": "Framed in the 1940s for the double murder of his wife and her lover...",
        "release_date": "1994-09-23",
        "adult": false,
        "backdrop_path": "/kXfqcdQKsToO0OUXHcrrNCHDBzO.jpg",
        "poster_path": "/q6y0Go1tsGEsmtFryDOJo3dEmqu.jpg",
        "genres": [
            {"id": 18, "name": "Drama"},
            {"id": 80, "name": "Crime"}
        ],
        "budget": 25000000,
        "revenue": 58300000,
        "runtime": 142,
        "status": "Released",
        "tagline": "Fear can hold you prisoner. Hope can set you free.",
        "homepage": "https://www.warnerbros.com/movies/shawshank-redemption",
        "imdb_id": "tt0111161",
        "popularity": 123.456,
        "vote_average": 8.7,
        "vote_count": 25000,
        "video": false
    }
    """.data(using: .utf8)!
    
    /// Empty results response
    static let emptyResultsJSON = """
    {
        "page": 1,
        "total_pages": 0,
        "total_results": 0,
        "results": []
    }
    """.data(using: .utf8)!
    
    /// Invalid JSON (for testing error handling)
    static let invalidJSON = "{ invalid json }".data(using: .utf8)!
    
    /// Empty data
    static let emptyData = Data()
    
    // MARK: - Simple Test Models
    
    /// A simple Codable struct for basic HTTPClient tests
    struct SimpleResponse: Codable, Equatable {
        let id: Int
        let name: String
        let isActive: Bool  // Tests snake_case conversion (is_active → isActive)
    }
    
    static let simpleResponseJSON = """
    {
        "id": 42,
        "name": "Test Item",
        "is_active": true
    }
    """.data(using: .utf8)!
    
    // MARK: - URLs
    
    static let testBaseURL = "https://api.test.com"
    static let testEndpoint = "/test/endpoint"
}

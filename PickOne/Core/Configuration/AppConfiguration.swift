//
//  AppConfiguration.swift
//  PickOne
//
//  Created by PickOne Team
//

import Foundation

/// Configuration for the application
/// Centralized access to API keys and environment settings
struct AppConfiguration {
    
    // MARK: - TMDB Configuration
    
    /// The Movie Database API Key
    /// Get your key at: https://developer.themoviedb.org/reference/getting-started
    static let tmdbAPIKey: String = {
        return "eyJhbGciOiJIUzI1NiJ9.eyJhdWQiOiIwNDk2MzZjZjBmMGY0MWRhOGM0N2M3OTI1MzBkZDJhOSIsIm5iZiI6MTc2ODgzNDQ4My4zMDQsInN1YiI6IjY5NmU0NWIzNDY0NjY0N2FhZDhmZDZiOCIsInNjb3BlcyI6WyJhcGlfcmVhZCJdLCJ2ZXJzaW9uIjoxfQ.hqWuv0vLZRuthU2u3o946zKK7cfSbwIUI2WBa1wxO0A"
    }()
    
    static let tmdbBaseURL = "https://api.themoviedb.org/3"
    static let tmdbImageBaseURL = "https://image.tmdb.org/t/p"
    
    // MARK: - Image Sizes
    
    enum ImageSize: String {
        case posterSmall = "w185"
        case posterMedium = "w342"
        case posterLarge = "w500"
        case posterOriginal = "original"
        
        case backdropSmall = "w300"
        case backdropMedium = "w780"
        case backdropLarge = "w1280"
        case backdropOriginal = "original_"
    }
    
    // MARK: - Cache Configuration
    
    static let discoveryFeedCacheTTL: TimeInterval = 24 * 60 * 60 // 24 hours
    static let movieDetailCacheTTL: TimeInterval = 7 * 24 * 60 * 60 // 7 days
    static let searchCacheTTL: TimeInterval = 10 * 60 // 10 minutes
    
    // MARK: - UI Configuration
    
    static let searchDebounceDelay: TimeInterval = 0.3 // 300ms
    static let maxAIRecommendations = 5
    static let minAIRecommendations = 3
}

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
        // TODO: Replace with actual API key when provided
        return "YOUR_TMDB_API_KEY_HERE"
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
        case backdropOriginal = "original"
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

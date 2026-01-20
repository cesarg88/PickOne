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
    /// Loaded from environment variable (configured in Xcode Scheme)
    /// Get your key at: https://developer.themoviedb.org/reference/getting-started
    static let tmdbAPIKey: String = {
        if let envKey = ProcessInfo.processInfo.environment["TMDB_API_KEY"],
           !envKey.isEmpty {
            return envKey
        }
        
        #if DEBUG
        fatalError("""
            ❌ TMDB API Key not found!
            
            Setup:
              1. In Xcode: Product → Scheme → Edit Scheme (⌘<)
              2. Select "Run" → "Arguments" tab
              3. Under "Environment Variables", add:
                 Name: TMDB_API_KEY
                 Value: your_bearer_token
            
            Get your token at: https://developer.themoviedb.org
            Use the "API Read Access Token" (Bearer token), NOT the API Key.
            """)
        #else
        return ""
        #endif
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
    }
    
    // MARK: - Cache Configuration
    
    static let discoveryFeedCacheTTL: TimeInterval = 24 * 60 * 60 // 24 hours
    static let movieDetailCacheTTL: TimeInterval = 7 * 24 * 60 * 60 // 7 days
    static let searchCacheTTL: TimeInterval = 10 * 60 // 10 minutes
    
    // MARK: - Network Configuration
    
    static let defaultRequestTimeout: TimeInterval = 30 // 30 seconds
    static let uploadRequestTimeout: TimeInterval = 60 // 60 seconds for uploads
    
    // MARK: - UI Configuration
    
    static let searchDebounceDelay: TimeInterval = 0.3 // 300ms
    static let maxAIRecommendations = 5
    static let minAIRecommendations = 3
}

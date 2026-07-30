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
    static let isUITesting = ProcessInfo.processInfo.arguments.contains("-ui-testing")
    
    // MARK: - TMDB Configuration
    
    /// The Movie Database API Key
    /// Loaded from Info.plist (injected via xcconfig at build time)
    /// Get your key at: https://developer.themoviedb.org/reference/getting-started
    static let tmdbAPIKey: String = {
        let key = (Bundle.main.object(
            forInfoDictionaryKey: "TMDBApiKey"
        ) as? String)?
        .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        
        precondition(
            !key.isEmpty && key != "YOUR_TMDB_API_KEY_HERE",
            """
            TMDB API Key is missing or not configured.
            
            To fix this:
            1. Copy Config/Debug.xcconfig.example → Config/Debug.xcconfig
            2. Replace YOUR_TMDB_API_KEY_HERE with your actual TMDB API key
            3. Rebuild the project
            
            Get your key at: https://developer.themoviedb.org/reference/getting-started
            """
        )
        
        return key
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

        case providerLogo = "w92"
    }
    
    // MARK: - Cache Configuration
    
    static let discoveryFeedCacheTTL: TimeInterval = 24 * 60 * 60 // 24 hours
    static let movieDetailCacheTTL: TimeInterval = 7 * 24 * 60 * 60 // 7 days
    static let searchCacheTTL: TimeInterval = 10 * 60 // 10 minutes
    
    // MARK: - Network Configuration
    
    static let defaultRequestTimeout: TimeInterval = 10
    static let uploadRequestTimeout: TimeInterval = 60
    
    // MARK: - UI Configuration
    
    static let searchDebounceDelay: TimeInterval = 0.3 // 300ms
    static let maxAIRecommendations = 5
    static let minAIRecommendations = 3
}

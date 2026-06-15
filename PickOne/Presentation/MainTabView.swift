//
//  MainTabView.swift
//  PickOne
//
//  Main tab navigation for the app
//

import SwiftUI

struct MainTabView: View {
    let container: AppContainer
    
    var body: some View {
        TabView {
            DiscoveryView(
                model: container.discoveryViewModel,
                getMovieDetail: container.getMovieDetail,
                setMembership: container.setWatchlistMembership,
                setWatched: container.setWatched,
                imagePipeline: container.imagePipeline
            )
            .tabItem {
                Label("Discover", systemImage: "film")
            }
            
            SearchView(
                model: container.searchViewModel,
                getMovieDetail: container.getMovieDetail,
                setMembership: container.setWatchlistMembership,
                setWatched: container.setWatched,
                imagePipeline: container.imagePipeline
            )
            .tabItem {
                Label("Search", systemImage: "magnifyingglass")
            }
            
            RecommendationView(
                model: container.recommendationViewModel,
                getMovieDetail: container.getMovieDetail,
                setMembership: container.setWatchlistMembership,
                setWatched: container.setWatched,
                imagePipeline: container.imagePipeline
            )
            .tabItem {
                Label("Ask", systemImage: "sparkles")
            }
            
            WatchlistView(
                model: container.watchlistViewModel,
                getMovieDetail: container.getMovieDetail,
                setMembership: container.setWatchlistMembership,
                setWatched: container.setWatched,
                imagePipeline: container.imagePipeline
            )
            .tabItem {
                Label("Watchlist", systemImage: "bookmark")
            }
        }
    }
}

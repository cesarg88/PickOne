//
//  MainTabView.swift
//  PickOne
//
//  Main tab navigation for the app
//

import SwiftUI

@MainActor
struct MainTabView: View {
    let container: AppContainer
    @Bindable var profileModel: ViewerProfileViewModel

    var body: some View {
        TabView {
            DiscoveryView(
                model: container.discoveryViewModel,
                getMovieDetail: container.getMovieDetail,
                setMembership: container.setWatchlistMembership,
                setWatched: container.setWatched,
                checkAvailability: container.checkMovieAvailability,
                preparePlaybackOptions: container.preparePlaybackOptions,
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
                checkAvailability: container.checkMovieAvailability,
                preparePlaybackOptions: container.preparePlaybackOptions,
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
                checkAvailability: container.checkMovieAvailability,
                preparePlaybackOptions: container.preparePlaybackOptions,
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
                checkAvailability: container.checkMovieAvailability,
                preparePlaybackOptions: container.preparePlaybackOptions,
                imagePipeline: container.imagePipeline
            )
            .tabItem {
                Label("Watchlist", systemImage: "bookmark")
            }

            SettingsView(model: profileModel)
                .tabItem {
                    Label("Settings", systemImage: "gearshape")
                }
        }
        .fullScreenCover(
            isPresented: Binding(
                get: { profileModel.presentedCalibration == .recalibration },
                set: { if !$0 { profileModel.dismissRecalibration() } }
            )
        ) {
            NavigationStack {
                CalibrationFlowView(
                    model: profileModel,
                    mode: .recalibration,
                    imagePipeline: container.imagePipeline
                )
            }
        }
    }
}

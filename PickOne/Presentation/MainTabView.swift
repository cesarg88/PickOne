//
//  MainTabView.swift
//  PickOne
//
//  Main tab navigation for the app
//

import SwiftUI

@MainActor
struct MainTabView: View {
    @Environment(\.scenePhase) private var scenePhase
    let container: AppContainer
    @Bindable var profileModel: ViewerProfileViewModel
    @State private var selectedTab = MainTab.home
    @State private var settingsPath: [SettingsRoute] = []

    var body: some View {
        TabView(selection: $selectedTab) {
            Tab("Home", systemImage: "house", value: MainTab.home) {
                HomeDecisionView(
                    model: container.homeDecisionViewModel,
                    getMovieDetail: container.getMovieDetail,
                    getViewerMovieState: container.getViewerMovieState,
                    updateViewerMovieState: container.updateHomeViewerMovieState,
                    checkAvailability: container.checkMovieAvailability,
                    preparePlaybackOptions: container.preparePlaybackOptions,
                    imagePipeline: container.imagePipeline,
                    reviewMyMovies: { showSettings(.myMovies) },
                    reviewStreamingServices: { showSettings(.streamingServices) }
                )
            }

            Tab("Search", systemImage: "magnifyingglass", value: MainTab.search) {
                SearchView(
                    model: container.searchViewModel,
                    getMovieDetail: container.getMovieDetail,
                    getViewerMovieState: container.getViewerMovieState,
                    updateViewerMovieState: container.updateViewerMovieState,
                    checkAvailability: container.checkMovieAvailability,
                    preparePlaybackOptions: container.preparePlaybackOptions,
                    imagePipeline: container.imagePipeline,
                    viewerStateDidChange: reconcileHome,
                    eligibilityDidChange: repairHome
                )
            }

            Tab("Discover", systemImage: "film", value: MainTab.discover) {
                DiscoveryView(
                    model: container.discoveryViewModel,
                    getMovieDetail: container.getMovieDetail,
                    getViewerMovieState: container.getViewerMovieState,
                    updateViewerMovieState: container.updateViewerMovieState,
                    checkAvailability: container.checkMovieAvailability,
                    preparePlaybackOptions: container.preparePlaybackOptions,
                    imagePipeline: container.imagePipeline,
                    viewerStateDidChange: reconcileHome,
                    eligibilityDidChange: repairHome
                )
            }

            Tab("Watchlist", systemImage: "bookmark", value: MainTab.watchlist) {
                WatchlistView(
                    model: container.watchlistViewModel,
                    getMovieDetail: container.getMovieDetail,
                    getViewerMovieState: container.getViewerMovieState,
                    updateViewerMovieState: container.updateViewerMovieState,
                    checkAvailability: container.checkMovieAvailability,
                    preparePlaybackOptions: container.preparePlaybackOptions,
                    imagePipeline: container.imagePipeline,
                    viewerStateDidChange: reconcileHome,
                    eligibilityDidChange: repairHome
                )
            }

            Tab("Settings", systemImage: "gearshape", value: MainTab.settings) {
                SettingsView(
                    model: profileModel,
                    myMoviesModel: container.myMoviesViewModel,
                    imagePipeline: container.imagePipeline,
                    movieDetailDependencies: MovieDetailNavigationDependencies(
                        getMovieDetail: container.getMovieDetail,
                        getViewerMovieState: container.getViewerMovieState,
                        updateViewerMovieState: container.updateViewerMovieState,
                        checkAvailability: container.checkMovieAvailability,
                        preparePlaybackOptions: container.preparePlaybackOptions,
                        viewerStateDidChange: reconcileHome,
                        eligibilityDidChange: repairHome
                    ),
                    navigationPath: $settingsPath
                )
            }
        }
        .task {
            container.homeDecisionViewModel.load()
        }
        .onChange(of: selectedTab) {
            guard selectedTab == .home else { return }
            container.homeDecisionViewModel.load()
        }
        .onChange(of: scenePhase) {
            guard scenePhase == .active else { return }
            container.homeDecisionViewModel.appDidBecomeActive()
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

    private func repairHome(_ change: DecisionEligibilityChange) {
        container.homeDecisionViewModel.repair(after: change)
    }

    private func reconcileHome(_ change: DecisionViewerStateChange) {
        container.homeDecisionViewModel.reconcile(after: change)
    }

    private func showSettings(_ route: SettingsRoute) {
        settingsPath = [route]
        selectedTab = .settings
    }
}

private enum MainTab: Hashable {
    case home
    case search
    case discover
    case watchlist
    case settings
}

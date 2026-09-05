import SwiftUI

@MainActor
struct HomeDecisionView: View {
    let model: HomeDecisionViewModel
    let getMovieDetail: GetMovieDetailUseCase
    let getViewerMovieState: GetViewerMovieStateUseCase
    let updateViewerMovieState: UpdateViewerMovieStateUseCase
    let checkAvailability: CheckMovieAvailabilityUseCase
    let preparePlaybackOptions: PreparePlaybackOptionsUseCase
    let imagePipeline: ImagePipeline
    let reviewMyMovies: () -> Void
    let reviewStreamingServices: () -> Void

    @State private var navigationPath: [HomeDecisionRoute] = []

    var body: some View {
        NavigationStack(path: $navigationPath) {
            HomeDecisionContent(
                state: model.state,
                exhaustion: model.exhaustion,
                updateFeedback: model.updateFeedback,
                imagePipeline: imagePipeline,
                updateViewerMovieState: updateViewerMovieState,
                viewerStateDidChange: model.reconcile,
                refresh: model.refresh,
                retry: model.load,
                reviewMyMovies: reviewMyMovies,
                reviewStreamingServices: reviewStreamingServices
            )
            .onAppear {
                model.homeDidAppear()
            }
            .onDisappear {
                model.homeDidDisappear()
            }
            .navigationTitle("Home")
            .navigationDestination(for: HomeDecisionRoute.self) { route in
                movieDetail(movieID: route.movieID)
            }
        }
        .onChange(of: navigationPath) { oldPath, newPath in
            guard !oldPath.isEmpty, newPath.isEmpty else { return }
            model.load()
        }
    }

    private func movieDetail(movieID: Int) -> some View {
        let dependencies = MovieDetailNavigationDependencies(
            getMovieDetail: getMovieDetail,
            getViewerMovieState: getViewerMovieState,
            updateViewerMovieState: updateViewerMovieState,
            checkAvailability: checkAvailability,
            preparePlaybackOptions: preparePlaybackOptions,
            viewerStateDidChange: model.reconcile,
            eligibilityDidChange: model.repair
        )
        return MovieDetailView(
            model: dependencies.makeViewModel(movieID: movieID),
            imagePipeline: imagePipeline,
            navigationDependencies: dependencies
        )
    }
}

@MainActor
private struct HomeDecisionContent: View {
    let state: HomeDecisionViewState
    let exhaustion: HomeDecisionExhaustionPresentation?
    let updateFeedback: String?
    let imagePipeline: ImagePipeline
    let updateViewerMovieState: any UpdateViewerMovieStateUseCase
    let viewerStateDidChange: @MainActor (DecisionViewerStateChange) -> Void
    let refresh: () -> Void
    let retry: () -> Void
    let reviewMyMovies: () -> Void
    let reviewStreamingServices: () -> Void

    var body: some View {
        content
            .overlay(alignment: .top) {
                if let updateFeedback {
                    Label(updateFeedback, systemImage: "checkmark.circle")
                        .font(.footnote.weight(.medium))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .background(.regularMaterial, in: .capsule)
                        .padding(.top, 8)
                        .allowsHitTesting(false)
                        .accessibilityIdentifier("home-recommendations-updated")
                }
            }
    }

    @ViewBuilder
    private var content: some View {
        switch state {
            case .idle, .loading:
                ProgressView("Finding tonight's picks...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            case let .loaded(set, isRefreshing, refreshError):
                HomeDecisionLoadedView(
                    set: set,
                    isRefreshing: isRefreshing,
                    refreshError: refreshError,
                    exhaustion: exhaustion,
                    imagePipeline: imagePipeline,
                    updateViewerMovieState: updateViewerMovieState,
                    viewerStateDidChange: viewerStateDidChange,
                    refresh: refresh,
                    reviewMyMovies: reviewMyMovies,
                    reviewStreamingServices: reviewStreamingServices
                )
            case let .empty(isRefreshing, refreshError):
                HomeDecisionEmptyView(
                    isRefreshing: isRefreshing,
                    refreshError: refreshError,
                    exhaustion: exhaustion,
                    refresh: refresh,
                    reviewMyMovies: reviewMyMovies,
                    reviewStreamingServices: reviewStreamingServices
                )
            case let .failure(message):
                EmptyStateView(
                    title: "Couldn't load tonight's picks",
                    message: message,
                    actionTitle: "Retry",
                    action: retry
                )
        }
    }
}

@MainActor
private struct HomeDecisionLoadedView: View {
    let set: HomeDecisionSetPresentationModel
    let isRefreshing: Bool
    let refreshError: String?
    let exhaustion: HomeDecisionExhaustionPresentation?
    let imagePipeline: ImagePipeline
    let updateViewerMovieState: any UpdateViewerMovieStateUseCase
    let viewerStateDidChange: @MainActor (DecisionViewerStateChange) -> Void
    let refresh: () -> Void
    let reviewMyMovies: () -> Void
    let reviewStreamingServices: () -> Void

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Three for Tonight")
                        .font(.title2.bold())
                    Text("A small set of movies included with your services in Spain.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                ForEach(set.items) { item in
                    HomeDecisionCard(
                        item: item,
                        imagePipeline: imagePipeline,
                        updateViewerMovieState: updateViewerMovieState,
                        viewerStateDidChange: viewerStateDidChange
                    )
                }

                if let exhaustion {
                    HomeDecisionExhaustionControls(
                        exhaustion: exhaustion,
                        isRefreshing: isRefreshing,
                        refresh: refresh,
                        reviewMyMovies: reviewMyMovies,
                        reviewStreamingServices: reviewStreamingServices
                    )
                } else {
                    HomeDecisionRefreshControls(
                        isRefreshing: isRefreshing,
                        refreshError: refreshError,
                        refresh: refresh
                    )
                }
            }
            .padding()
        }
    }
}

@MainActor
private struct HomeDecisionEmptyView: View {
    let isRefreshing: Bool
    let refreshError: String?
    let exhaustion: HomeDecisionExhaustionPresentation?
    let refresh: () -> Void
    let reviewMyMovies: () -> Void
    let reviewStreamingServices: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            if let exhaustion {
                ContentUnavailableView(
                    "No picks available right now",
                    systemImage: "film.stack",
                    description: Text(
                        "We've checked more movies and revisited older suggestions, but " +
                            "couldn't find an unseen match we can confidently recommend " +
                            "from your services."
                    )
                )
                HomeDecisionExhaustionControls(
                    exhaustion: exhaustion,
                    isRefreshing: isRefreshing,
                    refresh: refresh,
                    reviewMyMovies: reviewMyMovies,
                    reviewStreamingServices: reviewStreamingServices
                )
            } else {
                ContentUnavailableView(
                    "No picks available tonight",
                    systemImage: "film.stack",
                    description: Text(
                        "No unseen movie currently meets every taste and availability rule."
                    )
                )
                HomeDecisionRefreshControls(
                    isRefreshing: isRefreshing,
                    refreshError: refreshError,
                    refresh: refresh
                )
            }
        }
        .padding(.horizontal)
    }
}

@MainActor
private struct HomeDecisionExhaustionControls: View {
    let exhaustion: HomeDecisionExhaustionPresentation
    let isRefreshing: Bool
    let refresh: () -> Void
    let reviewMyMovies: () -> Void
    let reviewStreamingServices: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if exhaustion.recommendationCount == 3 {
                Text("No more picks available right now")
                    .font(.headline)
                Text(
                    "We couldn't find a different unseen match we can confidently recommend " +
                        "from your services. Your current picks are still available."
                )
                .font(.subheadline)
                .foregroundStyle(.secondary)
            } else if exhaustion.recommendationCount > 0 {
                Text(
                    "We found only \(exhaustion.recommendationCount) strong " +
                        "\(exhaustion.recommendationCount == 1 ? "match" : "matches") right now."
                )
                .font(.subheadline)
                .foregroundStyle(.secondary)
            }

            if exhaustion.canRefresh {
                Button("Give me three more", action: refresh)
                    .buttonStyle(.borderedProminent)
                    .disabled(isRefreshing)
            }
            if exhaustion.canRefresh {
                Button("Review My movies", action: reviewMyMovies)
                    .buttonStyle(.bordered)
            } else {
                Button("Review My movies", action: reviewMyMovies)
                    .buttonStyle(.borderedProminent)
            }
            Button("Review streaming services", action: reviewStreamingServices)
                .buttonStyle(.bordered)
        }
        .frame(maxWidth: .infinity)
    }
}

@MainActor
private struct HomeDecisionRefreshControls: View {
    let isRefreshing: Bool
    let refreshError: String?
    let refresh: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if let refreshError {
                Label(refreshError, systemImage: "exclamationmark.circle")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            Button(action: refresh) {
                HStack {
                    if isRefreshing {
                        ProgressView()
                            .controlSize(.small)
                            .accessibilityHidden(true)
                    }
                    Text(isRefreshing ? "Finding more..." : "Give me three more")
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .disabled(isRefreshing)
        }
        .frame(maxWidth: .infinity)
    }
}

struct HomeDecisionRoute: Hashable {
    let movieID: Int
}

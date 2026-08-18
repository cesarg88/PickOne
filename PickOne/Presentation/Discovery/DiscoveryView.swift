import SwiftUI

@MainActor
struct DiscoveryView: View {
    @ScaledMetric(relativeTo: .body) private var minimumCardWidth = 104.0

    let model: DiscoveryViewModel
    let getMovieDetail: GetMovieDetailUseCase
    let setMembership: SetWatchlistMembershipUseCase
    let setWatched: SetWatchedUseCase
    let checkAvailability: CheckMovieAvailabilityUseCase
    let preparePlaybackOptions: PreparePlaybackOptionsUseCase
    let imagePipeline: ImagePipeline
    var eligibilityDidChange: @MainActor (DecisionEligibilityChange) -> Void = { _ in }

    var body: some View {
        NavigationStack {
            Group {
                switch model.state {
                    case .idle, .loading:
                        ProgressView("Loading picks...")
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    case let .error(errorMessage):
                        EmptyStateView(
                            title: "Couldn't load movies",
                            message: errorMessage,
                            actionTitle: "Retry",
                            action: { Task { await model.loadInitial() } }
                        )
                    case let .loaded(data) where data.movies.isEmpty:
                        EmptyStateView(
                            title: "No movies yet",
                            message: "Try again in a moment.",
                            actionTitle: "Reload",
                            action: { Task { await model.loadInitial() } }
                        )
                    case let .loaded(data):
                        ScrollView {
                            LazyVGrid(columns: columns, spacing: 12) {
                                ForEach(data.movies) { movie in
                                    NavigationLink(value: DiscoveryRoute(movieID: movie.id)) {
                                        PosterCardView(movie: movie, pipeline: imagePipeline)
                                            .task {
                                                await model.loadNextPageIfNeeded(current: movie)
                                            }
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .padding(.horizontal)
                            .padding(.top, 12)

                            if data.isLoadingNextPage {
                                ProgressView()
                                    .padding()
                            }
                        }
                }
            }
            .navigationTitle("PickOne")
            .navigationDestination(for: DiscoveryRoute.self) { route in
                movieDetail(movieID: route.movieID)
            }
            .task {
                guard !AppConfiguration.isUITesting else { return }
                await model.loadInitial()
            }
        }
    }

    private var columns: [GridItem] {
        [
            GridItem(
                .adaptive(minimum: min(minimumCardWidth, 180), maximum: 180),
                spacing: 12
            ),
        ]
    }

    private func movieDetail(movieID: Int) -> some View {
        MovieDetailView(
            model: MovieDetailViewModel(
                movieId: movieID,
                getMovieDetail: getMovieDetail,
                setMembership: setMembership,
                setWatched: setWatched,
                checkAvailability: checkAvailability,
                preparePlaybackOptions: preparePlaybackOptions,
                eligibilityDidChange: eligibilityDidChange
            ),
            imagePipeline: imagePipeline,
            getMovieDetail: getMovieDetail,
            setMembership: setMembership,
            setWatched: setWatched,
            checkAvailability: checkAvailability,
            preparePlaybackOptions: preparePlaybackOptions
        )
    }
}

@MainActor
private struct PosterCardView: View {
    let movie: DiscoveryMovieItem
    let pipeline: ImagePipeline

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            RemoteImageView(
                url: movie.posterURL,
                loader: pipeline,
                contentMode: .fill,
                accessibilityLabel: movie.title
            )
            .aspectRatio(2 / 3, contentMode: .fit)
            .clipped()
            .clipShape(.rect(cornerRadius: 8))
            .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                Text(movie.title)
                    .font(.caption)
                    .lineLimit(2)
                    .foregroundStyle(.primary)

                if let year = movie.releaseYearText {
                    Text(year)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityHint("Open movie details")
    }
}

private struct DiscoveryRoute: Hashable {
    let movieID: Int
}

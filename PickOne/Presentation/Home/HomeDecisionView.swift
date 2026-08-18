import SwiftUI

@MainActor
struct HomeDecisionView: View {
    let model: HomeDecisionViewModel
    let getMovieDetail: GetMovieDetailUseCase
    let setMembership: SetWatchlistMembershipUseCase
    let setWatched: SetWatchedUseCase
    let checkAvailability: CheckMovieAvailabilityUseCase
    let preparePlaybackOptions: PreparePlaybackOptionsUseCase
    let imagePipeline: ImagePipeline

    @State private var navigationPath: [HomeDecisionRoute] = []

    var body: some View {
        NavigationStack(path: $navigationPath) {
            HomeDecisionContent(
                state: model.state,
                imagePipeline: imagePipeline,
                refresh: model.refresh,
                retry: model.load
            )
            .navigationTitle("Home")
            .navigationDestination(for: HomeDecisionRoute.self) { route in
                MovieDetailView(
                    model: MovieDetailViewModel(
                        movieId: route.movieID,
                        getMovieDetail: getMovieDetail,
                        setMembership: setMembership,
                        setWatched: setWatched,
                        checkAvailability: checkAvailability,
                        preparePlaybackOptions: preparePlaybackOptions,
                        eligibilityDidChange: model.repair
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
        .onChange(of: navigationPath) { oldPath, newPath in
            guard !oldPath.isEmpty, newPath.isEmpty else { return }
            model.load()
        }
    }
}

@MainActor
private struct HomeDecisionContent: View {
    let state: HomeDecisionViewState
    let imagePipeline: ImagePipeline
    let refresh: () -> Void
    let retry: () -> Void

    var body: some View {
        switch state {
            case .idle, .loading:
                ProgressView("Finding tonight's picks...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            case let .loaded(set, isRefreshing, refreshError):
                HomeDecisionLoadedView(
                    set: set,
                    isRefreshing: isRefreshing,
                    refreshError: refreshError,
                    imagePipeline: imagePipeline,
                    refresh: refresh
                )
            case let .empty(isRefreshing, refreshError):
                HomeDecisionEmptyView(
                    isRefreshing: isRefreshing,
                    refreshError: refreshError,
                    refresh: refresh
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
    let imagePipeline: ImagePipeline
    let refresh: () -> Void

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
                    NavigationLink(value: HomeDecisionRoute(movieID: item.id)) {
                        HomeDecisionCard(item: item, imagePipeline: imagePipeline)
                    }
                    .buttonStyle(.plain)
                }

                HomeDecisionRefreshControls(
                    isRefreshing: isRefreshing,
                    refreshError: refreshError,
                    refresh: refresh
                )
            }
            .padding()
        }
    }
}

@MainActor
private struct HomeDecisionEmptyView: View {
    let isRefreshing: Bool
    let refreshError: String?
    let refresh: () -> Void

    var body: some View {
        VStack(spacing: 20) {
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
            .padding(.horizontal)
        }
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

@MainActor
private struct HomeDecisionCard: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @ScaledMetric(relativeTo: .body) private var scaledPosterWidth = 112.0

    let item: HomeDecisionMovieItem
    let imagePipeline: ImagePipeline

    var body: some View {
        cardLayout {
            RemoteImageView(
                url: item.posterURL,
                loader: imagePipeline,
                contentMode: .fill,
                accessibilityLabel: item.title
            )
            .frame(width: posterWidth, height: posterWidth * 1.5)
            .clipped()
            .clipShape(.rect(cornerRadius: 10))
            .accessibilityHidden(true)

            content
        }
        .padding(14)
        .background(Color(.secondarySystemBackground))
        .clipShape(.rect(cornerRadius: 14))
        .accessibilityElement(children: .combine)
        .accessibilityHint("Open movie details")
    }

    private var cardLayout: AnyLayout {
        if dynamicTypeSize.isAccessibilitySize {
            AnyLayout(VStackLayout(alignment: .leading, spacing: 14))
        } else {
            AnyLayout(HStackLayout(alignment: .top, spacing: 14))
        }
    }

    private var posterWidth: CGFloat {
        min(scaledPosterWidth, 180)
    }

    private var content: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(item.role)
                .font(.caption.bold())
                .foregroundStyle(.tint)

            Text(item.title)
                .font(.headline)
                .foregroundStyle(.primary)

            if !item.details.isEmpty {
                Text(item.details)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Text(item.reason)
                .font(.subheadline)
                .foregroundStyle(.primary)

            HomeDecisionProviderRow(
                providers: item.providers,
                imagePipeline: imagePipeline
            )

            if item.isSaved {
                Label("Saved", systemImage: "bookmark.fill")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

@MainActor
private struct HomeDecisionProviderRow: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    let providers: [HomeDecisionProviderItem]
    let imagePipeline: ImagePipeline

    var body: some View {
        providerLayout {
            ForEach(providers) { provider in
                HomeDecisionProviderLogo(
                    provider: provider,
                    imagePipeline: imagePipeline
                )
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Included with \(providers.map(\.name).formatted())")
    }

    private var providerLayout: AnyLayout {
        if dynamicTypeSize.isAccessibilitySize {
            AnyLayout(VStackLayout(alignment: .leading, spacing: 8))
        } else {
            AnyLayout(HStackLayout(spacing: 8))
        }
    }
}

@MainActor
private struct HomeDecisionProviderLogo: View {
    @ScaledMetric(relativeTo: .caption) private var logoSize = 32.0

    let provider: HomeDecisionProviderItem
    let imagePipeline: ImagePipeline

    var body: some View {
        if let logoURL = provider.logoURL {
            RemoteImageView(
                url: logoURL,
                loader: imagePipeline,
                contentMode: .fit,
                accessibilityLabel: provider.name
            )
            .frame(width: min(logoSize, 48), height: min(logoSize, 48))
            .clipShape(.rect(cornerRadius: 6))
        } else {
            Text(provider.name)
                .font(.caption2)
                .lineLimit(1)
        }
    }
}

private struct HomeDecisionRoute: Hashable {
    let movieID: Int
}

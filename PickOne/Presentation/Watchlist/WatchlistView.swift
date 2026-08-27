//
//  WatchlistView.swift
//  PickOne
//
//  View for displaying and managing the user's watchlist
//

import SwiftUI

@MainActor
struct WatchlistView: View {
    let model: WatchlistViewModel
    let getMovieDetail: GetMovieDetailUseCase
    let setMembership: SetWatchlistMembershipUseCase
    let setWatched: SetWatchedUseCase
    let checkAvailability: CheckMovieAvailabilityUseCase
    let preparePlaybackOptions: PreparePlaybackOptionsUseCase
    let imagePipeline: ImagePipeline
    var eligibilityDidChange: @MainActor (DecisionEligibilityChange) -> Void = { _ in }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Filter picker
                Picker("Filter", selection: Binding(
                    get: { model.currentFilter },
                    set: { filter in Task { await model.applyFilter(filter) } }
                )) {
                    ForEach(WatchlistFilter.allCases) { filter in
                        Text(filter.rawValue).tag(filter)
                    }
                }
                .pickerStyle(.segmented)
                .padding()

                // Content
                Group {
                    switch model.state {
                        case .idle:
                            ProgressView()
                                .frame(maxWidth: .infinity, maxHeight: .infinity)

                        case let .empty(filter):
                            emptyView(for: filter)

                        case let .loaded(data):
                            watchlistContent(data: data)
                    }
                }
            }
            .navigationTitle("Watchlist")
            .navigationDestination(for: WatchlistRoute.self) { route in
                movieDetail(movieID: route.movieID)
            }
            .task {
                await model.load()
            }
            .alert(
                "Watchlist update failed",
                isPresented: Binding(
                    get: { model.actionErrorMessage != nil },
                    set: { if !$0 { model.actionErrorMessage = nil } }
                )
            ) {
                Button("OK") {
                    model.actionErrorMessage = nil
                }
            } message: {
                Text(model.actionErrorMessage ?? "Please try again.")
            }
        }
    }

    // MARK: - Subviews

    @ViewBuilder
    private func emptyView(for filter: WatchlistFilter) -> some View {
        let (title, message) = emptyStateContent(for: filter)
        VStack {
            EmptyStateView(
                title: title,
                message: message,
                actionTitle: nil,
                action: nil
            )
            .padding(.top, 40)

            Spacer()
        }
    }

    private func emptyStateContent(for filter: WatchlistFilter) -> (title: String, message: String) {
        switch filter {
            case .all:
                ("Your watchlist is empty", "Add movies from discovery or search to start building your list.")
            case .toWatch:
                ("Nothing to watch", "Movies you haven't watched yet will appear here.")
            case .watched:
                ("No watched movies", "Movies you've marked as watched will appear here.")
        }
    }

    private func watchlistContent(data: WatchlistPresentationModel) -> some View {
        List {
            ForEach(data.items) { item in
                NavigationLink(value: WatchlistRoute(movieID: item.id)) {
                    WatchlistRow(item: item, imagePipeline: imagePipeline)
                }
                .swipeActions(edge: .trailing, allowsFullSwipe: !item.isWatched) {
                    if !item.isWatched {
                        Button(role: .destructive) {
                            Task { await model.remove(movieId: item.id) }
                        } label: {
                            Label("Remove", systemImage: "trash")
                        }
                    }
                }
                .swipeActions(edge: .leading, allowsFullSwipe: true) {
                    Button {
                        Task { await model.toggleWatched(movieId: item.id) }
                    } label: {
                        if item.isWatched {
                            Label("To Watch", systemImage: "eye.slash")
                        } else {
                            Label("Watched", systemImage: "eye")
                        }
                    }
                    .tint(item.isWatched ? .orange : .green)
                }
            }
        }
        .listStyle(.plain)
    }

    private func movieDetail(movieID: Int) -> some View {
        let dependencies = MovieDetailNavigationDependencies(
            getMovieDetail: getMovieDetail,
            setMembership: setMembership,
            setWatched: setWatched,
            checkAvailability: checkAvailability,
            preparePlaybackOptions: preparePlaybackOptions,
            eligibilityDidChange: eligibilityDidChange
        )
        return MovieDetailView(
            model: dependencies.makeViewModel(movieID: movieID),
            imagePipeline: imagePipeline,
            navigationDependencies: dependencies
        )
    }
}

// MARK: - Row

@MainActor
private struct WatchlistRow: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @ScaledMetric(relativeTo: .body) private var scaledPosterWidth = 60.0

    let item: WatchlistItemPresentation
    let imagePipeline: ImagePipeline

    var body: some View {
        rowLayout {
            RemoteImageView(
                url: item.posterURL,
                loader: imagePipeline,
                contentMode: .fill,
                accessibilityLabel: item.title
            )
            .frame(width: posterWidth, height: posterWidth * 1.5)
            .clipped()
            .clipShape(.rect(cornerRadius: 6))
            .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 4) {
                Text(item.title)
                    .font(.headline)
                    .lineLimit(2)

                metadataLayout {
                    if let year = item.releaseYear {
                        Text(year)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }

                    if let rating = item.rating {
                        HStack(spacing: 2) {
                            Image(systemName: "star.fill")
                                .foregroundStyle(.yellow)
                                .font(.caption)
                                .accessibilityHidden(true)
                            Text(rating)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                HStack(spacing: 4) {
                    Image(systemName: item.isWatched ? "eye.fill" : "bookmark.fill")
                        .font(.caption)
                        .foregroundStyle(item.isWatched ? .green : .blue)
                        .accessibilityHidden(true)

                    Text(item.isWatched ? "Watched" : "To Watch")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Text("·")
                        .foregroundStyle(.secondary)

                    Text(item.addedDate)
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
    }

    private var rowLayout: AnyLayout {
        if dynamicTypeSize.isAccessibilitySize {
            AnyLayout(VStackLayout(alignment: .leading, spacing: 12))
        } else {
            AnyLayout(HStackLayout(spacing: 12))
        }
    }

    private var metadataLayout: AnyLayout {
        if dynamicTypeSize.isAccessibilitySize {
            AnyLayout(VStackLayout(alignment: .leading, spacing: 4))
        } else {
            AnyLayout(HStackLayout(spacing: 8))
        }
    }

    private var posterWidth: CGFloat {
        min(scaledPosterWidth, 90)
    }
}

private struct WatchlistRoute: Hashable {
    let movieID: Int
}

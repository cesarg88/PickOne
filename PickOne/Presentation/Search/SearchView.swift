//
//  SearchView.swift
//  PickOne
//
//  View for searching movies
//

import SwiftUI

@MainActor
struct SearchView: View {
    let model: SearchViewModel
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
                    case let .idle(history):
                        historyView(history: history)

                    case .searching:
                        ProgressView("Searching...")
                            .frame(maxWidth: .infinity, maxHeight: .infinity)

                    case let .results(data):
                        resultsView(data: data)

                    case let .empty(query):
                        EmptyStateView(
                            title: "No results",
                            message: "No movies found for \"\(query)\"",
                            actionTitle: "Clear",
                            action: { model.clearSearch() }
                        )

                    case let .error(message):
                        EmptyStateView(
                            title: "Search failed",
                            message: message,
                            actionTitle: "Try again",
                            action: { model.selectHistoryItem(model.query) }
                        )
                }
            }
            .navigationTitle("Search")
            .navigationDestination(for: SearchRoute.self) { route in
                movieDetail(movieID: route.movieID)
            }
            .searchable(
                text: Binding(
                    get: { model.query },
                    set: { model.onQueryChange($0) }
                ),
                prompt: "Movie titles"
            )
            .onAppear {
                model.loadHistory()
            }
        }
    }

    // MARK: - Subviews

    @ViewBuilder
    private func historyView(history: [String]) -> some View {
        if history.isEmpty {
            EmptyStateView(
                title: "Search for movies",
                message: "Find a movie by title",
                actionTitle: nil,
                action: nil
            )
        } else {
            List {
                Section {
                    ForEach(history, id: \.self) { query in
                        Button {
                            model.selectHistoryItem(query)
                        } label: {
                            HStack {
                                Image(systemName: "clock.arrow.circlepath")
                                    .foregroundStyle(.secondary)
                                    .accessibilityHidden(true)
                                Text(query)
                                    .foregroundStyle(.primary)
                                Spacer()
                            }
                        }
                        .buttonStyle(.plain)
                    }
                } header: {
                    HStack {
                        Text("Recent Searches")
                        Spacer()
                        Button("Clear") {
                            model.clearHistory()
                        }
                        .font(.caption)
                    }
                }
            }
            .listStyle(.insetGrouped)
        }
    }

    private func resultsView(data: SearchPresentationModel) -> some View {
        List {
            ForEach(data.items) { item in
                NavigationLink(value: SearchRoute(movieID: item.id)) {
                    SearchResultRow(item: item, imagePipeline: imagePipeline)
                        .task {
                            // Load next page when reaching last item
                            if item.id == data.items.last?.id {
                                await model.loadNextPage()
                            }
                        }
                }
            }

            if data.isLoadingNextPage {
                HStack {
                    Spacer()
                    ProgressView()
                    Spacer()
                }
                .listRowSeparator(.hidden)
            }
        }
        .listStyle(.plain)
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

// MARK: - Row

@MainActor
private struct SearchResultRow: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @ScaledMetric(relativeTo: .body) private var scaledPosterWidth = 60.0

    let item: SearchMovieItem
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

                    HStack(spacing: 2) {
                        Image(systemName: "star.fill")
                            .foregroundStyle(.yellow)
                            .font(.caption)
                            .accessibilityHidden(true)
                        Text(item.rating)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
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

private struct SearchRoute: Hashable {
    let movieID: Int
}

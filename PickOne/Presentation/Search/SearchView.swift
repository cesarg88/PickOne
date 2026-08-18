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
                NavigationLink {
                    MovieDetailView(
                        model: MovieDetailViewModel(
                            movieId: item.id,
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
                } label: {
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
}

// MARK: - Row

@MainActor
private struct SearchResultRow: View {
    let item: SearchMovieItem
    let imagePipeline: ImagePipeline

    var body: some View {
        HStack(spacing: 12) {
            // Poster
            RemoteImageView(
                url: item.posterURL,
                loader: imagePipeline,
                contentMode: .fill,
                accessibilityLabel: item.title
            )
            .frame(width: 60, height: 90)
            .clipped()
            .cornerRadius(6)

            // Info
            VStack(alignment: .leading, spacing: 4) {
                Text(item.title)
                    .font(.headline)
                    .lineLimit(2)

                HStack(spacing: 8) {
                    if let year = item.releaseYear {
                        Text(year)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }

                    HStack(spacing: 2) {
                        Image(systemName: "star.fill")
                            .foregroundStyle(.yellow)
                            .font(.caption)
                        Text(item.rating)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Spacer()
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
    }
}

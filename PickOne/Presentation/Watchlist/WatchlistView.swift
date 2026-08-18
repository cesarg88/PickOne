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
                    set: { model.applyFilter($0) }
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
            .onAppear {
                model.load()
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
                    WatchlistRow(item: item, imagePipeline: imagePipeline)
                }
                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                    Button(role: .destructive) {
                        model.remove(movieId: item.id)
                    } label: {
                        Label("Remove", systemImage: "trash")
                    }
                }
                .swipeActions(edge: .leading, allowsFullSwipe: true) {
                    Button {
                        model.toggleWatched(movieId: item.id)
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
}

// MARK: - Row

@MainActor
private struct WatchlistRow: View {
    let item: WatchlistItemPresentation
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

                HStack(spacing: 4) {
                    Image(systemName: item.isWatched ? "eye.fill" : "bookmark.fill")
                        .font(.caption)
                        .foregroundStyle(item.isWatched ? .green : .blue)

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

            Spacer()
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
    }
}

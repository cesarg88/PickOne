import SwiftUI

@MainActor
struct MovieDetailView: View {
    @Environment(\.openURL) private var openURL
    @State private var handoffTask: Task<Void, Never>?

    let model: MovieDetailViewModel
    let imagePipeline: ImagePipeline
    let getMovieDetail: GetMovieDetailUseCase
    let setMembership: SetWatchlistMembershipUseCase
    let setWatched: SetWatchedUseCase
    let checkAvailability: CheckMovieAvailabilityUseCase
    let preparePlaybackOptions: PreparePlaybackOptionsUseCase

    var body: some View {
        ScrollView {
            switch model.state {
                case .idle, .loading:
                    ProgressView("Loading details...")
                        .frame(maxWidth: .infinity, minHeight: 200)
                case let .error(errorMessage):
                    EmptyStateView(
                        title: "Couldn't load details",
                        message: errorMessage,
                        actionTitle: "Retry",
                        action: { Task { await model.load() } }
                    )
                case let .loaded(data):
                    VStack(alignment: .leading, spacing: 16) {
                        RemoteImageView(
                            url: data.backdropURL,
                            loader: imagePipeline,
                            contentMode: .fill,
                            accessibilityLabel: data.title
                        )
                        .frame(height: 220)
                        .clipped()
                        .cornerRadius(12)

                        VStack(alignment: .leading, spacing: 8) {
                            Text(data.title)
                                .font(.title2)
                                .fontWeight(.semibold)

                            HStack(spacing: 12) {
                                if let year = data.releaseYear {
                                    Text(year)
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                }

                                if let runtime = data.runtimeText {
                                    Text(runtime)
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                }

                                HStack(spacing: 4) {
                                    Image(systemName: "star.fill")
                                        .font(.caption)
                                        .foregroundStyle(.yellow)
                                    Text(data.rating)
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }

                        // Watchlist Actions
                        WatchlistActionsView(
                            isInWatchlist: data.isInWatchlist,
                            isWatched: data.isWatched,
                            onToggleWatchlist: { model.toggleWatchlist() },
                            onToggleWatched: { model.toggleWatched() }
                        )

                        ExpandableText(
                            title: "Synopsis",
                            text: data.overview
                        )

                        CreditsSection(
                            directorName: data.directorName,
                            topCastNames: data.topCastNames,
                            isUnavailable: data.isCreditsUnavailable
                        )

                        AvailabilitySection(
                            state: model.availabilityState,
                            imagePipeline: imagePipeline,
                            onOpenPlaybackOptions: {
                                handoffTask?.cancel()
                                handoffTask = Task {
                                    if let url = await model.preparePlaybackOptions() {
                                        try? Task.checkCancellation()
                                        guard !Task.isCancelled else { return }
                                        openURL(url)
                                    }
                                }
                            }
                        )

                        if !data.similar.isEmpty || data.isSimilarUnavailable {
                            SimilarMoviesSection(
                                movies: data.similar,
                                pipeline: imagePipeline,
                                isUnavailable: data.isSimilarUnavailable,
                                getMovieDetail: getMovieDetail,
                                setMembership: setMembership,
                                setWatched: setWatched,
                                checkAvailability: checkAvailability,
                                preparePlaybackOptions: preparePlaybackOptions
                            )
                        }
                    }
                    .padding()
            }
        }
        .navigationTitle("Details")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await model.load()
        }
        .onDisappear {
            handoffTask?.cancel()
            handoffTask = nil
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

// MARK: - Availability

@MainActor
private struct AvailabilitySection: View {
    let state: MovieAvailabilityViewState
    let imagePipeline: ImagePipeline
    let onOpenPlaybackOptions: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(MovieAvailabilityViewState.title)
                .font(.headline)

            switch state {
                case .loading:
                    ProgressView()
                        .controlSize(.small)
                        .accessibilityLabel("Loading availability")
                case let .eligible(data):
                    providerLogos(data.providers)
                    Text(MovieAvailabilityViewState.attribution)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    if data.showsPlaybackOptionsAction {
                        Button(
                            MovieAvailabilityViewState.handoffTitle,
                            action: onOpenPlaybackOptions
                        )
                        .font(.footnote.weight(.semibold))
                    }
                case .ineligible:
                    Text(MovieAvailabilityViewState.ineligibleMessage)
                        .font(.subheadline)
                    Text(MovieAvailabilityViewState.attribution)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                case .unknown:
                    Text(MovieAvailabilityViewState.unknownMessage)
                        .font(.subheadline)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func providerLogos(
        _ providers: [AvailabilityProviderPresentationModel]
    ) -> some View {
        LazyVGrid(
            columns: [GridItem(.adaptive(minimum: 112), spacing: 12)],
            alignment: .leading,
            spacing: 10
        ) {
            ForEach(providers) { provider in
                ProviderLogoView(
                    provider: provider,
                    imagePipeline: imagePipeline
                )
            }
        }
    }
}

@MainActor
private struct ProviderLogoView: View {
    private enum Phase {
        case loading
        case loaded(Image)
        case fallback
    }

    let provider: AvailabilityProviderPresentationModel
    let imagePipeline: ImagePipeline
    @State private var phase: Phase = .loading

    var body: some View {
        Group {
            switch phase {
                case .loading:
                    ProgressView()
                        .controlSize(.small)
                case let .loaded(image):
                    image
                        .resizable()
                        .scaledToFit()
                case .fallback:
                    Text(provider.name)
                        .font(.footnote.weight(.semibold))
                        .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: 112, minHeight: 44, maxHeight: 44)
        .padding(.horizontal, 8)
        .background(Color(uiColor: .secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(provider.name)
        .task(id: provider.logoURL?.absoluteString ?? "") {
            await load()
        }
    }

    private func load() async {
        guard let logoURL = provider.logoURL else {
            phase = .fallback
            return
        }
        phase = .loading
        do {
            let image = try await imagePipeline.loadImage(from: logoURL)
            try Task.checkCancellation()
            phase = .loaded(Image(uiImage: image))
        } catch is CancellationError {
            return
        } catch {
            phase = .fallback
        }
    }
}

// MARK: - Watchlist Actions

@MainActor
private struct WatchlistActionsView: View {
    let isInWatchlist: Bool
    let isWatched: Bool
    let onToggleWatchlist: () -> Void
    let onToggleWatched: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Button {
                onToggleWatchlist()
            } label: {
                Label(
                    isInWatchlist ? "In Watchlist" : "Add to Watchlist",
                    systemImage: isInWatchlist ? "bookmark.fill" : "bookmark"
                )
            }
            .buttonStyle(.borderedProminent)
            .tint(isInWatchlist ? .green : .accentColor)

            if isInWatchlist {
                Button {
                    onToggleWatched()
                } label: {
                    Label(
                        isWatched ? "Watched" : "Mark Watched",
                        systemImage: isWatched ? "eye.fill" : "eye"
                    )
                }
                .buttonStyle(.bordered)
                .tint(isWatched ? .orange : nil)
            }
        }
    }
}

@MainActor
private struct CreditsSection: View {
    let directorName: String?
    let topCastNames: [String]
    let isUnavailable: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Cast & Crew")
                .font(.headline)

            if isUnavailable {
                Text("Credits are unavailable right now.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                if let directorName, !directorName.isEmpty {
                    HStack(spacing: 6) {
                        Text("Director:")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(directorName)
                            .font(.subheadline)
                    }
                }

                if !topCastNames.isEmpty {
                    Text("Top cast: \(topCastNames.joined(separator: ", "))")
                        .font(.subheadline)
                        .foregroundStyle(.primary)
                }
            }
        }
        .accessibilityElement(children: .combine)
    }
}

@MainActor
private struct ExpandableText: View {
    let title: String
    let text: String

    @State private var isExpanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.headline)

            Text(text.isEmpty ? "No synopsis available." : text)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .lineLimit(isExpanded ? nil : 4)

            if !text.isEmpty {
                Button(isExpanded ? "Show less" : "Read more") {
                    isExpanded.toggle()
                }
                .font(.caption)
            }
        }
        .accessibilityElement(children: .combine)
    }
}

@MainActor
private struct SimilarMoviesSection: View {
    let movies: [SimilarMovieItem]
    let pipeline: ImagePipeline
    let isUnavailable: Bool
    let getMovieDetail: GetMovieDetailUseCase
    let setMembership: SetWatchlistMembershipUseCase
    let setWatched: SetWatchedUseCase
    let checkAvailability: CheckMovieAvailabilityUseCase
    let preparePlaybackOptions: PreparePlaybackOptionsUseCase

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Similar Movies")
                .font(.headline)

            if isUnavailable {
                Text("Similar movies are unavailable right now.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 12) {
                    ForEach(movies) { movie in
                        NavigationLink {
                            MovieDetailView(
                                model: MovieDetailViewModel(
                                    movieId: movie.id,
                                    getMovieDetail: getMovieDetail,
                                    setMembership: setMembership,
                                    setWatched: setWatched,
                                    checkAvailability: checkAvailability,
                                    preparePlaybackOptions: preparePlaybackOptions
                                ),
                                imagePipeline: pipeline,
                                getMovieDetail: getMovieDetail,
                                setMembership: setMembership,
                                setWatched: setWatched,
                                checkAvailability: checkAvailability,
                                preparePlaybackOptions: preparePlaybackOptions
                            )
                        } label: {
                            VStack(alignment: .leading, spacing: 4) {
                                RemoteImageView(
                                    url: movie.posterURL,
                                    loader: pipeline,
                                    contentMode: .fill,
                                    accessibilityLabel: movie.title
                                )
                                .frame(width: 100, height: 150)
                                .clipped()
                                .cornerRadius(8)

                                Text(movie.title)
                                    .font(.caption2)
                                    .lineLimit(2)
                                    .frame(width: 100, alignment: .leading)
                            }
                            .accessibilityElement(children: .combine)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }
}

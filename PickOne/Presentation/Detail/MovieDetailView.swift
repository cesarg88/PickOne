import SwiftUI

struct MovieDetailView: View {
    let model: MovieDetailViewModel
    let imagePipeline: ImagePipeline
    let getMovieDetail: GetMovieDetailUseCase
    let setMembership: SetWatchlistMembershipUseCase?
    let setWatched: SetWatchedUseCase?
    
    /// Convenience initializer for backwards compatibility
    init(
        model: MovieDetailViewModel,
        imagePipeline: ImagePipeline,
        getMovieDetail: GetMovieDetailUseCase
    ) {
        self.model = model
        self.imagePipeline = imagePipeline
        self.getMovieDetail = getMovieDetail
        self.setMembership = nil
        self.setWatched = nil
    }
    
    /// Full initializer with watchlist support
    init(
        model: MovieDetailViewModel,
        imagePipeline: ImagePipeline,
        getMovieDetail: GetMovieDetailUseCase,
        setMembership: SetWatchlistMembershipUseCase?,
        setWatched: SetWatchedUseCase?
    ) {
        self.model = model
        self.imagePipeline = imagePipeline
        self.getMovieDetail = getMovieDetail
        self.setMembership = setMembership
        self.setWatched = setWatched
    }
    
    var body: some View {
        ScrollView {
            switch model.state {
            case .idle, .loading:
                ProgressView("Loading details...")
                    .frame(maxWidth: .infinity, minHeight: 200)
            case .error(let errorMessage):
                EmptyStateView(
                    title: "Couldn't load details",
                    message: errorMessage,
                    actionTitle: "Retry",
                    action: { Task { await model.load() } }
                )
            case .loaded(let data):
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
                    
                    if !data.similar.isEmpty || data.isSimilarUnavailable {
                        SimilarMoviesSection(
                            movies: data.similar,
                            pipeline: imagePipeline,
                            isUnavailable: data.isSimilarUnavailable,
                            getMovieDetail: getMovieDetail,
                            setMembership: setMembership,
                            setWatched: setWatched
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
    }
}

// MARK: - Watchlist Actions

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

private struct SimilarMoviesSection: View {
    let movies: [SimilarMovieItem]
    let pipeline: ImagePipeline
    let isUnavailable: Bool
    let getMovieDetail: GetMovieDetailUseCase
    let setMembership: SetWatchlistMembershipUseCase?
    let setWatched: SetWatchedUseCase?
    
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
                                    setWatched: setWatched
                                ),
                                imagePipeline: pipeline,
                                getMovieDetail: getMovieDetail,
                                setMembership: setMembership,
                                setWatched: setWatched
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

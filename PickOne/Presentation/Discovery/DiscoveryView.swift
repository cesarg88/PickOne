import SwiftUI

@MainActor
struct DiscoveryView: View {
    let model: DiscoveryViewModel
    let getMovieDetail: GetMovieDetailUseCase
    let setMembership: SetWatchlistMembershipUseCase
    let setWatched: SetWatchedUseCase
    let checkAvailability: CheckMovieAvailabilityUseCase
    let preparePlaybackOptions: PreparePlaybackOptionsUseCase
    let imagePipeline: ImagePipeline
    @State private var isShowingAbout = false
    
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 12), count: 3)
    
    var body: some View {
        NavigationStack {
            Group {
                switch model.state {
                case .idle, .loading:
                    ProgressView("Loading picks...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                case .error(let errorMessage):
                    EmptyStateView(
                        title: "Couldn't load movies",
                        message: errorMessage,
                        actionTitle: "Retry",
                        action: { Task { await model.loadInitial() } }
                    )
                case .loaded(let data) where data.movies.isEmpty:
                    EmptyStateView(
                        title: "No movies yet",
                        message: "Try again in a moment.",
                        actionTitle: "Reload",
                        action: { Task { await model.loadInitial() } }
                    )
                case .loaded(let data):
                    ScrollView {
                        LazyVGrid(columns: columns, spacing: 12) {
                            ForEach(data.movies) { movie in
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
                                        imagePipeline: imagePipeline,
                                        getMovieDetail: getMovieDetail,
                                        setMembership: setMembership,
                                        setWatched: setWatched,
                                        checkAvailability: checkAvailability,
                                        preparePlaybackOptions: preparePlaybackOptions
                                    )
                                } label: {
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
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        isShowingAbout = true
                    } label: {
                        Label("About", systemImage: "info.circle")
                    }
                }
            }
            .sheet(isPresented: $isShowingAbout) {
                AboutView()
            }
            .task {
                guard !AppConfiguration.isUITesting else { return }
                await model.loadInitial()
            }
        }
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
            .frame(height: 170)
            .clipped()
            .cornerRadius(8)
            
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

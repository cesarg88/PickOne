import SwiftUI

struct DiscoveryView: View {
    let model: DiscoveryModel
    let getMovieDetail: GetMovieDetailUseCase
    let imagePipeline: ImagePipeline
    
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 12), count: 3)
    
    var body: some View {
        NavigationStack {
            Group {
                if model.isLoading && model.snapshot.movies.isEmpty {
                    ProgressView("Loading picks...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let errorMessage = model.errorMessage {
                    EmptyStateView(
                        title: "Couldn't load movies",
                        message: errorMessage,
                        actionTitle: "Retry",
                        action: { Task { await model.loadInitial() } }
                    )
                } else if model.snapshot.movies.isEmpty {
                    EmptyStateView(
                        title: "No movies yet",
                        message: "Try again in a moment.",
                        actionTitle: "Reload",
                        action: { Task { await model.loadInitial() } }
                    )
                } else {
                    ScrollView {
                        LazyVGrid(columns: columns, spacing: 12) {
                            ForEach(model.snapshot.movies) { movie in
                                NavigationLink {
                                    MovieDetailView(
                                        model: MovieDetailModel(
                                            movieId: movie.id,
                                            getMovieDetail: getMovieDetail
                                        ),
                                        imagePipeline: imagePipeline
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
                        
                        if model.isLoadingNextPage {
                            ProgressView()
                                .padding()
                        }
                    }
                }
            }
            .navigationTitle("PickOne")
            .task {
                await model.loadInitial()
            }
        }
    }
}

private struct PosterCardView: View {
    let movie: MovieSummary
    let pipeline: ImagePipeline
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            RemoteImageView(
                url: ImageURLBuilder.posterURL(path: movie.posterPath, size: .posterMedium),
                pipeline: pipeline,
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
                
                if let year = movie.releaseYear {
                    Text(String(year))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityHint("Open movie details")
    }
}


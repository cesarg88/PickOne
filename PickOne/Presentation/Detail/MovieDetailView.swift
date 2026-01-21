import SwiftUI

struct MovieDetailView: View {
    let model: MovieDetailModel
    let imagePipeline: ImagePipeline
    
    var body: some View {
        ScrollView {
            if model.isLoading && model.snapshot == nil {
                ProgressView("Loading details...")
                    .frame(maxWidth: .infinity, minHeight: 200)
            } else if let errorMessage = model.errorMessage {
                EmptyStateView(
                    title: "Couldn't load details",
                    message: errorMessage,
                    actionTitle: "Retry",
                    action: { Task { await model.load() } }
                )
            } else if let snapshot = model.snapshot {
                VStack(alignment: .leading, spacing: 16) {
                    RemoteImageView(
                        url: ImageURLBuilder.backdropURL(path: snapshot.movie.backdropPath, size: .backdropLarge),
                        pipeline: imagePipeline,
                        contentMode: .fill,
                        accessibilityLabel: snapshot.movie.title
                    )
                    .frame(height: 220)
                    .clipped()
                    .cornerRadius(12)
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text(snapshot.movie.title)
                            .font(.title2)
                            .fontWeight(.semibold)
                        
                        HStack(spacing: 12) {
                            if let year = snapshot.movie.releaseYear {
                                Text(String(year))
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                            
                            if let runtime = snapshot.movie.runtimeFormatted {
                                Text(runtime)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                            
                            HStack(spacing: 4) {
                                Image(systemName: "star.fill")
                                    .font(.caption)
                                    .foregroundStyle(.yellow)
                                Text(String(format: "%.1f", snapshot.movie.rating))
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    
                    ExpandableText(
                        title: "Synopsis",
                        text: snapshot.movie.overview
                    )
                    
                    if !snapshot.similar.isEmpty || snapshot.isSimilarUnavailable {
                        SimilarMoviesSection(
                            movies: snapshot.similar,
                            pipeline: imagePipeline,
                            isUnavailable: snapshot.isSimilarUnavailable
                        )
                    }
                    
                    HStack(spacing: 12) {
                        Button("Add to Watchlist") {}
                            .buttonStyle(.borderedProminent)
                            .disabled(true)
                        
                        Button("Mark as Watched") {}
                            .buttonStyle(.bordered)
                            .disabled(true)
                    }
                    .accessibilityHint("Available in a later milestone")
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
    let movies: [MovieSummary]
    let pipeline: ImagePipeline
    let isUnavailable: Bool
    
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
                        VStack(alignment: .leading, spacing: 4) {
                            RemoteImageView(
                                url: ImageURLBuilder.posterURL(path: movie.posterPath, size: .posterSmall),
                                pipeline: pipeline,
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
                }
            }
        }
    }
}

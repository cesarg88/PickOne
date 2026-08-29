import SwiftUI

@MainActor
struct MyMoviesView: View {
    let model: MyMoviesViewModel
    let imagePipeline: ImagePipeline
    let movieDetailDependencies: MovieDetailNavigationDependencies

    var body: some View {
        Group {
            switch model.state {
                case .loading:
                    ProgressView("Loading your movies...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                case .empty:
                    ContentUnavailableView(
                        "No movies yet",
                        systemImage: "film.stack",
                        description: Text(
                            "Your rated, watched, and not interested movies will appear here."
                        )
                    )
                case let .loaded(items):
                    List(items) { item in
                        NavigationLink {
                            MovieDetailView(
                                model: movieDetailDependencies.makeViewModel(
                                    movieID: item.id
                                ),
                                imagePipeline: imagePipeline,
                                navigationDependencies: movieDetailDependencies
                            )
                        } label: {
                            MyMoviesRow(
                                item: item,
                                imagePipeline: imagePipeline
                            )
                        }
                        .accessibilityIdentifier("my-movies-row-\(item.id)")
                    }
                    .listStyle(.plain)
                case let .failure(message):
                    EmptyStateView(
                        title: "Couldn't load your movies",
                        message: message,
                        actionTitle: "Retry",
                        action: { Task { await model.load() } }
                    )
            }
        }
        .navigationTitle("My movies")
        .task {
            await model.load()
        }
    }
}

@MainActor
private struct MyMoviesRow: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @ScaledMetric(relativeTo: .body) private var scaledPosterWidth = 60.0

    let item: MyMoviesItemPresentation
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

                if let releaseYear = item.releaseYear {
                    Text(releaseYear)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Text(item.stateLabel)
                    .font(.caption)
                    .foregroundStyle(.secondary)
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

    private var posterWidth: CGFloat {
        min(scaledPosterWidth, 90)
    }
}

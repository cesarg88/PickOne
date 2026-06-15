import SwiftUI

struct RecommendationView: View {
    let model: RecommendationViewModel
    let getMovieDetail: GetMovieDetailUseCase
    let setMembership: SetWatchlistMembershipUseCase
    let setWatched: SetWatchedUseCase
    let imagePipeline: ImagePipeline
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    promptComposer
                    
                    switch model.state {
                    case .idle:
                        idleView
                    case .loading:
                        ProgressView("Finding recommendations...")
                            .frame(maxWidth: .infinity, minHeight: 180)
                    case .loaded(let data):
                        loadedView(data: data)
                    case .empty(let query):
                        EmptyStateView(
                            title: "No recommendations",
                            message: "We couldn't find usable picks for \"\(query)\".",
                            actionTitle: "Try again",
                            action: { Task { await model.retry() } }
                        )
                        .frame(maxWidth: .infinity, minHeight: 180)
                    case .error(let query, let message):
                        EmptyStateView(
                            title: "Recommendation failed",
                            message: "\(message)\n\nPrompt: \"\(query)\"",
                            actionTitle: "Retry",
                            action: { Task { await model.retry() } }
                        )
                        .frame(maxWidth: .infinity, minHeight: 180)
                    }
                }
                .padding()
            }
            .navigationTitle("Ask PickOne")
        }
    }
    
    private var promptComposer: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Describe what you feel like watching")
                .font(.headline)
            
            Text("Try things like “smart sci-fi like Arrival” or “something funny but not dumb”.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            
            TextField(
                "A tense sci-fi movie with emotional depth",
                text: Bindable(model).query,
                axis: .vertical
            )
            .textFieldStyle(.roundedBorder)
            .lineLimit(2...4)
            .submitLabel(.search)
            .onSubmit {
                Task { await model.submit() }
            }
            
            HStack(spacing: 12) {
                Button {
                    Task { await model.submit() }
                } label: {
                    Label("Get Picks", systemImage: "sparkles")
                }
                .buttonStyle(.borderedProminent)
                
                if !model.query.isEmpty {
                    Button("Clear") {
                        model.clear()
                    }
                    .buttonStyle(.bordered)
                }
            }
        }
    }
    
    private var idleView: some View {
        VStack(alignment: .leading, spacing: 16) {
            EmptyStateView(
                title: "Need inspiration?",
                message: "Describe a mood, genre, or vibe and PickOne will return a short set of movie options.",
                actionTitle: nil,
                action: nil
            )
            
            VStack(alignment: .leading, spacing: 8) {
                Text("Examples")
                    .font(.headline)
                
                ForEach(samplePrompts, id: \.self) { prompt in
                    Button {
                        model.query = prompt
                        Task { await model.submit() }
                    } label: {
                        HStack(alignment: .top, spacing: 8) {
                            Image(systemName: "quote.bubble")
                                .foregroundStyle(.secondary)
                            Text(prompt)
                                .foregroundStyle(.primary)
                                .multilineTextAlignment(.leading)
                            Spacer()
                        }
                        .padding(12)
                        .background(Color(uiColor: .secondarySystemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
    
    private func loadedView(data: RecommendationPresentationModel) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 6) {
                Text(data.query)
                    .font(.headline)
                
                Text(data.explanation)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            
            LazyVStack(spacing: 16) {
                ForEach(data.items) { item in
                    RecommendationCard(
                        item: item,
                        getMovieDetail: getMovieDetail,
                        setMembership: setMembership,
                        setWatched: setWatched,
                        imagePipeline: imagePipeline
                    )
                }
            }
        }
    }
    
    private var samplePrompts: [String] {
        [
            "A smart sci-fi movie like Arrival",
            "Something funny but not dumb",
            "A thriller from the 90s"
        ]
    }
}

private struct RecommendationCard: View {
    let item: RecommendationMovieItem
    let getMovieDetail: GetMovieDetailUseCase
    let setMembership: SetWatchlistMembershipUseCase
    let setWatched: SetWatchedUseCase
    let imagePipeline: ImagePipeline
    
    @State private var didAddToWatchlist = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            NavigationLink {
                MovieDetailView(
                    model: MovieDetailViewModel(
                        movieId: item.id,
                        getMovieDetail: getMovieDetail,
                        setMembership: setMembership,
                        setWatched: setWatched
                    ),
                    imagePipeline: imagePipeline,
                    getMovieDetail: getMovieDetail,
                    setMembership: setMembership,
                    setWatched: setWatched
                )
            } label: {
                HStack(spacing: 12) {
                    RemoteImageView(
                        url: item.posterURL,
                        loader: imagePipeline,
                        contentMode: .fill,
                        accessibilityLabel: item.title
                    )
                    .frame(width: 72, height: 108)
                    .clipped()
                    .cornerRadius(8)
                    
                    VStack(alignment: .leading, spacing: 6) {
                        Text(item.title)
                            .font(.headline)
                            .foregroundStyle(.primary)
                            .multilineTextAlignment(.leading)
                        
                        HStack(spacing: 8) {
                            if let year = item.releaseYearText {
                                Text(year)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                            
                            HStack(spacing: 4) {
                                Image(systemName: "star.fill")
                                    .font(.caption)
                                    .foregroundStyle(.yellow)
                                Text(item.ratingText)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        
                        if let reason = item.reason, !reason.isEmpty {
                            Text(reason)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.leading)
                        }
                    }
                    
                    Spacer()
                }
            }
            .buttonStyle(.plain)
            
            HStack {
                Spacer()
                
                Button {
                    addToWatchlist()
                } label: {
                    Label(
                        didAddToWatchlist ? "Added" : "Add to Watchlist",
                        systemImage: didAddToWatchlist ? "checkmark.circle.fill" : "bookmark"
                    )
                }
                .buttonStyle(.bordered)
                .tint(didAddToWatchlist ? .green : .accentColor)
            }
        }
        .padding()
        .background(Color(uiColor: .secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
    
    private func addToWatchlist() {
        do {
            try setMembership.execute(movie: item.movieSummary, isInWatchlist: true)
            didAddToWatchlist = true
        } catch {
        }
    }
}

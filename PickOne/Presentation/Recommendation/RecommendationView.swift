import SwiftUI

@MainActor
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
                        loadingView
                    case .loaded(let data):
                        loadedView(data: data)
                    case .empty(let query):
                        VStack(alignment: .leading, spacing: 16) {
                            EmptyStateView(
                                title: "No usable picks yet",
                                message: "We couldn't resolve recommendations for \"\(query)\". Try being more specific about mood, genre, or era.",
                                actionTitle: "Try again",
                                action: { Task { await model.retry() } }
                            )
                            .frame(maxWidth: .infinity, minHeight: 180)
                            
                            suggestedPromptsSection(
                                title: "Try one of these prompts",
                                subtitle: "Start with one of these, or describe your own movie mood."
                            )
                        }
                    case .error(let query, let message):
                        VStack(alignment: .leading, spacing: 16) {
                            EmptyStateView(
                                title: "We couldn't finish that request",
                                message: "Prompt: \"\(query)\"\n\n\(message)",
                                actionTitle: "Retry",
                                action: { Task { await model.retry() } }
                            )
                            .frame(maxWidth: .infinity, minHeight: 180)
                            
                            suggestedPromptsSection(
                                title: "Need a quick reset?",
                                subtitle: "Start from a prompt that already matches the current recommendation catalog."
                            )
                        }
                    }
                }
                .padding()
            }
            .navigationTitle("Ask PickOne")
        }
    }
    
    private var promptComposer: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Describe what you feel like watching")
                    .font(.headline)
                
                Text("Keep it simple: mood, genre, pace, decade, or a movie reference is enough.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            
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
                .disabled(model.canSubmit == false)
                
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
                message: "Describe a mood, genre, or vibe and PickOne will return a short list of movie options you can act on quickly.",
                actionTitle: nil,
                action: nil
            )
            .frame(maxWidth: .infinity, minHeight: 180)
            
            suggestedPromptsSection(
                title: "Starter prompts",
                subtitle: "Tap one to see how the recommendation flow behaves."
            )
        }
    }
    
    private var loadingView: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 12) {
                    ProgressView()
                    Text("Finding recommendations...")
                        .font(.headline)
                }
                
                Text("We’re resolving the best available matches from the current recommendation source.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
            .background(Color(uiColor: .secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 16))
            
            suggestedPromptsSection(
                title: "Good prompt ingredients",
                subtitle: "Mood, genre, era, or a reference title usually works best."
            )
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
            
            HStack(spacing: 8) {
                Label("\(data.items.count) picks", systemImage: "checkmark.seal")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.secondary)
                
                Text("Open any card for detail or save it to your watchlist.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .padding()
            .background(Color(uiColor: .secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 16))
            
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
    
    private func suggestedPromptsSection(
        title: String,
        subtitle: String
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            
            ForEach(samplePrompts, id: \.self) { prompt in
                Button {
                    Task { await model.submitSuggestedPrompt(prompt) }
                } label: {
                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: "sparkle.magnifyingglass")
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
                .disabled(model.isLoading)
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

@MainActor
private struct RecommendationCard: View {
    let item: RecommendationMovieItem
    let getMovieDetail: GetMovieDetailUseCase
    let setMembership: SetWatchlistMembershipUseCase
    let setWatched: SetWatchedUseCase
    let imagePipeline: ImagePipeline
    
    @State private var didAddToWatchlist = false
    @State private var actionErrorMessage: String?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Why it fits")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            
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
        .alert(
            "Couldn't update watchlist",
            isPresented: Binding(
                get: { actionErrorMessage != nil },
                set: { if !$0 { actionErrorMessage = nil } }
            )
        ) {
            Button("OK") {
                actionErrorMessage = nil
            }
        } message: {
            Text(actionErrorMessage ?? "Please try again.")
        }
    }
    
    private func addToWatchlist() {
        do {
            try setMembership.execute(movie: item.movieSummary, isInWatchlist: true)
            didAddToWatchlist = true
        } catch {
            actionErrorMessage = error.localizedDescription
        }
    }
}

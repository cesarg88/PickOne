import SwiftUI

@MainActor
struct MovieFeedbackSection: View {
    let state: MovieFeedbackViewState
    let retry: () -> Void
    let setReaction: (MovieReaction) -> Void
    let removeReaction: () -> Void
    let toggleWatched: () -> Void
    let toggleNotInterested: () -> Void
    let toggleWatchlist: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Your feedback")
                .font(.headline)

            switch state {
                case .loading:
                    ProgressView("Loading your feedback...")
                        .controlSize(.small)
                        .accessibilityIdentifier("movie-feedback-loading")
                case let .failure(message):
                    Text(message)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Button("Retry", action: retry)
                        .accessibilityIdentifier("movie-feedback-retry")
                case let .loaded(model, isSaving, canSubmit):
                    MovieFeedbackControls(
                        model: model,
                        isSaving: isSaving,
                        canSubmit: canSubmit,
                        setReaction: setReaction,
                        removeReaction: removeReaction,
                        toggleWatched: toggleWatched,
                        toggleNotInterested: toggleNotInterested,
                        toggleWatchlist: toggleWatchlist
                    )
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Movie feedback")
        .accessibilityIdentifier("movie-feedback-section")
    }
}

@MainActor
private struct MovieFeedbackControls: View {
    @ScaledMetric(relativeTo: .body) private var minimumReactionWidth = 138.0

    let model: MovieFeedbackPresentationModel
    let isSaving: Bool
    let canSubmit: Bool
    let setReaction: (MovieReaction) -> Void
    let removeReaction: () -> Void
    let toggleWatched: () -> Void
    let toggleNotInterested: () -> Void
    let toggleWatchlist: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            LazyVGrid(
                columns: [GridItem(
                    .adaptive(minimum: minimumReactionWidth),
                    alignment: .leading
                )],
                alignment: .leading,
                spacing: 8
            ) {
                ForEach(MovieReaction.allCases, id: \.rawValue) { reaction in
                    MovieReactionButton(
                        reaction: reaction,
                        isSelected: model.reaction == reaction,
                        action: { setReaction(reaction) }
                    )
                }
            }

            if model.reaction != nil {
                Button("Remove rating", action: removeReaction)
                    .buttonStyle(.bordered)
                    .accessibilityIdentifier("movie-feedback-remove-reaction")
            }

            Button(action: toggleWatched) {
                Label(
                    model.isWatched ? "Mark unwatched" : "Mark watched",
                    systemImage: model.isWatched ? "eye.slash" : "eye"
                )
            }
            .buttonStyle(.bordered)
            .accessibilityIdentifier("movie-feedback-watched")

            if !model.isWatched {
                Divider()

                Button(action: toggleNotInterested) {
                    Label(
                        model.isNotInterested ? "Undo Not interested" : "Not interested",
                        systemImage: model.isNotInterested ? "hand.thumbsdown.fill" : "hand.thumbsdown"
                    )
                }
                .buttonStyle(.bordered)
                .tint(model.isNotInterested ? .orange : nil)
                .accessibilityAddTraits(model.isNotInterested ? .isSelected : [])
                .accessibilityIdentifier("movie-feedback-not-interested")

                Button(action: toggleWatchlist) {
                    Label(
                        model.isInWatchlist ? "Remove from Watchlist" : "Add to Watchlist",
                        systemImage: model.isInWatchlist ? "bookmark.fill" : "bookmark"
                    )
                }
                .buttonStyle(.bordered)
                .tint(model.isInWatchlist ? .green : nil)
                .accessibilityAddTraits(model.isInWatchlist ? .isSelected : [])
                .accessibilityIdentifier("movie-feedback-watchlist")
            }

            if isSaving {
                ProgressView("Saving...")
                    .controlSize(.small)
                    .accessibilityIdentifier("movie-feedback-saving")
            } else if !canSubmit {
                Text("Feedback controls are unavailable until movie details can be loaded.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .disabled(isSaving || !canSubmit)
    }
}

@MainActor
private struct MovieReactionButton: View {
    let reaction: MovieReaction
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label(
                reaction.feedbackTitle,
                systemImage: isSelected ? "checkmark.circle.fill" : "circle"
            )
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .buttonStyle(.bordered)
        .tint(isSelected ? .accentColor : nil)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .accessibilityIdentifier("movie-feedback-reaction-\(reaction.rawValue)")
    }
}

private extension MovieReaction {
    var feedbackTitle: String {
        switch self {
            case .loveIt: "Love it"
            case .likeIt: "Like it"
            case .itWasOkay: "It was okay"
            case .didNotLikeIt: "Didn't like it"
        }
    }
}

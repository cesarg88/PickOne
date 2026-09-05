import SwiftUI

@MainActor
struct HomeDecisionCard: View {
    @State private var quickFeedbackTask: Task<Void, Never>?
    @State private var quickFeedbackModel: HomeQuickFeedbackViewModel

    let item: HomeDecisionMovieItem
    let imagePipeline: ImagePipeline

    init(
        item: HomeDecisionMovieItem,
        imagePipeline: ImagePipeline,
        updateViewerMovieState: any UpdateViewerMovieStateUseCase,
        viewerStateDidChange: @escaping @MainActor (DecisionViewerStateChange) -> Void
    ) {
        self.item = item
        self.imagePipeline = imagePipeline
        _quickFeedbackModel = State(initialValue: HomeQuickFeedbackViewModel(
            movieID: item.id,
            metadata: item.feedbackMetadata,
            updateViewerMovieState: updateViewerMovieState,
            viewerStateDidChange: viewerStateDidChange
        ))
    }

    var body: some View {
        if quickFeedbackModel.state != .submitted {
            HStack(alignment: .top, spacing: 8) {
                NavigationLink(value: HomeDecisionRoute(movieID: item.id)) {
                    HomeDecisionCardContent(
                        item: item,
                        imagePipeline: imagePipeline
                    )
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("home-recommendation-\(item.id)")

                quickFeedbackControl
            }
            .padding(14)
            .background(Color(.secondarySystemBackground))
            .clipShape(.rect(cornerRadius: 14))
            .alert(
                "Couldn't save feedback",
                isPresented: Binding(
                    get: { quickFeedbackModel.state == .failed },
                    set: { _ in }
                )
            ) {
                Button("Try again") {
                    performQuickFeedback(quickFeedbackModel.retry)
                }
                Button("Cancel", role: .cancel) {
                    quickFeedbackModel.cancelFailure()
                }
            } message: {
                Text("Your feedback wasn't saved. Please try again.")
            }
            .onDisappear {
                quickFeedbackTask?.cancel()
                quickFeedbackTask = nil
            }
        }
    }

    @ViewBuilder
    private var quickFeedbackControl: some View {
        if quickFeedbackModel.state == .saving {
            ProgressView()
                .controlSize(.small)
                .frame(minWidth: 44, minHeight: 44)
                .accessibilityLabel("Saving feedback for \(item.title)")
                .accessibilityIdentifier("home-feedback-saving-\(item.id)")
        } else {
            Menu {
                Section("Rate") {
                    quickFeedbackButton(
                        "Love it",
                        systemImage: "heart.fill",
                        action: .assignReaction(.loveIt)
                    )
                    quickFeedbackButton(
                        "Like it",
                        systemImage: "hand.thumbsup.fill",
                        action: .assignReaction(.likeIt)
                    )
                    quickFeedbackButton(
                        "It was okay",
                        systemImage: "hand.thumbsup",
                        action: .assignReaction(.itWasOkay)
                    )
                    quickFeedbackButton(
                        "Didn't like it",
                        systemImage: "hand.thumbsdown.fill",
                        action: .assignReaction(.didNotLikeIt)
                    )
                }

                quickFeedbackButton(
                    "Already watched",
                    systemImage: "eye",
                    action: .markWatched
                )
                quickFeedbackButton(
                    "Not interested",
                    systemImage: "hand.thumbsdown",
                    action: .setNotInterested
                )
            } label: {
                Image(systemName: "ellipsis")
                    .frame(minWidth: 44, minHeight: 44)
                    .contentShape(.rect)
            }
            .accessibilityLabel("Feedback for \(item.title)")
            .accessibilityIdentifier("home-feedback-menu-\(item.id)")
        }
    }

    private func quickFeedbackButton(
        _ title: String,
        systemImage: String,
        action: ViewerMovieStateTransition.Action
    ) -> some View {
        Button {
            performQuickFeedback {
                await quickFeedbackModel.submit(action)
            }
        } label: {
            Label(title, systemImage: systemImage)
        }
        .accessibilityIdentifier("home-feedback-\(item.id)-\(action.accessibilityIdentifier)")
    }

    private func performQuickFeedback(
        _ action: @escaping @MainActor () async -> Void
    ) {
        quickFeedbackTask?.cancel()
        quickFeedbackTask = Task {
            await action()
        }
    }
}

@MainActor
private struct HomeDecisionCardContent: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @ScaledMetric(relativeTo: .body) private var scaledPosterWidth = 112.0

    let item: HomeDecisionMovieItem
    let imagePipeline: ImagePipeline

    var body: some View {
        cardLayout {
            RemoteImageView(
                url: item.posterURL,
                loader: imagePipeline,
                contentMode: .fill,
                accessibilityLabel: item.title
            )
            .frame(width: posterWidth, height: posterWidth * 1.5)
            .clipped()
            .clipShape(.rect(cornerRadius: 10))
            .accessibilityHidden(true)

            content
        }
        .accessibilityElement(children: .combine)
        .accessibilityHint("Open movie details")
    }

    private var cardLayout: AnyLayout {
        if dynamicTypeSize.isAccessibilitySize {
            AnyLayout(VStackLayout(alignment: .leading, spacing: 14))
        } else {
            AnyLayout(HStackLayout(alignment: .top, spacing: 14))
        }
    }

    private var posterWidth: CGFloat {
        min(scaledPosterWidth, 180)
    }

    private var content: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(item.role)
                .font(.caption.bold())
                .foregroundStyle(.tint)

            Text(item.title)
                .font(.headline)
                .foregroundStyle(.primary)

            if !item.details.isEmpty {
                Text(item.details)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Text(item.reason)
                .font(.subheadline)
                .foregroundStyle(.primary)

            HomeDecisionProviderRow(
                providers: item.providers,
                imagePipeline: imagePipeline
            )

            if item.isSaved {
                Label("Saved", systemImage: "bookmark.fill")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

@MainActor
private struct HomeDecisionProviderRow: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    let providers: [HomeDecisionProviderItem]
    let imagePipeline: ImagePipeline

    var body: some View {
        providerLayout {
            ForEach(providers) { provider in
                HomeDecisionProviderLogo(
                    provider: provider,
                    imagePipeline: imagePipeline
                )
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Included with \(providers.map(\.name).formatted())")
    }

    private var providerLayout: AnyLayout {
        if dynamicTypeSize.isAccessibilitySize {
            AnyLayout(VStackLayout(alignment: .leading, spacing: 8))
        } else {
            AnyLayout(HStackLayout(spacing: 8))
        }
    }
}

@MainActor
private struct HomeDecisionProviderLogo: View {
    @ScaledMetric(relativeTo: .caption) private var logoSize = 32.0

    let provider: HomeDecisionProviderItem
    let imagePipeline: ImagePipeline

    var body: some View {
        if let logoURL = provider.logoURL {
            RemoteImageView(
                url: logoURL,
                loader: imagePipeline,
                contentMode: .fit,
                accessibilityLabel: provider.name
            )
            .frame(width: min(logoSize, 48), height: min(logoSize, 48))
            .clipShape(.rect(cornerRadius: 6))
        } else {
            Text(provider.name)
                .font(.caption2)
                .lineLimit(1)
        }
    }
}

private extension ViewerMovieStateTransition.Action {
    var accessibilityIdentifier: String {
        switch self {
            case .assignReaction(.loveIt): "love-it"
            case .assignReaction(.likeIt): "like-it"
            case .assignReaction(.itWasOkay): "it-was-okay"
            case .assignReaction(.didNotLikeIt): "did-not-like-it"
            case .markWatched: "already-watched"
            case .setNotInterested: "not-interested"
            case .removeReaction,
                 .removeNotInterested,
                 .markUnwatched,
                 .saveToWatchlist,
                 .removeFromWatchlist:
                "unsupported"
        }
    }
}

import SwiftUI

@MainActor
struct HomeDecisionCard: View {
    @Environment(\.colorSchemeContrast) private var colorSchemeContrast
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    @State private var artwork: HomeDecisionArtwork = .surface
    @State private var quickFeedbackTask: Task<Void, Never>?
    @State private var quickFeedbackModel: HomeQuickFeedbackViewModel

    let isHero: Bool
    let pickModel: HomePickViewModel?
    let item: HomeDecisionMovieItem
    let imagePipeline: ImagePipeline
    let feedbackDidCommit: @MainActor () -> Void

    init(
        item: HomeDecisionMovieItem,
        isHero: Bool = false,
        pickModel: HomePickViewModel? = nil,
        imagePipeline: ImagePipeline,
        updateViewerMovieState: any UpdateViewerMovieStateUseCase,
        viewerStateDidChange: @escaping @MainActor (DecisionViewerStateChange) -> Void,
        feedbackDidCommit: @escaping @MainActor () -> Void = {}
    ) {
        self.isHero = isHero
        self.pickModel = pickModel
        self.item = item
        self.imagePipeline = imagePipeline
        self.feedbackDidCommit = feedbackDidCommit
        _quickFeedbackModel = State(initialValue: HomeQuickFeedbackViewModel(
            movieID: item.id,
            metadata: item.feedbackMetadata,
            updateViewerMovieState: updateViewerMovieState,
            viewerStateDidChange: viewerStateDidChange,
            alreadyWatchedRecorder: { pickModel?.alreadyWatchedRecorder(movieID: item.id) ?? {} }
        ))
    }

    var body: some View {
        VStack(spacing: 0) {
            if case let .poster(image) = artwork {
                NavigationLink(value: HomeDecisionRoute(movieID: item.id)) {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .frame(maxWidth: .infinity)
                        .frame(height: isHero ? 290 : 190)
                        .background(.black)
                        .overlay(HomeDecisionScrim.gradient)
                        .accessibilityHidden(true)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Open movie details for \(item.title)")
                .accessibilityIdentifier("home-poster-link-\(item.id)")
            }

            VStack(alignment: .leading, spacing: 12) {
                NavigationLink(value: HomeDecisionRoute(movieID: item.id)) {
                    HomeDecisionCardContent(
                        item: item,
                        imagePipeline: imagePipeline,
                        photoBackground: showsBackdrop,
                        isHero: isHero
                    )
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("home-recommendation-\(item.id)")

                if let pickModel {
                    HomePickControl(model: pickModel, movieID: item.id, title: item.title)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding(isHero ? 24 : 18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .frame(minHeight: showsBackdrop ? (isHero ? 380 : 240) : 0, alignment: .bottomLeading)
            .background {
                if showsBackdrop {
                    backdropBackground
                } else {
                    Color(.secondarySystemBackground)
                }
            }
            .foregroundStyle(showsBackdrop ? .white : .primary)
            .overlay(alignment: .topTrailing) {
                quickFeedbackControl
                    .foregroundStyle(showsBackdrop ? Color.white : Color.primary)
                    .padding(12)
            }
        }
        .clipShape(.rect(cornerRadius: 18))
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
        .task(id: artworkIdentity) {
            artwork = .surface
            let loaded = await HomeDecisionArtworkLoader.load(
                backdropURL: item.backdropURL,
                posterURL: item.posterURL,
                using: imagePipeline
            )
            guard !Task.isCancelled else { return }
            artwork = loaded
        }
    }

    private var artworkIdentity: String {
        "\(item.id)|\(item.backdropURL?.absoluteString ?? "")|\(item.posterURL?.absoluteString ?? "")"
    }

    private var showsBackdrop: Bool {
        artwork.isBackdrop && !reduceTransparency && colorSchemeContrast != .increased
    }

    private var backdropBackground: some View {
        GeometryReader { geometry in
            if case let .backdrop(image) = artwork {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: geometry.size.width, height: geometry.size.height)
                    .clipped()
                    .overlay(HomeDecisionScrim.gradient)
                    .accessibilityHidden(true)
            }
        }
    }

    @ViewBuilder
    private var quickFeedbackControl: some View {
        if quickFeedbackModel.state == .saving || quickFeedbackModel.state == .submitted {
            ProgressView()
                .controlSize(.small)
                .frame(minWidth: 44, minHeight: 44)
                .accessibilityLabel(quickFeedbackModel.state == .saving
                    ? Text("Saving feedback for \(item.title)")
                    : Text("Updating recommendations for \(item.title)"))
                .accessibilityIdentifier(quickFeedbackModel.state == .saving
                    ? "home-feedback-saving-\(item.id)" : "home-feedback-updating-\(item.id)")
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
            .buttonStyle(.glass)
            .buttonBorderShape(.circle)
            .accessibilityLabel("More options for \(item.title)")
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
            Label(LocalizedStringKey(title), systemImage: systemImage)
        }
        .accessibilityIdentifier("home-feedback-\(item.id)-\(action.accessibilityIdentifier)")
    }

    private func performQuickFeedback(
        _ action: @escaping @MainActor () async -> Void
    ) {
        quickFeedbackTask?.cancel()
        quickFeedbackTask = Task {
            await action()
            if quickFeedbackModel.state == .submitted {
                feedbackDidCommit()
            }
        }
    }
}

@MainActor
private struct HomeDecisionCardContent: View {
    let item: HomeDecisionMovieItem
    let imagePipeline: ImagePipeline
    let photoBackground: Bool
    let isHero: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(item.role)
                .font(.caption.bold())
                .padding(.trailing, 56)

            Spacer(minLength: photoBackground ? (isHero ? 88 : 20) : 0)

            Text(item.title)
                .font(isHero ? .system(.largeTitle, design: .serif) : .system(.title3, design: .serif))

            if !item.details.isEmpty {
                Text(item.details)
                    .font(.caption)
            }

            Text(item.reason)
                .font(.subheadline)

            HomeDecisionProviderRow(providers: item.providers, imagePipeline: imagePipeline)

            if item.isSaved {
                Label("Saved", systemImage: "bookmark.fill")
                    .font(.caption)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
        .accessibilityHint("Open movie details")
    }
}

@MainActor
private struct HomeDecisionProviderRow: View {
    let providers: [HomeDecisionProviderItem]
    let imagePipeline: ImagePipeline

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Included with your subscription")
                .font(.caption2)
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
}

@MainActor
private struct HomeDecisionProviderLogo: View {
    @ScaledMetric(relativeTo: .caption) private var logoSize = 32.0
    @State private var logo: UIImage?

    let provider: HomeDecisionProviderItem
    let imagePipeline: ImagePipeline

    var body: some View {
        HStack(spacing: 8) {
            if let logo {
                Image(uiImage: logo)
                    .resizable()
                    .scaledToFit()
                    .frame(width: min(logoSize, 48), height: min(logoSize, 48))
                    .clipShape(.rect(cornerRadius: 6))
                    .accessibilityHidden(true)
            }
            Text(provider.name)
                .font(.caption)
                .fixedSize(horizontal: false, vertical: true)
        }
        .task(id: provider.logoURL) {
            logo = nil
            guard let logoURL = provider.logoURL else { return }
            let loaded = try? await imagePipeline.loadImage(from: logoURL)
            guard !Task.isCancelled else { return }
            logo = loaded
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
            case .confirmPick, .confirmationReaction, .removeReaction,
                 .removeNotInterested,
                 .markUnwatched,
                 .saveToWatchlist,
                 .removeFromWatchlist:
                "unsupported"
        }
    }
}

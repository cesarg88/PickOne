import SwiftUI

@MainActor
struct HomeDecisionView: View {
    @Environment(\.locale) private var locale
    let model: HomeDecisionViewModel
    var confirmationModel: ViewingConfirmationViewModel?
    let getMovieDetail: GetMovieDetailUseCase
    let getViewerMovieState: GetViewerMovieStateUseCase
    let updateViewerMovieState: UpdateViewerMovieStateUseCase
    let checkAvailability: CheckMovieAvailabilityUseCase
    let preparePlaybackOptions: PreparePlaybackOptionsUseCase
    let imagePipeline: ImagePipeline
    let reviewMyMovies: () -> Void
    let reviewStreamingServices: () -> Void

    @State private var navigationPath: [HomeDecisionRoute] = []

    var body: some View {
        NavigationStack(path: $navigationPath) {
            VStack(spacing: 0) {
                if let confirmationModel { ViewingConfirmationView(model: confirmationModel) }
                HomeDecisionContent(
                    state: model.state,
                    pickModel: model.pickModel,
                    exhaustion: model.exhaustion,
                    updateFeedback: model.updateFeedback,
                    imagePipeline: imagePipeline,
                    updateViewerMovieState: updateViewerMovieState,
                    viewerStateDidChange: model.reconcile,
                    refresh: model.refresh,
                    retry: model.load,
                    reviewMyMovies: reviewMyMovies,
                    reviewStreamingServices: reviewStreamingServices
                )
            }
            .task(id: model.pickModel?.activeDecision?.id) { await confirmationModel?.refresh() }
            .onAppear {
                model.setContentLocale(locale)
                model.homeDidAppear()
                model.pickModel?.showHome()
            }
            .onDisappear {
                model.homeDidDisappear()
            }
            .onChange(of: locale.identifier) {
                model.setContentLocale(locale)
                model.pickModel?.dismissPickFeedback()
            }
            .navigationTitle("Home")
            .navigationDestination(for: HomeDecisionRoute.self) { route in
                movieDetail(movieID: route.movieID)
            }
        }
        .onChange(of: navigationPath) { oldPath, newPath in
            if let route = newPath.last { model.pickModel?.showRelatedDetail(movieID: route.movieID) }
            guard !oldPath.isEmpty, newPath.isEmpty else { return }
            model.load()
        }
    }

    private func movieDetail(movieID: Int) -> some View {
        let dependencies = MovieDetailNavigationDependencies(
            getMovieDetail: getMovieDetail,
            getViewerMovieState: getViewerMovieState,
            updateViewerMovieState: updateViewerMovieState,
            checkAvailability: checkAvailability,
            preparePlaybackOptions: preparePlaybackOptions,
            viewerStateDidChange: model.reconcile,
            eligibilityDidChange: model.repair
        )
        return HomeMovieDetailDestination(
            movieID: movieID,
            contentLocale: MovieContentLocale(effectiveLocale: locale),
            imagePipeline: imagePipeline,
            navigationDependencies: dependencies
        )
    }
}

@MainActor
private struct HomeMovieDetailDestination: View {
    @Environment(\.locale) private var locale
    @State private var model: MovieDetailViewModel
    let imagePipeline: ImagePipeline
    let navigationDependencies: MovieDetailNavigationDependencies

    init(
        movieID: Int,
        contentLocale: MovieContentLocale,
        imagePipeline: ImagePipeline,
        navigationDependencies: MovieDetailNavigationDependencies
    ) {
        _model = State(initialValue: navigationDependencies.makeViewModel(
            movieID: movieID,
            contentLocale: contentLocale
        ))
        self.imagePipeline = imagePipeline
        self.navigationDependencies = navigationDependencies
    }

    var body: some View {
        MovieDetailView(
            model: model,
            imagePipeline: imagePipeline,
            navigationDependencies: navigationDependencies
        )
        .onChange(of: locale.identifier) {
            Task {
                await model.changeContentLocale(MovieContentLocale(effectiveLocale: locale))
            }
        }
    }
}

@MainActor
private struct HomeDecisionContent: View {
    let state: HomeDecisionViewState
    let pickModel: HomePickViewModel?
    let exhaustion: HomeDecisionExhaustionPresentation?
    let updateFeedback: String?
    let imagePipeline: ImagePipeline
    let updateViewerMovieState: any UpdateViewerMovieStateUseCase
    let viewerStateDidChange: @MainActor (DecisionViewerStateChange) -> Void
    let refresh: () -> Void
    let retry: () -> Void
    let reviewMyMovies: () -> Void
    let reviewStreamingServices: () -> Void

    var body: some View {
        content
    }

    @ViewBuilder
    private var content: some View {
        switch state {
            case .idle, .loading:
                ProgressView("Finding tonight's picks...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            case let .loaded(set, isRefreshing, refreshError):
                HomeDecisionLoadedView(
                    set: set,
                    pickModel: pickModel,
                    updateFeedback: updateFeedback,
                    isRefreshing: isRefreshing,
                    refreshError: refreshError,
                    exhaustion: exhaustion,
                    imagePipeline: imagePipeline,
                    updateViewerMovieState: updateViewerMovieState,
                    viewerStateDidChange: viewerStateDidChange,
                    refresh: refresh,
                    reviewMyMovies: reviewMyMovies,
                    reviewStreamingServices: reviewStreamingServices
                )
            case let .empty(isRefreshing, refreshError):
                HomeDecisionEmptyView(
                    isRefreshing: isRefreshing,
                    refreshError: refreshError,
                    exhaustion: exhaustion,
                    refresh: refresh,
                    reviewMyMovies: reviewMyMovies,
                    reviewStreamingServices: reviewStreamingServices
                )
            case let .failure(message):
                EmptyStateView(
                    title: String(localized: "Couldn't load tonight's picks"),
                    message: message,
                    actionTitle: String(localized: "Retry"),
                    action: retry
                )
        }
    }
}

@MainActor
private struct HomeDecisionLoadedView: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @AccessibilityFocusState private var focusedSlot: HomeDecisionSlot?

    let set: HomeDecisionSetPresentationModel
    let pickModel: HomePickViewModel?
    let updateFeedback: String?
    let isRefreshing: Bool
    let refreshError: String?
    let exhaustion: HomeDecisionExhaustionPresentation?
    let imagePipeline: ImagePipeline
    let updateViewerMovieState: any UpdateViewerMovieStateUseCase
    let viewerStateDidChange: @MainActor (DecisionViewerStateChange) -> Void
    let refresh: () -> Void
    let reviewMyMovies: () -> Void
    let reviewStreamingServices: () -> Void

    var body: some View {
        GeometryReader { geometry in
            let availableWidth = max(0, min(geometry.size.width - 2 * horizontalPadding, 1280))
            let usesColumns = HomeDecisionLayout.usesColumns(
                availableWidth: availableWidth,
                dynamicTypeSize: dynamicTypeSize
            )

            ScrollView {
                // At most three eager cards retain their movie-ID state during reflow.
                VStack(alignment: .leading, spacing: 20) {
                    let layout = usesColumns
                        ? AnyLayout(HStackLayout(alignment: .top, spacing: 28))
                        : AnyLayout(VStackLayout(alignment: .leading, spacing: 16))
                    layout {
                        if let hero = set.items.first(where: { $0.decisionRole == .safeChoice })
                            ?? set.items.first
                        {
                            card(for: hero, isHero: true)
                                .frame(maxWidth: usesColumns ? availableWidth * 0.53 : .infinity)
                        }

                        if !alternatives.isEmpty {
                            VStack(alignment: .leading, spacing: 12) {
                                Text(alternativesHeading)
                                    .font(.system(.title2, design: .serif))
                                ForEach(alternatives, id: \.slot) { item in
                                    card(for: item, isHero: false)
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }

                    if let exhaustion {
                        HomeDecisionExhaustionControls(
                            exhaustion: exhaustion,
                            isRefreshing: isRefreshing,
                            refresh: refresh,
                            reviewMyMovies: reviewMyMovies,
                            reviewStreamingServices: reviewStreamingServices
                        )
                    } else {
                        HomeDecisionRefreshControls(
                            isRefreshing: isRefreshing,
                            refreshError: refreshError,
                            refresh: refresh
                        )
                    }
                }
                .frame(maxWidth: 1280, alignment: .leading)
                .padding(.horizontal, horizontalPadding)
                .padding(.vertical, 20)
                .frame(maxWidth: .infinity)
                .animation(HomeDecisionTransition.animation(reduceMotion: reduceMotion), value: set.items.map(\.id))
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            HomeDecisionStatusRegion(
                pickFeedback: pickModel?.pickFeedback,
                updateFeedback: updateFeedback
            )
        }
        .onChange(of: set.items.map(\.id)) { oldIDs, newIDs in
            guard oldIDs != newIDs, let slot = focusedSlot else { return }
            focusedSlot = nil
            Task { @MainActor in
                await Task.yield()
                focusedSlot = slot
            }
        }
    }

    private var horizontalPadding: CGFloat {
        dynamicTypeSize.isAccessibilitySize ? 16 : 24
    }

    private var alternatives: [HomeDecisionMovieItem] {
        guard let heroID = (set.items.first(where: { $0.decisionRole == .safeChoice })
            ?? set.items.first)?.id else { return [] }
        return set.items.filter { $0.id != heroID }
    }

    private var alternativesHeading: LocalizedStringKey {
        alternatives.count == 1 ? "Another path." : "Two other paths."
    }

    private func card(for item: HomeDecisionMovieItem, isHero: Bool) -> some View {
        HomeDecisionCard(
            item: item,
            isHero: isHero,
            pickModel: pickModel,
            imagePipeline: imagePipeline,
            updateViewerMovieState: updateViewerMovieState,
            viewerStateDidChange: viewerStateDidChange,
            feedbackDidCommit: { focusedSlot = item.slot }
        )
        .id(item.id)
        .accessibilityElement(children: .contain)
        .accessibilityFocused($focusedSlot, equals: item.slot)
    }
}

@MainActor
private struct HomeDecisionStatusRegion: View {
    @ScaledMetric(relativeTo: .subheadline) private var reservedHeight = 72.0

    let pickFeedback: HomePickAcknowledgement?
    let updateFeedback: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 8) {
                if let pickFeedback {
                    HomePickSuccessNotice(feedback: pickFeedback)
                }
                if let updateFeedback {
                    Label(updateFeedback, systemImage: "checkmark.circle")
                        .font(.footnote.weight(.medium))
                        .accessibilityIdentifier("home-recommendations-updated")
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .scrollIndicators(.hidden)
        .frame(height: reservedHeight)
        .background {
            if pickFeedback != nil || updateFeedback != nil {
                Rectangle().fill(.regularMaterial)
            }
        }
        .accessibilityAddTraits(.updatesFrequently)
    }
}

@MainActor
private struct HomeDecisionEmptyView: View {
    let isRefreshing: Bool
    let refreshError: String?
    let exhaustion: HomeDecisionExhaustionPresentation?
    let refresh: () -> Void
    let reviewMyMovies: () -> Void
    let reviewStreamingServices: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            if let exhaustion {
                ContentUnavailableView(
                    "No picks available right now",
                    systemImage: "film.stack",
                    description: Text(
                        """
                        We've checked more movies and revisited older suggestions, but \
                        couldn't find an unseen match we can confidently recommend from your services.
                        """
                    )
                )
                HomeDecisionExhaustionControls(
                    exhaustion: exhaustion,
                    isRefreshing: isRefreshing,
                    refresh: refresh,
                    reviewMyMovies: reviewMyMovies,
                    reviewStreamingServices: reviewStreamingServices
                )
            } else {
                ContentUnavailableView(
                    "No picks available tonight",
                    systemImage: "film.stack",
                    description: Text(
                        "No unseen movie currently meets every taste and availability rule."
                    )
                )
                HomeDecisionRefreshControls(
                    isRefreshing: isRefreshing,
                    refreshError: refreshError,
                    refresh: refresh
                )
            }
        }
        .padding(.horizontal)
    }
}

@MainActor
private struct HomeDecisionExhaustionControls: View {
    let exhaustion: HomeDecisionExhaustionPresentation
    let isRefreshing: Bool
    let refresh: () -> Void
    let reviewMyMovies: () -> Void
    let reviewStreamingServices: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if exhaustion.recommendationCount == 3 {
                Text("No more picks available right now")
                    .font(.headline)
                Text(
                    """
                    We couldn't find a different unseen match we can confidently recommend \
                    from your services. Your current picks are still available.
                    """
                )
                .font(.subheadline)
                .foregroundStyle(.secondary)
            } else if exhaustion.recommendationCount > 0 {
                Text(
                    "We found only \(exhaustion.recommendationCount) strong matches right now."
                )
                .font(.subheadline)
                .foregroundStyle(.secondary)
            }

            if exhaustion.canRefresh {
                Button("Give me three more", action: refresh)
                    .buttonStyle(.borderedProminent)
                    .disabled(isRefreshing)
            }
            if exhaustion.canRefresh {
                Button("Review My movies", action: reviewMyMovies)
                    .buttonStyle(.bordered)
            } else {
                Button("Review My movies", action: reviewMyMovies)
                    .buttonStyle(.borderedProminent)
            }
            Button("Review streaming services", action: reviewStreamingServices)
                .buttonStyle(.bordered)
        }
        .frame(maxWidth: .infinity)
    }
}

@MainActor
private struct HomeDecisionRefreshControls: View {
    let isRefreshing: Bool
    let refreshError: String?
    let refresh: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if let refreshError {
                Label(refreshError, systemImage: "exclamationmark.circle")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            Button(action: refresh) {
                HStack {
                    if isRefreshing {
                        ProgressView()
                            .controlSize(.small)
                            .accessibilityHidden(true)
                    }
                    Text(isRefreshing ? "Finding more..." : "Give me three more")
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .disabled(isRefreshing)
        }
        .frame(maxWidth: .infinity)
    }
}

struct HomeDecisionRoute: Hashable {
    let movieID: Int
}

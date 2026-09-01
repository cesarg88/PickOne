enum TrustedDecisionStateLoadError: Error, Equatable, Sendable {
    case profileUnavailable
    case viewerStateUnavailable
    case inputsChanged
}

struct TrustedDecisionState: Equatable, Sendable {
    let profile: ViewerProfile
    let viewerMovieState: ViewerMovieStateSnapshot

    var snapshotID: ViewerStateSnapshotID {
        viewerMovieState.id
    }

    var recommendationSuppressionEpochID: RecommendationSuppressionEpochID {
        viewerMovieState.recommendationSuppressionEpochID
    }

    var reactions: [Int: MovieReaction] {
        ViewerMovieStateProjections.reactions(from: viewerMovieState)
    }

    var recommendationExcludedMovieIDs: Set<Int> {
        ViewerMovieStateProjections.recommendationExcludedMovieIDs(
            from: viewerMovieState
        )
    }

    var savedUnwatchedMovieIDs: Set<Int> {
        Set(ViewerMovieStateProjections.watchlist(from: viewerMovieState).map(\.movieID))
    }
}

protocol TrustedDecisionStateLoading: Sendable {
    func load() async throws -> TrustedDecisionState
    func matches(snapshotID: ViewerStateSnapshotID) async -> Bool
}

struct LoadTrustedDecisionState: TrustedDecisionStateLoading, Sendable {
    private let viewerProfileRepository: any ViewerProfileRepository
    private let viewerMovieStateRepository: any ViewerMovieStateRepository

    init(
        viewerProfileRepository: any ViewerProfileRepository,
        viewerMovieStateRepository: any ViewerMovieStateRepository
    ) {
        self.viewerProfileRepository = viewerProfileRepository
        self.viewerMovieStateRepository = viewerMovieStateRepository
    }

    func load() async throws -> TrustedDecisionState {
        let snapshotBefore = try await loadViewerMovieState()
        guard case let .completed(profile, _) = await viewerProfileRepository.loadState() else {
            throw TrustedDecisionStateLoadError.profileUnavailable
        }
        let snapshotAfter = try await loadViewerMovieState()
        guard snapshotBefore.id == snapshotAfter.id else {
            throw TrustedDecisionStateLoadError.inputsChanged
        }
        return TrustedDecisionState(
            profile: profile,
            viewerMovieState: snapshotAfter
        )
    }

    func matches(snapshotID: ViewerStateSnapshotID) async -> Bool {
        guard let snapshot = try? await viewerMovieStateRepository.snapshot() else {
            return false
        }
        return snapshot.id == snapshotID
    }

    private func loadViewerMovieState() async throws -> ViewerMovieStateSnapshot {
        do {
            return try await viewerMovieStateRepository.snapshot()
        } catch {
            throw TrustedDecisionStateLoadError.viewerStateUnavailable
        }
    }
}

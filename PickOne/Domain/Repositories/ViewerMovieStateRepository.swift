protocol ViewerMovieStateRepository: Sendable {
    func loadState() async -> ViewerMovieStateLoadState
    func snapshot() async throws -> ViewerMovieStateSnapshot
    func state(movieID: Int) async throws -> ViewerMovieState?
    func apply(
        _ transition: ViewerMovieStateTransition,
        metadata: MovieFeedbackMetadata
    ) async throws -> ViewerMovieStateChange
}

enum ViewerMovieStateRepositoryError: Error, Equatable, Sendable {
    case invalidMovieID
    case invalidTransition(ViewerMovieStateTransitionError)
    case corruptData
    case unsupportedSchema
    case migrationFailure
    case quarantineFailure
    case encodingFailure
    case previousCopyFailure
    case replacementFailure
    case loadFailure
}

enum ViewerStateRecoveryNotice: Equatable, Sendable {
    case olderSnapshot
}

protocol ViewerStateRecoveryNoticeRepository: Sendable {
    func recoveryNotice() async -> ViewerStateRecoveryNotice?
}

protocol ViewerStateDestructiveRecoveryRepository: Sendable {
    func resetUnrecoverableViewerState() async throws
}

enum ViewerStateDestructiveRecoveryError: Error, Equatable, Sendable {
    case stateIsRecoverable
    case resetUnavailable
    case resetFailed
}

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

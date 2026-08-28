protocol GetViewerMovieStateUseCase: Sendable {
    func execute(movieID: Int) async throws -> ViewerMovieState?
}

final class GetViewerMovieState: GetViewerMovieStateUseCase, Sendable {
    private let repository: any ViewerMovieStateRepository

    init(repository: any ViewerMovieStateRepository) {
        self.repository = repository
    }

    func execute(movieID: Int) async throws -> ViewerMovieState? {
        try await repository.state(movieID: movieID)
    }
}

protocol UpdateViewerMovieStateUseCase: Sendable {
    func execute(
        transition: ViewerMovieStateTransition,
        metadata: MovieFeedbackMetadata
    ) async throws -> ViewerMovieStateChange
}

final class UpdateViewerMovieState: UpdateViewerMovieStateUseCase, Sendable {
    private let repository: any ViewerMovieStateRepository

    init(repository: any ViewerMovieStateRepository) {
        self.repository = repository
    }

    func execute(
        transition: ViewerMovieStateTransition,
        metadata: MovieFeedbackMetadata
    ) async throws -> ViewerMovieStateChange {
        try await repository.apply(transition, metadata: metadata)
    }
}

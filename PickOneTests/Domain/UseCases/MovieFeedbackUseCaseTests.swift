import Foundation
@testable import PickOne
import Testing

@Suite("Movie feedback use cases")
struct MovieFeedbackUseCaseTests {
    @Test("current state is loaded through the focused repository boundary")
    func currentStateLoadsFromRepository() async throws {
        let expected = try feedbackState()
        let repository = RecordingViewerMovieStateRepository(state: expected)
        let sut = GetViewerMovieState(repository: repository)

        let state = try await sut.execute(movieID: expected.movieID)

        #expect(state == expected)
        #expect(await repository.requestedMovieIDs == [expected.movieID])
    }

    @Test("validated transitions preserve Domain metadata and return the persisted change")
    func transitionReturnsPersistedChange() async throws {
        let state = try feedbackState()
        let transition = ViewerMovieStateTransition(
            movieID: state.movieID,
            action: .assignReaction(.loveIt)
        )
        let expected = ViewerMovieStateChange(
            state: state,
            impact: .tasteChanged,
            snapshotID: ViewerStateSnapshotID(rawValue: UUID())
        )
        let repository = RecordingViewerMovieStateRepository(
            state: state,
            change: expected
        )
        let sut = UpdateViewerMovieState(repository: repository)

        let change = try await sut.execute(
            transition: transition,
            metadata: state.displayMetadata
        )

        #expect(change == expected)
        #expect(await repository.appliedTransitions == [transition])
        #expect(await repository.appliedMetadata == [state.displayMetadata])
    }

    private func feedbackState() throws -> ViewerMovieState {
        try ViewerMovieState(
            movieID: 42,
            displayMetadata: MovieFeedbackMetadata(
                title: "Offline title",
                releaseYear: 2024,
                posterPath: "/offline.jpg"
            ),
            watchState: .watched,
            preference: .reaction(.likeIt),
            watchlistIntent: nil,
            stateChangedAt: Date(timeIntervalSince1970: 1_700_000_000)
        )
    }
}

private actor RecordingViewerMovieStateRepository: ViewerMovieStateRepository {
    let storedState: ViewerMovieState?
    let change: ViewerMovieStateChange?
    private(set) var requestedMovieIDs: [Int] = []
    private(set) var appliedTransitions: [ViewerMovieStateTransition] = []
    private(set) var appliedMetadata: [MovieFeedbackMetadata] = []

    init(
        state: ViewerMovieState?,
        change: ViewerMovieStateChange? = nil
    ) {
        storedState = state
        self.change = change
    }

    func loadState() -> ViewerMovieStateLoadState {
        .absent
    }

    func snapshot() throws -> ViewerMovieStateSnapshot {
        try ViewerMovieStateSnapshot(
            id: ViewerStateSnapshotID(rawValue: UUID()),
            states: storedState.map { [$0] } ?? []
        )
    }

    func state(movieID: Int) -> ViewerMovieState? {
        requestedMovieIDs.append(movieID)
        return storedState
    }

    func apply(
        _ transition: ViewerMovieStateTransition,
        metadata: MovieFeedbackMetadata
    ) throws -> ViewerMovieStateChange {
        appliedTransitions.append(transition)
        appliedMetadata.append(metadata)
        guard let change else {
            throw MovieFeedbackUseCaseTestError.missingChange
        }
        return change
    }
}

private enum MovieFeedbackUseCaseTestError: Error {
    case missingChange
}

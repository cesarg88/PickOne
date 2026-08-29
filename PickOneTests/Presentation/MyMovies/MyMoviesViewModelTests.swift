import Foundation
@testable import PickOne
import Testing

@MainActor
@Suite("MyMoviesViewModel")
struct MyMoviesViewModelTests {
    @Test("load publishes empty history")
    func loadPublishesEmpty() async {
        let useCase = MyMoviesUseCaseStub(states: [])
        let sut = MyMoviesViewModel(getMyMovies: useCase)

        await sut.load()

        #expect(sut.state == .empty)
    }

    @Test("load publishes mapped content")
    func loadPublishesContent() async throws {
        let movie = try historyState()
        let useCase = MyMoviesUseCaseStub(states: [movie])
        let sut = MyMoviesViewModel(getMyMovies: useCase)

        await sut.load()

        guard case let .loaded(items) = sut.state else {
            Issue.record("Expected loaded state")
            return
        }
        #expect(items.map(\.id) == [movie.movieID])
        #expect(items.first?.stateLabel == "Watched")
    }

    @Test("load failure is blocking and retryable")
    func loadFailureAndRetry() async throws {
        let useCase = MyMoviesUseCaseStub(error: .failed)
        let sut = MyMoviesViewModel(getMyMovies: useCase)

        await sut.load()

        #expect(sut.state == .failure("Your movies couldn't be loaded. Please try again."))

        try await useCase.setResult(states: [historyState()], error: nil)
        await sut.load()

        guard case let .loaded(items) = sut.state else {
            Issue.record("Expected retry to load content")
            return
        }
        #expect(items.count == 1)
    }

    private func historyState() throws -> ViewerMovieState {
        try ViewerMovieState(
            movieID: 42,
            displayMetadata: MovieFeedbackMetadata(
                title: "Offline title",
                releaseYear: nil,
                posterPath: nil
            ),
            watchState: .watched,
            preference: nil,
            watchlistIntent: nil,
            stateChangedAt: .distantPast
        )
    }
}

private actor MyMoviesUseCaseStub: GetMyMoviesUseCase {
    enum StubError: Error {
        case failed
    }

    private var states: [ViewerMovieState]
    private var error: StubError?

    init(
        states: [ViewerMovieState] = [],
        error: StubError? = nil
    ) {
        self.states = states
        self.error = error
    }

    func execute() async throws -> [ViewerMovieState] {
        if let error { throw error }
        return states
    }

    func setResult(
        states: [ViewerMovieState],
        error: StubError?
    ) {
        self.states = states
        self.error = error
    }
}

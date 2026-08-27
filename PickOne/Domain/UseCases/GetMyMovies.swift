protocol GetMyMoviesUseCase: Sendable {
    func execute() async throws -> [ViewerMovieState]
}

struct GetMyMovies: GetMyMoviesUseCase {
    private let repository: any ViewerMovieStateRepository

    init(repository: any ViewerMovieStateRepository) {
        self.repository = repository
    }

    func execute() async throws -> [ViewerMovieState] {
        try await ViewerMovieStateProjections.myMovies(from: repository.snapshot())
    }
}

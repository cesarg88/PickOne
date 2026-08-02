struct CalibrationMovieMetadata: Equatable, Sendable {
    let title: String
    let originalTitle: String
    let releaseYear: Int?
    let posterPath: String?
}

protocol GetCalibrationMovieMetadataUseCase: Sendable {
    func execute(movieID: Int) async throws -> CalibrationMovieMetadata
}

struct GetCalibrationMovieMetadata: GetCalibrationMovieMetadataUseCase {
    private let repository: MovieRepository

    init(repository: MovieRepository) {
        self.repository = repository
    }

    func execute(movieID: Int) async throws -> CalibrationMovieMetadata {
        let result = try await repository.getMovieDetail(
            id: movieID,
            policy: .returnCacheElseLoad
        )
        let movie = result.value
        return CalibrationMovieMetadata(
            title: movie.title,
            originalTitle: movie.originalTitle,
            releaseYear: movie.releaseYear,
            posterPath: movie.posterPath
        )
    }
}

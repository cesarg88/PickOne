protocol GetCalibrationMovieMetadataUseCase: Sendable {
    func execute(movieID: Int) async throws -> CalibrationMovieMetadata
}

struct GetCalibrationMovieMetadata: GetCalibrationMovieMetadataUseCase {
    private let repository: CalibrationMovieMetadataRepository

    init(repository: CalibrationMovieMetadataRepository) {
        self.repository = repository
    }

    func execute(movieID: Int) async throws -> CalibrationMovieMetadata {
        try await repository.getMetadata(movieID: movieID)
    }
}

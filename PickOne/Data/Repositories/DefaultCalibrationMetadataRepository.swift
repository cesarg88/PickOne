final class DefaultCalibrationMetadataRepository: CalibrationMovieMetadataRepository {
    private let client: CalibrationMovieMetadataClient

    init(client: CalibrationMovieMetadataClient) {
        self.client = client
    }

    func getMetadata(movieID: Int) async throws -> CalibrationMovieMetadata {
        let movie = try await MovieMapper.mapDetail(from: client.getMovieDetail(id: movieID))
        return CalibrationMovieMetadata(
            title: movie.title,
            originalTitle: movie.originalTitle,
            releaseYear: movie.releaseYear,
            posterPath: movie.posterPath
        )
    }
}

struct CalibrationMovieMetadata: Equatable, Sendable {
    let title: String
    let originalTitle: String
    let releaseYear: Int?
    let posterPath: String?
}

protocol CalibrationMovieMetadataRepository: Sendable {
    func getMetadata(movieID: Int) async throws -> CalibrationMovieMetadata
}

import Foundation

protocol GetMovieDetailUseCase {
    func execute(id: Int, policy: CachePolicy) async throws -> CacheResult<MovieDetailSnapshot>
}

final class GetMovieDetail: GetMovieDetailUseCase {
    private let repository: MovieRepository
    
    init(repository: MovieRepository) {
        self.repository = repository
    }
    
    func execute(id: Int, policy: CachePolicy) async throws -> CacheResult<MovieDetailSnapshot> {
        let detailResult = try await repository.getMovieDetail(id: id, policy: policy)
        let similarResult = try await repository.getSimilarMovies(id: id, page: 1, policy: policy)
        let creditsResult = try await repository.getCredits(id: id, policy: policy)
        
        let snapshot = MovieDetailSnapshot(
            movie: detailResult.value,
            similar: similarResult.value.movies,
            isInWatchlist: false,
            isWatched: false,
            director: creditsResult.value.director,
            topCast: creditsResult.value.topCast,
            asOf: Date()
        )
        let isStale = detailResult.isStale || similarResult.isStale || creditsResult.isStale
        return CacheResult(value: snapshot, isStale: isStale)
    }
}

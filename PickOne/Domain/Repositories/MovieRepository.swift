import Foundation

protocol MovieRepository {
    func getTopRated(page: Int, policy: CachePolicy) async throws -> CacheResult<MoviePage>
    func getMovieDetail(id: Int, policy: CachePolicy) async throws -> CacheResult<Movie>
    func getSimilarMovies(id: Int, page: Int, policy: CachePolicy) async throws -> CacheResult<MoviePage>
    func getCredits(id: Int, policy: CachePolicy) async throws -> CacheResult<Credits>
}

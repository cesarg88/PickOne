import Foundation

protocol MovieRepository: Sendable {
    func getTopRated(page: Int, policy: CachePolicy) async throws -> CacheResult<MoviePage>
    func getMovieDetail(id: Int, policy: CachePolicy) async throws -> CacheResult<Movie>
    func getSimilarMovies(id: Int, page: Int, policy: CachePolicy) async throws -> CacheResult<MoviePage>
    func getCredits(id: Int, policy: CachePolicy) async throws -> CacheResult<Credits>
    func searchMovies(query: String, page: Int) async throws -> MoviePage
}

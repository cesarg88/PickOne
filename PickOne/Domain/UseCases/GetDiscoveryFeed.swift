import Foundation

protocol GetDiscoveryFeedUseCase {
    func execute(page: Int, policy: CachePolicy) async throws -> CacheResult<DiscoverySnapshot>
}

final class GetDiscoveryFeed: GetDiscoveryFeedUseCase {
    private let repository: MovieRepository

    init(repository: MovieRepository) {
        self.repository = repository
    }

    func execute(page: Int, policy: CachePolicy) async throws -> CacheResult<DiscoverySnapshot> {
        let result = try await repository.getTopRated(page: page, policy: policy)
        let snapshot = DiscoverySnapshot(
            movies: result.value.movies,
            currentPage: result.value.page,
            hasMorePages: result.value.hasMorePages,
            asOf: Date()
        )
        return CacheResult(value: snapshot, isStale: result.isStale)
    }
}

import Foundation
import Observation

@MainActor
@Observable
final class DiscoveryModel {
    private let getDiscoveryFeed: GetDiscoveryFeedUseCase
    
    var snapshot: DiscoverySnapshot = .empty
    var isLoading = false
    var isLoadingNextPage = false
    var errorMessage: String?
    
    init(getDiscoveryFeed: GetDiscoveryFeedUseCase) {
        self.getDiscoveryFeed = getDiscoveryFeed
    }
    
    func loadInitial() async {
        guard snapshot.movies.isEmpty else { return }
        isLoading = true
        errorMessage = nil
        await loadPage(1, shouldAppend: false)
        isLoading = false
    }
    
    func loadNextPageIfNeeded(current movie: MovieSummary) async {
        guard snapshot.hasMorePages else { return }
        guard snapshot.movies.last?.id == movie.id else { return }
        guard !isLoadingNextPage else { return }
        
        isLoadingNextPage = true
        let nextPage = snapshot.currentPage + 1
        await loadPage(nextPage, shouldAppend: true)
        isLoadingNextPage = false
    }
    
    private func loadPage(_ page: Int, shouldAppend: Bool) async {
        do {
            let cached = try await getDiscoveryFeed.execute(page: page, policy: .returnCacheElseLoad)
            apply(snapshot: cached.value, shouldAppend: shouldAppend)
            if cached.isStale {
                let refreshed = try await getDiscoveryFeed.execute(page: page, policy: .refresh)
                apply(snapshot: refreshed.value, shouldAppend: shouldAppend)
            }
        } catch {
            if snapshot.movies.isEmpty {
                errorMessage = error.localizedDescription
            }
        }
    }
    
    private func apply(snapshot: DiscoverySnapshot, shouldAppend: Bool) {
        if shouldAppend {
            let merged = mergeMovies(existing: self.snapshot.movies, incoming: snapshot.movies)
            self.snapshot = DiscoverySnapshot(
                movies: merged,
                currentPage: snapshot.currentPage,
                hasMorePages: snapshot.hasMorePages,
                asOf: snapshot.asOf
            )
        } else {
            self.snapshot = snapshot
        }
    }
    
    private func mergeMovies(existing: [MovieSummary], incoming: [MovieSummary]) -> [MovieSummary] {
        var seen = Set(existing.map(\.id))
        var merged = existing
        for movie in incoming where !seen.contains(movie.id) {
            merged.append(movie)
            seen.insert(movie.id)
        }
        return merged
    }
}

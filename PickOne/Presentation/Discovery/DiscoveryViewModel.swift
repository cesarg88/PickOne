import Foundation
import Observation

enum DiscoveryViewState: Equatable {
    case idle
    case loading
    case loaded(MovieSummaryPresentationModel)
    case error(String)
}

@MainActor
@Observable
final class DiscoveryViewModel {
    private let getDiscoveryFeed: GetDiscoveryFeedUseCase
    
    var state: DiscoveryViewState = .idle
    
    init(getDiscoveryFeed: GetDiscoveryFeedUseCase) {
        self.getDiscoveryFeed = getDiscoveryFeed
    }
    
    func loadInitial() async {
        if case .loaded(let data) = state, !data.movies.isEmpty {
            return
        }
        state = .loading
        await loadPage(1, shouldAppend: false)
    }
    
    func loadNextPageIfNeeded(current movie: DiscoveryMovieItem) async {
        guard var data = currentData(),
              data.hasMorePages,
              !data.isLoadingNextPage,
              data.movies.last?.id == movie.id else {
            return
        }
        
        data.isLoadingNextPage = true
        state = .loaded(data)
        await loadPage(data.currentPage + 1, shouldAppend: true)
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
            if shouldAppend, var data = currentData() {
                data.isLoadingNextPage = false
                state = .loaded(data)
            } else {
                state = .error(error.localizedDescription)
            }
        }
    }
    
    private func apply(snapshot: DiscoverySnapshot, shouldAppend: Bool) {
        let mapped = DiscoveryPresentationMapper.map(snapshot: snapshot)
        if shouldAppend, let data = currentData() {
            let merged = mergeMovies(existing: data.movies, incoming: mapped.movies)
            state = .loaded(
                MovieSummaryPresentationModel(
                    movies: merged,
                    currentPage: mapped.currentPage,
                    hasMorePages: mapped.hasMorePages,
                    isLoadingNextPage: false
                )
            )
        } else {
            state = .loaded(
                mapped
            )
        }
    }
    
    private func mergeMovies(existing: [DiscoveryMovieItem], incoming: [DiscoveryMovieItem]) -> [DiscoveryMovieItem] {
        var seen = Set(existing.map(\.id))
        var merged = existing
        for movie in incoming where !seen.contains(movie.id) {
            merged.append(movie)
            seen.insert(movie.id)
        }
        return merged
    }
    
    private func currentData() -> MovieSummaryPresentationModel? {
        guard case .loaded(let data) = state else { return nil }
        return data
    }
    
}

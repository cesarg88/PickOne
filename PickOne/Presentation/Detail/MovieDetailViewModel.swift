import Foundation
import Observation

enum MovieDetailViewState: Equatable {
    case idle
    case loading
    case loaded(MovieDetailPresentationModel)
    case error(String)
}

@MainActor
@Observable
final class MovieDetailViewModel {
    let movieId: Int
    private let getMovieDetail: GetMovieDetailUseCase
    private let setMembership: SetWatchlistMembershipUseCase?
    private let setWatched: SetWatchedUseCase?
    
    var state: MovieDetailViewState = .idle
    var actionErrorMessage: String?
    
    /// Convenience initializer for backwards compatibility
    init(movieId: Int, getMovieDetail: GetMovieDetailUseCase) {
        self.movieId = movieId
        self.getMovieDetail = getMovieDetail
        self.setMembership = nil
        self.setWatched = nil
    }
    
    /// Full initializer with watchlist support
    init(
        movieId: Int,
        getMovieDetail: GetMovieDetailUseCase,
        setMembership: SetWatchlistMembershipUseCase?,
        setWatched: SetWatchedUseCase?
    ) {
        self.movieId = movieId
        self.getMovieDetail = getMovieDetail
        self.setMembership = setMembership
        self.setWatched = setWatched
    }
    
    // MARK: - Load
    
    func load() async {
        state = .loading
        do {
            let cached = try await getMovieDetail.execute(id: movieId, policy: .returnCacheElseLoad)
            state = .loaded(MovieDetailPresentationMapper.map(snapshot: cached.value))
            if cached.isStale {
                let refreshed = try await getMovieDetail.execute(id: movieId, policy: .refresh)
                state = .loaded(MovieDetailPresentationMapper.map(snapshot: refreshed.value))
            }
        } catch {
            state = .error(error.localizedDescription)
        }
    }
    
    // MARK: - Watchlist Actions
    
    func toggleWatchlist() {
        guard
            let setMembership,
            case .loaded(var model) = state
        else { return }
        
        let movie = MovieSummary(
            id: model.id,
            title: model.title,
            posterPath: extractPosterPath(from: model.posterURL),
            releaseYear: extractYear(from: model.releaseYear),
            rating: extractRating(from: model.rating)
        )
        
        do {
            try setMembership.execute(movie: movie, isInWatchlist: !model.isInWatchlist)
            model.isInWatchlist.toggle()
            if !model.isInWatchlist {
                model.isWatched = false // Remove from watchlist clears watched status
            }
            state = .loaded(model)
        } catch {
            actionErrorMessage = error.localizedDescription
        }
    }
    
    func toggleWatched() {
        guard let setWatched,
              case .loaded(var model) = state,
              model.isInWatchlist else { return }
        
        do {
            try setWatched.execute(movieId: model.id, isWatched: !model.isWatched)
            model.isWatched.toggle()
            state = .loaded(model)
        } catch {
            actionErrorMessage = error.localizedDescription
        }
    }
    
    // MARK: - Helpers
    
    private func extractPosterPath(from url: URL?) -> String? {
        guard let url else { return nil }
        // URL format: https://image.tmdb.org/t/p/w500/path.jpg
        let path = url.path
        // Remove the size prefix (e.g., /w500)
        if let range = path.range(of: "/", options: .backwards) {
            return String(path[range.lowerBound...])
        }
        return path
    }
    
    private func extractYear(from yearText: String?) -> Int? {
        guard let yearText else { return nil }
        return Int(yearText)
    }
    
    private func extractRating(from ratingText: String) -> Double {
        // Rating format: "7.5 (1,234)"
        let components = ratingText.components(separatedBy: " ")
        return Double(components.first ?? "0") ?? 0
    }
}

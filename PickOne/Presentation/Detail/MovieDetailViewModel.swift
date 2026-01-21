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
    
    var state: MovieDetailViewState = .idle
    
    init(movieId: Int, getMovieDetail: GetMovieDetailUseCase) {
        self.movieId = movieId
        self.getMovieDetail = getMovieDetail
    }
    
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
}

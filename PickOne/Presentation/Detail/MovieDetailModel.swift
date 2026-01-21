import Foundation
import Observation

@MainActor
@Observable
final class MovieDetailModel {
    let movieId: Int
    private let getMovieDetail: GetMovieDetailUseCase
    
    var snapshot: MovieDetailSnapshot?
    var isLoading = false
    var errorMessage: String?
    
    init(movieId: Int, getMovieDetail: GetMovieDetailUseCase) {
        self.movieId = movieId
        self.getMovieDetail = getMovieDetail
    }
    
    func load() async {
        isLoading = true
        errorMessage = nil
        do {
            let cached = try await getMovieDetail.execute(id: movieId, policy: .returnCacheElseLoad)
            snapshot = cached.value
            if cached.isStale {
                let refreshed = try await getMovieDetail.execute(id: movieId, policy: .refresh)
                snapshot = refreshed.value
            }
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }
}

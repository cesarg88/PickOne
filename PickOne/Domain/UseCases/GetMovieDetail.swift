import Foundation

protocol GetMovieDetailUseCase: Sendable {
    func execute(id: Int, policy: CachePolicy) async throws -> CacheResult<MovieDetailSnapshot>
}

final class GetMovieDetail: GetMovieDetailUseCase, Sendable {
    private let repository: MovieRepository
    private let watchlistRepository: WatchlistRepository
    
    init(
        repository: MovieRepository,
        watchlistRepository: WatchlistRepository
    ) {
        self.repository = repository
        self.watchlistRepository = watchlistRepository
    }
    
    func execute(id: Int, policy: CachePolicy) async throws -> CacheResult<MovieDetailSnapshot> {
        let (detailResult, similarOutcome, creditsOutcome) = try await withThrowingTaskGroup(
            of: FetchResult.self
        ) { group in
            group.addTask {
                .detail(try await self.repository.getMovieDetail(id: id, policy: policy))
            }
            group.addTask {
                do {
                    let value = try await self.repository.getSimilarMovies(id: id, page: 1, policy: policy)
                    return .similar(.success(value))
                } catch {
                    return .similar(.failure(error))
                }
            }
            group.addTask {
                do {
                    let value = try await self.repository.getCredits(id: id, policy: policy)
                    return .credits(.success(value))
                } catch {
                    return .credits(.failure(error))
                }
            }
            
            var detail: CacheResult<Movie>?
            var similar: Result<CacheResult<MoviePage>, Error> = .failure(FetchError.missing)
            var credits: Result<CacheResult<Credits>, Error> = .failure(FetchError.missing)
            
            for try await result in group {
                switch result {
                case .detail(let value):
                    detail = value
                case .similar(let value):
                    similar = value
                case .credits(let value):
                    credits = value
                }
            }
            
            guard let detail else {
                throw FetchError.missing
            }
            
            return (detail, similar, credits)
        }
        
        var similar: [MovieSummary] = []
        var credits: Credits = Credits(director: nil, topCast: [])
        var isSimilarUnavailable = false
        var isCreditsUnavailable = false
        var similarStale = false
        var creditsStale = false
        
        switch similarOutcome {
        case .success(let result):
            similar = result.value.movies
            similarStale = result.isStale
        case .failure:
            isSimilarUnavailable = true
        }
        
        switch creditsOutcome {
        case .success(let result):
            credits = result.value
            creditsStale = result.isStale
        case .failure:
            isCreditsUnavailable = true
        }
        
        // Get watchlist status
        let watchlistStatus = watchlistRepository.getStatus(movieId: id)
        let isInWatchlist = watchlistStatus != .notInWatchlist
        let isWatched = watchlistStatus == .watched
        
        let snapshot = MovieDetailSnapshot(
            movie: detailResult.value,
            similar: similar,
            isInWatchlist: isInWatchlist,
            isWatched: isWatched,
            director: credits.director,
            topCast: credits.topCast,
            isSimilarUnavailable: isSimilarUnavailable,
            isCreditsUnavailable: isCreditsUnavailable,
            asOf: Date()
        )
        let isStale = detailResult.isStale || similarStale || creditsStale
        return CacheResult(value: snapshot, isStale: isStale)
    }
}

private enum FetchResult {
    case detail(CacheResult<Movie>)
    case similar(Result<CacheResult<MoviePage>, Error>)
    case credits(Result<CacheResult<Credits>, Error>)
}

private enum FetchError: Error {
    case missing
}

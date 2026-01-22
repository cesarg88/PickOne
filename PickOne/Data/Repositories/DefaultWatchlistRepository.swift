//
//  DefaultWatchlistRepository.swift
//  PickOne
//
//  Implementation of WatchlistRepository using LocalStore
//

import Foundation

final class DefaultWatchlistRepository: WatchlistRepository, @unchecked Sendable {
    
    private let localStore: LocalStoreProtocol
    
    init(localStore: LocalStoreProtocol) {
        self.localStore = localStore
    }
    
    // MARK: - WatchlistRepository
    
    func getAllItems() -> [WatchlistItem] {
        let persisted = localStore.getWatchlistItems()
        return persisted.map { item in
            WatchlistItem(
                id: item.movieId,
                addedAt: item.addedAt,
                isWatched: item.isWatched,
                movie: MovieSummary(
                    id: item.movieId,
                    title: item.title,
                    posterPath: item.posterPath,
                    releaseYear: item.releaseYear,
                    rating: item.rating
                )
            )
        }
    }
    
    func add(movie: MovieSummary) throws {
        let status = localStore.getWatchlistStatus(movieId: movie.id)
        if status.isInWatchlist {
            throw WatchlistError.movieAlreadyInWatchlist
        }
        
        let item = PersistedWatchlistItem(
            movieId: movie.id,
            title: movie.title,
            posterPath: movie.posterPath,
            releaseYear: movie.releaseYear,
            rating: movie.rating,
            addedAt: Date(),
            isWatched: false
        )
        
        localStore.saveWatchlistItem(item)
    }
    
    func remove(movieId: Int) throws {
        let status = localStore.getWatchlistStatus(movieId: movieId)
        if !status.isInWatchlist {
            throw WatchlistError.movieNotInWatchlist
        }
        
        localStore.removeWatchlistItem(movieId: movieId)
    }
    
    func setWatched(movieId: Int, isWatched: Bool) throws {
        let status = localStore.getWatchlistStatus(movieId: movieId)
        if !status.isInWatchlist {
            throw WatchlistError.movieNotInWatchlist
        }
        
        localStore.updateWatchedStatus(movieId: movieId, isWatched: isWatched)
    }
    
    func getStatus(movieId: Int) -> WatchlistStatus {
        let status = localStore.getWatchlistStatus(movieId: movieId)
        
        if !status.isInWatchlist {
            return .notInWatchlist
        }
        
        return status.isWatched ? .watched : .toWatch
    }
}

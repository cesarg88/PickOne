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
        localStore.getWatchlistItems().map(WatchlistItemMapper.toDomain)
    }
    
    func add(movie: MovieSummary) throws {
        let status = localStore.getWatchlistStatus(movieId: movie.id)
        if status.isInWatchlist {
            throw WatchlistError.movieAlreadyInWatchlist
        }
        
        let persisted = WatchlistItemMapper.toPersisted(movie: movie)
        localStore.saveWatchlistItem(persisted)
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

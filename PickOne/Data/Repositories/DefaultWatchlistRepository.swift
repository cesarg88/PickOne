//
//  DefaultWatchlistRepository.swift
//  PickOne
//
//  Implementation of WatchlistRepository using LocalStore
//

import Foundation

final class DefaultWatchlistRepository: WatchlistRepository {
    private let localStore: LocalStore

    init(localStore: LocalStore) {
        self.localStore = localStore
    }

    // MARK: - WatchlistRepository

    func loadAllItems() async throws -> [WatchlistItem] {
        try localStore.loadWatchlistItems().map(WatchlistItemMapper.toDomain)
    }

    func add(movie: MovieSummary) async throws {
        let status = localStore.getWatchlistStatus(movieId: movie.id)
        if status.isInWatchlist {
            throw WatchlistError.movieAlreadyInWatchlist
        }

        let persisted = WatchlistItemMapper.toPersisted(movie: movie)
        try localStore.saveWatchlistItem(persisted)
    }

    func remove(movieId: Int) async throws {
        let status = localStore.getWatchlistStatus(movieId: movieId)
        if !status.isInWatchlist {
            throw WatchlistError.movieNotInWatchlist
        }

        try localStore.removeWatchlistItem(movieId: movieId)
    }

    func setWatched(movieId: Int, isWatched: Bool) async throws {
        let status = localStore.getWatchlistStatus(movieId: movieId)
        if !status.isInWatchlist {
            throw WatchlistError.movieNotInWatchlist
        }

        try localStore.updateWatchedStatus(movieId: movieId, isWatched: isWatched)
    }

    func getStatus(movieId: Int) async throws -> WatchlistStatus {
        let status = localStore.getWatchlistStatus(movieId: movieId)

        if !status.isInWatchlist {
            return .notInWatchlist
        }

        return status.isWatched ? .watched : .toWatch
    }
}

//
//  DefaultWatchlistRepository.swift
//  PickOne
//
//  Implementation of WatchlistRepository using LocalStore
//

import Foundation

actor DefaultWatchlistRepository: WatchlistRepository {
    private let localStore: LocalStore

    init(localStore: LocalStore) {
        self.localStore = localStore
    }

    // MARK: - WatchlistRepository

    func loadAllItems() async throws -> [WatchlistItem] {
        try localStore.loadWatchlistItems().map(WatchlistItemMapper.toDomain)
    }

    func setMembership(
        movie: MovieSummary,
        isInWatchlist: Bool
    ) async throws -> WatchlistMutationOutcome {
        let status = localStore.getWatchlistStatus(movieId: movie.id)
        let currentStatus = watchlistStatus(status)
        if isInWatchlist {
            guard !status.isInWatchlist else {
                return WatchlistMutationOutcome(status: currentStatus, didChange: false)
            }
            let persisted = WatchlistItemMapper.toPersisted(movie: movie)
            try localStore.saveWatchlistItem(persisted)
            return WatchlistMutationOutcome(status: .toWatch, didChange: true)
        }
        guard currentStatus == .toWatch else {
            return WatchlistMutationOutcome(status: currentStatus, didChange: false)
        }
        try localStore.removeWatchlistItem(movieId: movie.id)
        return WatchlistMutationOutcome(status: .notInWatchlist, didChange: true)
    }

    func setWatched(
        movieId: Int,
        isWatched: Bool
    ) async throws -> WatchlistMutationOutcome {
        let status = localStore.getWatchlistStatus(movieId: movieId)
        if !status.isInWatchlist {
            throw WatchlistError.movieNotInWatchlist
        }
        let currentStatus = watchlistStatus(status)
        let requestedStatus: WatchlistStatus = isWatched ? .watched : .toWatch
        guard currentStatus != requestedStatus else {
            return WatchlistMutationOutcome(status: currentStatus, didChange: false)
        }

        try localStore.updateWatchedStatus(movieId: movieId, isWatched: isWatched)
        return WatchlistMutationOutcome(status: requestedStatus, didChange: true)
    }

    func getStatus(movieId: Int) async throws -> WatchlistStatus {
        watchlistStatus(localStore.getWatchlistStatus(movieId: movieId))
    }

    private func watchlistStatus(
        _ status: (isInWatchlist: Bool, isWatched: Bool)
    ) -> WatchlistStatus {
        if !status.isInWatchlist {
            return .notInWatchlist
        }
        return status.isWatched ? .watched : .toWatch
    }
}

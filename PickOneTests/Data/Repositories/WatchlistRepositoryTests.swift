//
//  WatchlistRepositoryTests.swift
//  PickOneTests
//
//  Tests for DefaultWatchlistRepository
//

import Foundation
@testable import PickOne
import Testing

@Suite("WatchlistRepository Tests", .serialized)
struct WatchlistRepositoryTests {
    // MARK: - getAllItems

    @Test("getAllItems returns empty when no items")
    func getAllItemsReturnsEmptyWhenNoItems() {
        let localStore = MockLocalStore()
        let sut = DefaultWatchlistRepository(localStore: localStore)

        let items = sut.getAllItems()

        #expect(items.isEmpty)
    }

    @Test("getAllItems maps persisted items to domain")
    func getAllItemsMapsPersistedToDomain() {
        let localStore = MockLocalStore()
        let addedAt = Date()
        localStore.seedWatchlistItems([
            PersistedWatchlistItem(
                movieId: 1,
                title: "Movie A",
                posterPath: "/poster.jpg",
                releaseYear: 2024,
                rating: 8.5,
                addedAt: addedAt,
                isWatched: false
            ),
            PersistedWatchlistItem(
                movieId: 2,
                title: "Movie B",
                posterPath: nil,
                releaseYear: nil,
                rating: 7.0,
                addedAt: addedAt.addingTimeInterval(-100),
                isWatched: true
            ),
        ])

        let sut = DefaultWatchlistRepository(localStore: localStore)
        let items = sut.getAllItems()

        #expect(items.count == 2)
        #expect(items[0].id == 1)
        #expect(items[0].movie.title == "Movie A")
        #expect(items[0].isWatched == false)
        #expect(items[1].id == 2)
        #expect(items[1].movie.title == "Movie B")
        #expect(items[1].isWatched == true)
    }

    @Test("loadAllItems propagates a corrupted Watchlist read")
    func loadAllItemsPropagatesCorruption() {
        let localStore = MockLocalStore()
        localStore.loadWatchlistItemsError = .corruptedWatchlist
        let sut = DefaultWatchlistRepository(localStore: localStore)

        #expect(throws: LocalStoreError.corruptedWatchlist) {
            _ = try sut.loadAllItems()
        }
    }

    // MARK: - add

    @Test("add saves item to local store")
    func addSavesItemToLocalStore() throws {
        let localStore = MockLocalStore()
        let sut = DefaultWatchlistRepository(localStore: localStore)
        let movie = MovieSummary(id: 1, title: "Test", posterPath: "/path.jpg", releaseYear: 2024, rating: 8.0)

        try sut.add(movie: movie)

        #expect(localStore.saveWatchlistItemCallCount == 1)
        #expect(localStore.lastSavedItem?.movieId == 1)
        #expect(localStore.lastSavedItem?.title == "Test")
        #expect(localStore.lastSavedItem?.isWatched == false)
    }

    @Test("add throws when movie already in watchlist")
    func addThrowsWhenAlreadyInWatchlist() {
        let localStore = MockLocalStore()
        localStore.seedWatchlistItems([
            PersistedWatchlistItem(
                movieId: 1,
                title: "Existing",
                posterPath: nil,
                releaseYear: nil,
                rating: 7.0,
                addedAt: Date(),
                isWatched: false
            ),
        ])
        let sut = DefaultWatchlistRepository(localStore: localStore)
        let movie = MovieSummary(id: 1, title: "Test", posterPath: nil, releaseYear: nil, rating: 8.0)

        #expect(throws: WatchlistError.movieAlreadyInWatchlist) {
            try sut.add(movie: movie)
        }
    }

    // MARK: - remove

    @Test("remove deletes item from local store")
    func removeDeletesFromLocalStore() throws {
        let localStore = MockLocalStore()
        localStore.seedWatchlistItems([
            PersistedWatchlistItem(
                movieId: 1,
                title: "To Remove",
                posterPath: nil,
                releaseYear: nil,
                rating: 7.0,
                addedAt: Date(),
                isWatched: false
            ),
        ])
        let sut = DefaultWatchlistRepository(localStore: localStore)

        try sut.remove(movieId: 1)

        #expect(localStore.removeWatchlistItemCallCount == 1)
        #expect(localStore.lastRemovedMovieId == 1)
    }

    @Test("remove throws when movie not in watchlist")
    func removeThrowsWhenNotInWatchlist() {
        let localStore = MockLocalStore()
        let sut = DefaultWatchlistRepository(localStore: localStore)

        #expect(throws: WatchlistError.movieNotInWatchlist) {
            try sut.remove(movieId: 999)
        }
    }

    // MARK: - setWatched

    @Test("setWatched updates watched status")
    func setWatchedUpdatesStatus() throws {
        let localStore = MockLocalStore()
        localStore.seedWatchlistItems([
            PersistedWatchlistItem(
                movieId: 1,
                title: "Movie",
                posterPath: nil,
                releaseYear: nil,
                rating: 7.0,
                addedAt: Date(),
                isWatched: false
            ),
        ])
        let sut = DefaultWatchlistRepository(localStore: localStore)

        try sut.setWatched(movieId: 1, isWatched: true)

        #expect(localStore.updateWatchedStatusCallCount == 1)
        #expect(localStore.lastUpdatedMovieId == 1)
        #expect(localStore.lastUpdatedWatchedStatus == true)
    }

    @Test("setWatched throws when movie not in watchlist")
    func setWatchedThrowsWhenNotInWatchlist() {
        let localStore = MockLocalStore()
        let sut = DefaultWatchlistRepository(localStore: localStore)

        #expect(throws: WatchlistError.movieNotInWatchlist) {
            try sut.setWatched(movieId: 999, isWatched: true)
        }
    }

    // MARK: - getStatus

    @Test("getStatus returns notInWatchlist when not present")
    func getStatusReturnsNotInWatchlistWhenNotPresent() {
        let localStore = MockLocalStore()
        let sut = DefaultWatchlistRepository(localStore: localStore)

        let status = sut.getStatus(movieId: 999)

        #expect(status == .notInWatchlist)
    }

    @Test("getStatus returns toWatch when in watchlist and not watched")
    func getStatusReturnsToWatchWhenNotWatched() {
        let localStore = MockLocalStore()
        localStore.seedWatchlistItems([
            PersistedWatchlistItem(
                movieId: 1,
                title: "Movie",
                posterPath: nil,
                releaseYear: nil,
                rating: 7.0,
                addedAt: Date(),
                isWatched: false
            ),
        ])
        let sut = DefaultWatchlistRepository(localStore: localStore)

        let status = sut.getStatus(movieId: 1)

        #expect(status == .toWatch)
    }

    @Test("getStatus returns watched when in watchlist and watched")
    func getStatusReturnsWatchedWhenWatched() {
        let localStore = MockLocalStore()
        localStore.seedWatchlistItems([
            PersistedWatchlistItem(
                movieId: 1,
                title: "Movie",
                posterPath: nil,
                releaseYear: nil,
                rating: 7.0,
                addedAt: Date(),
                isWatched: true
            ),
        ])
        let sut = DefaultWatchlistRepository(localStore: localStore)

        let status = sut.getStatus(movieId: 1)

        #expect(status == .watched)
    }
}

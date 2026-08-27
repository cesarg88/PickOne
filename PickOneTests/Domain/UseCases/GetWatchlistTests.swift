//
//  GetWatchlistTests.swift
//  PickOneTests
//
//  Tests for GetWatchlist use case
//

import Foundation
@testable import PickOne
import Testing

@Suite("GetWatchlist Tests", .serialized)
struct GetWatchlistTests {
    @Test("execute returns snapshot with separated toWatch and watched")
    func executeReturnsSnapshotWithSeparatedItems() async throws {
        let repository = MockWatchlistRepository()
        repository.getAllItemsResult = WatchlistTestFixtures.twoItems
        let sut = GetWatchlist(repository: repository)

        let snapshot = try await sut.execute()

        #expect(snapshot.toWatch.count == 1)
        #expect(snapshot.watched.count == 1)
        #expect(repository.loadAllItemsCallCount == 1)
    }

    @Test("execute puts unwatched items in toWatch")
    func executePutsUnwatchedInToWatch() async throws {
        let repository = MockWatchlistRepository()
        repository.getAllItemsResult = WatchlistTestFixtures.twoItems
        let sut = GetWatchlist(repository: repository)

        let snapshot = try await sut.execute()

        #expect(snapshot.toWatch.allSatisfy { !$0.isWatched })
    }

    @Test("execute puts watched items in watched")
    func executePutsWatchedInWatched() async throws {
        let repository = MockWatchlistRepository()
        repository.getAllItemsResult = WatchlistTestFixtures.twoItems
        let sut = GetWatchlist(repository: repository)

        let snapshot = try await sut.execute()

        #expect(snapshot.watched.allSatisfy { $0.isWatched })
    }

    @Test("execute returns empty snapshot when no items")
    func executeReturnsEmptySnapshotWhenNoItems() async throws {
        let repository = MockWatchlistRepository()
        repository.getAllItemsResult = []
        let sut = GetWatchlist(repository: repository)

        let snapshot = try await sut.execute()

        #expect(snapshot.toWatch.isEmpty)
        #expect(snapshot.watched.isEmpty)
    }
}

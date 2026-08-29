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
    @Test("execute returns future intent and omits watched history")
    func executeReturnsFutureIntentOnly() async throws {
        let repository = MockWatchlistRepository()
        repository.getAllItemsResult = WatchlistTestFixtures.twoItems
        let sut = GetWatchlist(repository: repository)

        let snapshot = try await sut.execute()

        #expect(snapshot.toWatch == WatchlistTestFixtures.twoItems)
        #expect(repository.loadAllItemsCallCount == 1)
    }

    @Test("execute returns empty snapshot when no items")
    func executeReturnsEmptySnapshotWhenNoItems() async throws {
        let repository = MockWatchlistRepository()
        repository.getAllItemsResult = []
        let sut = GetWatchlist(repository: repository)

        let snapshot = try await sut.execute()

        #expect(snapshot.toWatch.isEmpty)
    }
}

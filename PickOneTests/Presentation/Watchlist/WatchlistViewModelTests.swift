//
//  WatchlistViewModelTests.swift
//  PickOneTests
//
//  Tests for WatchlistViewModel
//

import Testing
import Foundation
@testable import PickOne

@MainActor
@Suite("WatchlistViewModel Tests", .serialized)
struct WatchlistViewModelTests {
    
    // MARK: - Load
    
    @Test("load transitions to empty when no items")
    func loadTransitionsToEmptyWhenNoItems() {
        let repository = MockWatchlistRepository()
        repository.getAllItemsResult = []
        let (sut, _) = makeSUT(repository: repository)
        
        sut.load()
        
        if case .empty(let filter) = sut.state {
            #expect(filter == .all)
        } else {
            Issue.record("Expected empty state")
        }
    }
    
    @Test("load transitions to loaded when items exist")
    func loadTransitionsToLoadedWhenItemsExist() {
        let repository = MockWatchlistRepository()
        repository.getAllItemsResult = WatchlistTestFixtures.twoItems
        let (sut, _) = makeSUT(repository: repository)
        
        sut.load()
        
        if case .loaded(let data) = sut.state {
            #expect(data.items.count == 2)
        } else {
            Issue.record("Expected loaded state")
        }
    }
    
    // MARK: - Filter
    
    @Test("applyFilter updates current filter and reloads")
    func applyFilterUpdatesAndReloads() {
        let repository = MockWatchlistRepository()
        repository.getAllItemsResult = WatchlistTestFixtures.twoItems
        let (sut, _) = makeSUT(repository: repository)
        
        sut.load()
        sut.applyFilter(.watched)
        
        #expect(sut.currentFilter == .watched)
        if case .loaded(let data) = sut.state {
            #expect(data.items.count == 1)
            #expect(data.items[0].isWatched == true)
        } else {
            Issue.record("Expected loaded state")
        }
    }
    
    @Test("applyFilter shows empty when no items match")
    func applyFilterShowsEmptyWhenNoMatch() {
        let repository = MockWatchlistRepository()
        repository.getAllItemsResult = [WatchlistTestFixtures.unwatchedItem]
        let (sut, _) = makeSUT(repository: repository)
        
        sut.load()
        sut.applyFilter(.watched)
        
        if case .empty(let filter) = sut.state {
            #expect(filter == .watched)
        } else {
            Issue.record("Expected empty state")
        }
    }
    
    // MARK: - Remove
    
    @Test("remove calls repository remove via use case")
    func removeCallsRepositoryRemove() {
        let repository = MockWatchlistRepository()
        repository.getAllItemsResult = WatchlistTestFixtures.twoItems
        repository.statusResult = .toWatch // Item is in watchlist, so remove will be called
        let (sut, _) = makeSUT(repository: repository)
        
        sut.load()
        sut.remove(movieId: 1)
        
        #expect(repository.removeCallCount == 1)
        #expect(repository.lastRemovedMovieId == 1)
    }
    
    @Test("remove reloads list after success")
    func removeReloadsListAfterSuccess() {
        let repository = MockWatchlistRepository()
        repository.getAllItemsResult = WatchlistTestFixtures.twoItems
        repository.statusResult = .toWatch
        let (sut, _) = makeSUT(repository: repository)
        
        sut.load()
        let initialCallCount = repository.getAllItemsCallCount
        
        sut.remove(movieId: 1)
        
        #expect(repository.getAllItemsCallCount > initialCallCount)
    }
    
    // MARK: - Toggle Watched
    
    @Test("toggleWatched calls repository setWatched via use case")
    func toggleWatchedCallsRepositorySetWatched() {
        let repository = MockWatchlistRepository()
        repository.getAllItemsResult = [WatchlistTestFixtures.unwatchedItem]
        repository.statusResult = .toWatch // Item is unwatched (toWatch), so setWatched will be called
        let (sut, _) = makeSUT(repository: repository)
        
        sut.load()
        sut.toggleWatched(movieId: 1)
        
        #expect(repository.setWatchedCallCount == 1)
        #expect(repository.lastSetWatchedMovieId == 1)
        #expect(repository.lastSetWatchedValue == true) // Was false, toggled to true
    }
    
    @Test("toggleWatched reloads list after success")
    func toggleWatchedReloadsListAfterSuccess() {
        let repository = MockWatchlistRepository()
        repository.getAllItemsResult = [WatchlistTestFixtures.unwatchedItem]
        repository.statusResult = .toWatch
        let (sut, _) = makeSUT(repository: repository)
        
        sut.load()
        let initialCallCount = repository.getAllItemsCallCount
        
        sut.toggleWatched(movieId: 1)
        
        #expect(repository.getAllItemsCallCount > initialCallCount)
    }
    
    // MARK: - Helpers
    
    private func makeSUT(
        repository: MockWatchlistRepository = MockWatchlistRepository()
    ) -> (sut: WatchlistViewModel, repository: MockWatchlistRepository) {
        let getWatchlist = GetWatchlist(repository: repository)
        let setMembership = SetWatchlistMembership(repository: repository)
        let setWatched = SetWatched(repository: repository)
        
        let sut = WatchlistViewModel(
            getWatchlist: getWatchlist,
            setMembership: setMembership,
            setWatched: setWatched
        )
        
        return (sut, repository)
    }
}

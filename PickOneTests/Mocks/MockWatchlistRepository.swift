//
//  MockWatchlistRepository.swift
//  PickOneTests
//
//  Mock implementation of WatchlistRepository for testing
//

import Foundation
@testable import PickOne

final class MockWatchlistRepository: WatchlistRepository, @unchecked Sendable {
    
    // MARK: - Stub Results
    
    var getAllItemsResult: [WatchlistItem] = []
    var addError: Error?
    var removeError: Error?
    var setWatchedError: Error?
    var statusResult: WatchlistStatus = .notInWatchlist
    
    // MARK: - Call Tracking
    
    private(set) var getAllItemsCallCount = 0
    private(set) var addCallCount = 0
    private(set) var removeCallCount = 0
    private(set) var setWatchedCallCount = 0
    private(set) var getStatusCallCount = 0
    
    private(set) var lastAddedMovie: MovieSummary?
    private(set) var lastRemovedMovieId: Int?
    private(set) var lastSetWatchedMovieId: Int?
    private(set) var lastSetWatchedValue: Bool?
    private(set) var lastGetStatusMovieId: Int?
    
    // MARK: - WatchlistRepository
    
    func getAllItems() -> [WatchlistItem] {
        getAllItemsCallCount += 1
        return getAllItemsResult
    }
    
    func add(movie: MovieSummary) throws {
        addCallCount += 1
        lastAddedMovie = movie
        if let error = addError {
            throw error
        }
    }
    
    func remove(movieId: Int) throws {
        removeCallCount += 1
        lastRemovedMovieId = movieId
        if let error = removeError {
            throw error
        }
    }
    
    func setWatched(movieId: Int, isWatched: Bool) throws {
        setWatchedCallCount += 1
        lastSetWatchedMovieId = movieId
        lastSetWatchedValue = isWatched
        if let error = setWatchedError {
            throw error
        }
    }
    
    func getStatus(movieId: Int) -> WatchlistStatus {
        getStatusCallCount += 1
        lastGetStatusMovieId = movieId
        return statusResult
    }
    
    // MARK: - Test Helpers
    
    func reset() {
        getAllItemsResult = []
        addError = nil
        removeError = nil
        setWatchedError = nil
        statusResult = .notInWatchlist
        
        getAllItemsCallCount = 0
        addCallCount = 0
        removeCallCount = 0
        setWatchedCallCount = 0
        getStatusCallCount = 0
        
        lastAddedMovie = nil
        lastRemovedMovieId = nil
        lastSetWatchedMovieId = nil
        lastSetWatchedValue = nil
        lastGetStatusMovieId = nil
    }
}

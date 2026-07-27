//
//  WatchlistViewModel.swift
//  PickOne
//
//  ViewModel for the Watchlist screen
//

import Foundation
import Observation

// MARK: - State

enum WatchlistViewState: Equatable {
    case idle
    case loaded(WatchlistPresentationModel)
    case empty(WatchlistFilter)
}

// MARK: - ViewModel

@MainActor
@Observable
final class WatchlistViewModel {
    
    private let getWatchlist: GetWatchlistUseCase
    private let setMembership: SetWatchlistMembershipUseCase
    private let setWatched: SetWatchedUseCase
    
    var state: WatchlistViewState = .idle
    var currentFilter: WatchlistFilter = .all
    var actionErrorMessage: String?
    
    init(
        getWatchlist: GetWatchlistUseCase,
        setMembership: SetWatchlistMembershipUseCase,
        setWatched: SetWatchedUseCase
    ) {
        self.getWatchlist = getWatchlist
        self.setMembership = setMembership
        self.setWatched = setWatched
    }
    
    // MARK: - Actions
    
    func load() {
        let snapshot = getWatchlist.execute()
        applySnapshot(snapshot)
    }
    
    func applyFilter(_ filter: WatchlistFilter) {
        currentFilter = filter
        load()
    }
    
    func toggleWatched(movieId: Int) {
        guard let item = findItem(movieId: movieId) else { return }
        
        do {
            try setWatched.execute(movieId: movieId, isWatched: !item.isWatched)
            load()
        } catch {
            actionErrorMessage = error.localizedDescription
        }
    }
    
    func remove(movieId: Int) {
        guard let item = findItem(movieId: movieId) else { return }
        
        do {
            try setMembership.execute(movie: item.movieSummary, isInWatchlist: false)
            load()
        } catch {
            actionErrorMessage = error.localizedDescription
        }
    }
    
    // MARK: - Private
    
    private func applySnapshot(_ snapshot: WatchlistSnapshot) {
        let model = WatchlistPresentationMapper.map(snapshot: snapshot, filter: currentFilter)
        
        if model.isEmpty {
            state = .empty(currentFilter)
        } else {
            state = .loaded(model)
        }
    }
    
    private func findItem(movieId: Int) -> WatchlistItemPresentation? {
        guard case .loaded(let model) = state else { return nil }
        return model.items.first { $0.id == movieId }
    }
}

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
    @ObservationIgnored private let eligibilityDidChange: @MainActor (DecisionEligibilityChange) -> Void

    var state: WatchlistViewState = .idle
    var currentFilter: WatchlistFilter = .all
    var actionErrorMessage: String?

    init(
        getWatchlist: GetWatchlistUseCase,
        setMembership: SetWatchlistMembershipUseCase,
        setWatched: SetWatchedUseCase,
        eligibilityDidChange: @escaping @MainActor (DecisionEligibilityChange) -> Void = { _ in }
    ) {
        self.getWatchlist = getWatchlist
        self.setMembership = setMembership
        self.setWatched = setWatched
        self.eligibilityDidChange = eligibilityDidChange
    }

    // MARK: - Actions

    func load() async {
        do {
            let snapshot = try await getWatchlist.execute()
            applySnapshot(snapshot)
        } catch {
            actionErrorMessage = error.localizedDescription
        }
    }

    func applyFilter(_ filter: WatchlistFilter) async {
        currentFilter = filter
        await load()
    }

    func toggleWatched(movieId: Int) async {
        guard let item = findItem(movieId: movieId) else { return }

        do {
            let outcome = try await setWatched.execute(
                movieId: movieId,
                isWatched: !item.isWatched
            )
            await load()
            if outcome.didChange {
                notifyEligibilityChange(movieID: movieId)
            }
        } catch {
            actionErrorMessage = error.localizedDescription
        }
    }

    func remove(movieId: Int) async {
        guard let item = findItem(movieId: movieId) else { return }

        do {
            let outcome = try await setMembership.execute(
                movie: item.movieSummary,
                isInWatchlist: false
            )
            await load()
            if outcome.didChange {
                notifyEligibilityChange(movieID: movieId)
            }
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
        guard case let .loaded(model) = state else { return nil }
        return model.items.first { $0.id == movieId }
    }

    private func notifyEligibilityChange(movieID: Int) {
        guard let change = DecisionEligibilityChange(movieID: movieID, cause: .watchlist) else {
            return
        }
        eligibilityDidChange(change)
    }
}

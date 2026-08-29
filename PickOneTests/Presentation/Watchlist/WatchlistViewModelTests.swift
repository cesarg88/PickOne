//
//  WatchlistViewModelTests.swift
//  PickOneTests
//
//  Tests for WatchlistViewModel
//

import Foundation
@testable import PickOne
import Testing

@MainActor
@Suite("WatchlistViewModel Tests", .serialized)
struct WatchlistViewModelTests {
    // MARK: - Load

    @Test("load transitions to empty when no items")
    func loadTransitionsToEmptyWhenNoItems() async {
        let repository = MockWatchlistRepository()
        repository.getAllItemsResult = []
        let (sut, _) = makeSUT(repository: repository)

        await sut.load()

        guard case .empty = sut.state else {
            Issue.record("Expected empty state")
            return
        }
    }

    @Test("load transitions to loaded when items exist")
    func loadTransitionsToLoadedWhenItemsExist() async {
        let repository = MockWatchlistRepository()
        repository.getAllItemsResult = WatchlistTestFixtures.twoItems
        let (sut, _) = makeSUT(repository: repository)

        await sut.load()

        if case let .loaded(data) = sut.state {
            #expect(data.items.count == 1)
        } else {
            Issue.record("Expected loaded state")
        }
    }

    @Test("load omits an unavailable compatibility rating")
    func loadOmitsUnavailableCompatibilityRating() async {
        let repository = MockWatchlistRepository()
        repository.getAllItemsResult = [
            WatchlistItem(
                id: 1,
                addedAt: Date(timeIntervalSince1970: 100),
                isWatched: false,
                movie: MovieSummary(
                    id: 1,
                    title: "Movie",
                    posterPath: nil,
                    releaseYear: 2024,
                    rating: 0
                )
            ),
        ]
        let (sut, _) = makeSUT(repository: repository)

        await sut.load()

        guard case let .loaded(data) = sut.state else {
            Issue.record("Expected loaded state")
            return
        }
        #expect(data.items.first?.rating == nil)
    }

    // MARK: - Remove

    @Test("remove calls repository remove via use case")
    func removeCallsRepositoryRemove() async {
        let repository = MockWatchlistRepository()
        repository.getAllItemsResult = WatchlistTestFixtures.twoItems
        repository.statusResult = .toWatch // Item is in watchlist, so remove will be called
        let (sut, _) = makeSUT(repository: repository)

        await sut.load()
        await sut.remove(movieId: 1)

        #expect(repository.membershipCallCount == 1)
        #expect(repository.lastMembershipMovie?.id == 1)
        #expect(repository.lastMembershipValue == false)
    }

    @Test("remove reloads list after success")
    func removeReloadsListAfterSuccess() async {
        let repository = MockWatchlistRepository()
        repository.getAllItemsResult = WatchlistTestFixtures.twoItems
        repository.statusResult = .toWatch
        let (sut, _) = makeSUT(repository: repository)

        await sut.load()
        let initialCallCount = repository.getAllItemsCallCount

        await sut.remove(movieId: 1)

        #expect(repository.getAllItemsCallCount > initialCallCount)
    }

    @Test("watched-only state is absent from the final Watchlist")
    func watchedOnlyStateIsAbsent() async throws {
        let snapshotID = try LocalViewerStateTestFixtures.uuid(
            LocalViewerStateTestFixtures.firstID
        )
        let watched = try ViewerMovieState(
            movieID: 1,
            displayMetadata: LocalViewerStateTestFixtures.metadata(),
            watchState: .watched,
            preference: nil,
            watchlistIntent: nil,
            stateChangedAt: LocalViewerStateTestFixtures.date
        )
        let envelope = LocalViewerStateEnvelopeMapper().replacingStates(
            in: LocalViewerStateTestFixtures.emptyEnvelope(id: snapshotID),
            snapshotID: snapshotID,
            states: [watched]
        )
        let files = try InMemoryLocalViewerStateFileStore(
            activeData: LocalViewerStateTestFixtures.encoded(envelope)
        )
        let stateRepository = LocalViewerStateRepository(
            fileStore: files,
            legacySource: InMemoryLegacyViewerStateSource()
        )
        let watchlistRepository = LocalViewerStateWatchlistAdapter(
            repository: stateRepository
        )
        var changes: [DecisionEligibilityChange] = []
        let sut = WatchlistViewModel(
            getWatchlist: GetWatchlist(repository: watchlistRepository),
            setMembership: SetWatchlistMembership(repository: watchlistRepository),
            eligibilityDidChange: { changes.append($0) }
        )

        await sut.load()
        guard case .empty = sut.state else {
            Issue.record("Expected watched-only state to be absent")
            return
        }
        #expect(try await stateRepository.state(movieID: watched.movieID) == watched)
        #expect(changes.isEmpty)
        #expect(files.activeReplacementCount == 0)
    }

    @Test("successful mutation reports a bounded Home repair change")
    func successfulMutationReportsRepairChange() async throws {
        let repository = MockWatchlistRepository()
        repository.getAllItemsResult = [WatchlistTestFixtures.unwatchedItem]
        repository.statusResult = .toWatch
        var changes: [DecisionEligibilityChange] = []
        let (sut, _) = makeSUT(
            repository: repository,
            eligibilityDidChange: { changes.append($0) }
        )

        await sut.load()
        await sut.remove(movieId: 1)

        let expectedChange = try #require(
            DecisionEligibilityChange(movieID: 1, cause: .watchlist)
        )
        #expect(changes == [expectedChange])
    }

    // MARK: - Helpers

    private func makeSUT(
        repository: MockWatchlistRepository = MockWatchlistRepository(),
        eligibilityDidChange: @escaping @MainActor (DecisionEligibilityChange) -> Void = { _ in }
    ) -> (sut: WatchlistViewModel, repository: MockWatchlistRepository) {
        let getWatchlist = GetWatchlist(repository: repository)
        let setMembership = SetWatchlistMembership(repository: repository)
        let sut = WatchlistViewModel(
            getWatchlist: getWatchlist,
            setMembership: setMembership,
            eligibilityDidChange: eligibilityDidChange
        )

        return (sut, repository)
    }
}

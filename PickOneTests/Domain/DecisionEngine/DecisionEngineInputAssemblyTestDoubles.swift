@testable import PickOne

final class InputAssemblyWatchlistRepository: WatchlistRepository {
    enum ReadError: Error {
        case unreadable
    }

    private let items: [WatchlistItem]
    private let error: ReadError?

    init(items: [WatchlistItem] = [], error: ReadError? = nil) {
        self.items = items
        self.error = error
    }

    func loadAllItems() throws -> [WatchlistItem] {
        if let error {
            throw error
        }
        return items
    }

    func setMembership(
        movie _: MovieSummary,
        isInWatchlist _: Bool
    ) -> WatchlistMutationOutcome {
        WatchlistMutationOutcome(status: .notInWatchlist, didChange: false)
    }

    func setWatched(
        movieId _: Int,
        isWatched _: Bool
    ) -> WatchlistMutationOutcome {
        WatchlistMutationOutcome(status: .notInWatchlist, didChange: false)
    }

    func getStatus(movieId _: Int) -> WatchlistStatus {
        .notInWatchlist
    }
}

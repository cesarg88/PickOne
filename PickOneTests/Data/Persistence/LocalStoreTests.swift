import Foundation
import Testing
@testable import PickOne

@Suite("LocalStore Tests", .serialized)
struct LocalStoreTests {
    @Test("watchlist survives a new store instance")
    func watchlistPersists() throws {
        let context = makeContext()
        defer { context.defaults.removePersistentDomain(forName: context.suiteName) }

        let item = makeItem()
        try context.store.saveWatchlistItem(item)

        let reloadedStore = UserDefaultsLocalStore(suiteName: context.suiteName)
        #expect(reloadedStore.getWatchlistItems() == [item])
    }

    @Test("corrupted watchlist is preserved when a mutation is attempted")
    func corruptedWatchlistIsNotOverwritten() throws {
        let context = makeContext()
        defer { context.defaults.removePersistentDomain(forName: context.suiteName) }

        let corruptedData = Data("not-json".utf8)
        context.defaults.set(corruptedData, forKey: "watchlist_items_v2")

        #expect(throws: LocalStoreError.corruptedWatchlist) {
            try context.store.saveWatchlistItem(makeItem())
        }
        #expect(
            context.defaults.data(forKey: "watchlist_items_v2") == corruptedData
        )
    }

    @Test("concurrent watchlist writes preserve every item")
    func concurrentWatchlistWritesPreserveEveryItem() async {
        let context = makeContext()
        let store = context.store
        defer { context.defaults.removePersistentDomain(forName: context.suiteName) }

        let items = (1...20).map { id in
            PersistedWatchlistItem(
                movieId: id,
                title: "Movie \(id)",
                posterPath: nil,
                releaseYear: 2026,
                rating: 7,
                addedAt: Date(timeIntervalSince1970: TimeInterval(id)),
                isWatched: false
            )
        }

        await withTaskGroup(of: Void.self) { group in
            for item in items {
                group.addTask {
                    try? store.saveWatchlistItem(item)
                }
            }
        }

        #expect(Set(store.getWatchlistItems().map(\.movieId)) == Set(1...20))
    }

    private func makeContext() -> (
        suiteName: String,
        defaults: UserDefaults,
        store: UserDefaultsLocalStore
    ) {
        let suiteName = "PickOneTests.LocalStore.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        return (
            suiteName,
            defaults,
            UserDefaultsLocalStore(suiteName: suiteName)
        )
    }

    private func makeItem() -> PersistedWatchlistItem {
        PersistedWatchlistItem(
            movieId: 42,
            title: "Arrival",
            posterPath: "/arrival.jpg",
            releaseYear: 2016,
            rating: 7.6,
            addedAt: Date(timeIntervalSince1970: 1_000),
            isWatched: false
        )
    }
}

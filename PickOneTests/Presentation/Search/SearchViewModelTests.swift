import Foundation
import Testing
@testable import PickOne

@MainActor
@Suite("SearchViewModel Tests", .serialized)
struct SearchViewModelTests {
    @Test("older search cannot overwrite newer results")
    func olderSearchCannotOverwriteNewerResults() async {
        let search = ControlledSearchMoviesUseCase()
        let sut = SearchViewModel(
            searchMovies: search,
            searchHistory: SearchHistoryStub()
        )

        sut.selectHistoryItem("first")
        await search.waitUntilStarted(query: "first", page: 1)

        sut.selectHistoryItem("second")
        await search.waitUntilStarted(query: "second", page: 1)

        await search.complete(
            query: "second",
            page: 1,
            with: .success(snapshot(query: "second", movieID: 2))
        )
        await waitUntil {
            guard case .results(let model) = sut.state else { return false }
            return model.query == "second"
        }

        await search.complete(
            query: "first",
            page: 1,
            with: .success(snapshot(query: "first", movieID: 1))
        )
        await Task.yield()

        guard case .results(let model) = sut.state else {
            Issue.record("Expected latest results")
            return
        }
        #expect(model.query == "second")
        #expect(model.items.map(\.id) == [2])
    }

    @Test("pagination from an old query cannot overwrite a new search")
    func stalePaginationCannotOverwriteNewSearch() async {
        let search = ControlledSearchMoviesUseCase()
        let sut = SearchViewModel(
            searchMovies: search,
            searchHistory: SearchHistoryStub()
        )

        sut.selectHistoryItem("first")
        await search.waitUntilStarted(query: "first", page: 1)
        await search.complete(
            query: "first",
            page: 1,
            with: .success(
                snapshot(query: "first", movieID: 1, page: 1, totalPages: 2)
            )
        )
        await waitUntil {
            if case .results = sut.state { return true }
            return false
        }

        let paginationTask = Task { await sut.loadNextPage() }
        await search.waitUntilStarted(query: "first", page: 2)

        sut.selectHistoryItem("second")
        await search.waitUntilStarted(query: "second", page: 1)
        await search.complete(
            query: "second",
            page: 1,
            with: .success(snapshot(query: "second", movieID: 2))
        )
        await waitUntil {
            guard case .results(let model) = sut.state else { return false }
            return model.query == "second"
        }

        await search.complete(
            query: "first",
            page: 2,
            with: .success(
                snapshot(query: "first", movieID: 3, page: 2, totalPages: 2)
            )
        )
        await paginationTask.value

        guard case .results(let model) = sut.state else {
            Issue.record("Expected new query results")
            return
        }
        #expect(model.query == "second")
        #expect(model.items.map(\.id) == [2])
    }

    private func snapshot(
        query: String,
        movieID: Int,
        page: Int = 1,
        totalPages: Int = 1
    ) -> SearchSnapshot {
        SearchSnapshot(
            query: query,
            results: [
                MovieSummary(
                    id: movieID,
                    title: "\(query) movie",
                    posterPath: nil,
                    releaseYear: 2026,
                    rating: 7
                )
            ],
            currentPage: page,
            totalPages: totalPages,
            asOf: Date()
        )
    }

    private func waitUntil(
        _ condition: @escaping @MainActor () -> Bool
    ) async {
        for _ in 0..<100 where !condition() {
            await Task.yield()
        }
        #expect(condition())
    }
}

@MainActor
private final class SearchHistoryStub: SearchHistoryUseCase {
    func getHistory() -> [String] { [] }
    func clear() {}
}

private actor ControlledSearchMoviesUseCase: SearchMoviesUseCase {
    private struct Request: Hashable {
        let query: String
        let page: Int
    }

    private var continuations: [
        Request: CheckedContinuation<SearchSnapshot, Error>
    ] = [:]
    private var started: Set<Request> = []

    func execute(query: String, page: Int) async throws -> SearchSnapshot {
        let request = Request(query: query, page: page)
        started.insert(request)
        return try await withCheckedThrowingContinuation { continuation in
            continuations[request] = continuation
        }
    }

    func waitUntilStarted(query: String, page: Int) async {
        let request = Request(query: query, page: page)
        while !started.contains(request) {
            await Task.yield()
        }
    }

    func complete(
        query: String,
        page: Int,
        with result: Result<SearchSnapshot, Error>
    ) {
        let request = Request(query: query, page: page)
        guard let continuation = continuations.removeValue(forKey: request) else {
            return
        }
        continuation.resume(with: result)
    }
}

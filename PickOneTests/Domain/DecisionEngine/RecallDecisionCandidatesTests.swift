@testable import PickOne
import Testing

@Suite("Decision candidate recall tests")
struct RecallDecisionCandidatesTests {
    @Test("normal recall requests exactly six pages in stable order")
    func requestsSixOrderedPages() async throws {
        let repository = CandidateRepositorySpy()
        let sut = RecallDecisionCandidates(repository: repository)

        let candidates = try await sut.execute(context: testContext())

        #expect(await repository.requestedPages == [1, 2, 3, 4, 5, 6])
        #expect(candidates.map(\.movieID) == [1, 2, 3, 4, 5, 6])
    }

    @Test("deduplication keeps the first occurrence and page order")
    func deduplicatesByFirstOccurrence() async throws {
        let repository = try CandidateRepositorySpy(pages: [
            1: [seed(id: 10, title: "First"), seed(id: 20, title: "Second")],
            2: [seed(id: 10, title: "Duplicate"), seed(id: 30, title: "Third")],
            3: [],
            4: [],
            5: [],
            6: [],
        ])
        let sut = RecallDecisionCandidates(repository: repository)

        let candidates = try await sut.execute(context: testContext())

        #expect(candidates.map(\.movieID) == [10, 20, 30])
        #expect(candidates.first?.localizedTitle == "First")
    }

    @Test("a source error stops recall and remains an error")
    func propagatesSourceError() async throws {
        let repository = CandidateRepositorySpy(failingPage: 3)
        let sut = RecallDecisionCandidates(repository: repository)

        await #expect(throws: CandidateRecallTestError.sourceFailure) {
            try await sut.execute(context: testContext())
        }
        #expect(await repository.requestedPages == [1, 2, 3])
    }

    @Test("cancellation stops later page requests")
    func preservesCancellation() async throws {
        let repository = CandidateRepositorySpy(cancellingPage: 2)
        let sut = RecallDecisionCandidates(repository: repository)
        let task = Task {
            try await sut.execute(context: testContext())
        }

        await #expect(throws: CancellationError.self) {
            try await task.value
        }
        #expect(await repository.requestedPages == [1, 2])
    }

    @Test("candidate context rejects unsupported or empty recall filters")
    func rejectsInvalidContext() {
        #expect(DecisionCandidateContext(region: .spain, selectedProviderIDs: []) == nil)
        #expect(DecisionCandidateContext(
            region: ViewingRegion(code: "US"),
            selectedProviderIDs: [8]
        ) == nil)
        #expect(DecisionCandidateContext(region: .spain, selectedProviderIDs: [-1]) == nil)
        #expect(DecisionCandidateContext(region: .spain, selectedProviderIDs: [999]) == nil)
    }
}

private enum CandidateRecallTestError: Error, Equatable {
    case sourceFailure
}

private actor CandidateRepositorySpy: DecisionCandidateRepository {
    private(set) var requestedPages: [Int] = []
    private let pages: [Int: [DecisionCandidateSeed]]
    private let failingPage: Int?
    private let cancellingPage: Int?

    init(
        pages: [Int: [DecisionCandidateSeed]] = [:],
        failingPage: Int? = nil,
        cancellingPage: Int? = nil
    ) {
        self.pages = pages
        self.failingPage = failingPage
        self.cancellingPage = cancellingPage
    }

    func discoverPage(
        _ page: Int,
        context: DecisionCandidateContext
    ) async throws -> [DecisionCandidateSeed] {
        requestedPages.append(page)
        if page == failingPage {
            throw CandidateRecallTestError.sourceFailure
        }
        if page == cancellingPage {
            withUnsafeCurrentTask { $0?.cancel() }
        }
        if let candidates = pages[page] {
            return candidates
        }
        return try [seed(id: page)]
    }
}

private func seed(id: Int, title: String? = nil) throws -> DecisionCandidateSeed {
    try #require(DecisionCandidateSeed(
        movieID: id,
        localizedTitle: title ?? "Movie \(id)",
        posterPath: nil,
        backdropPath: nil,
        genres: [],
        releaseYear: nil,
        voteAverage: nil,
        voteCount: nil
    ))
}

private func testContext() throws -> DecisionCandidateContext {
    try #require(DecisionCandidateContext(
        region: .spain,
        selectedProviderIDs: [8, 119]
    ))
}

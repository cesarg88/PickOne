import Foundation
@testable import PickOne
import Testing

@MainActor
@Suite("Home display localization", .serialized)
struct HomeDisplayLocalizationViewModelTests {
    @Test("Changing language reprojects the same set without a new Pick observation")
    func languageChangePreservesPickAndSession() async throws {
        let snapshot = try HomeDecisionTestFixtures.snapshot()
        let useCase = LocalizedHomeUseCase(results: [.usable(snapshot)])
        let metadata = LocalizedHomeMetadata()
        let repository = LocalViewingDecisionRepository(store: MemoryViewingDecisionStore())
        let pick = HomePickViewModel(manage: ManageViewingDecision(repository: repository))
        let sut = HomeDecisionViewModel(
            threeForTonight: useCase, getMovieDisplayMetadata: metadata, pickModel: pick
        )

        sut.setContentLocale(MovieContentLocale.english.locale)
        sut.load()
        await waitForTitle("English 101", in: sut)
        pick.showHome()
        pick.setActive(true)
        await pick.waitForPendingOperations()
        pick.pick(movieID: 101)
        await pick.waitForPendingOperations()
        let before = try await repository.snapshot()

        sut.setContentLocale(MovieContentLocale.spanish.locale)
        await waitForTitle("Español 101", in: sut)
        await pick.waitForPendingOperations()
        let after = try await repository.snapshot()

        #expect(await useCase.callCount == 1)
        #expect(after.sessions == before.sessions)
        #expect(after.decisions == before.decisions)
        #expect(pick.activeDecision?.id == before.activeDecision?.id)
    }

    @Test("Late response for prior language cannot replace current labels")
    func staleLanguageResponseIsIgnored() async throws {
        let snapshot = try HomeDecisionTestFixtures.snapshot()
        let useCase = LocalizedHomeUseCase(results: [.usable(snapshot)])
        let gate = LocalizedHomeGate()
        let metadata = LocalizedHomeMetadata(spanishGate: gate)
        let sut = HomeDecisionViewModel(threeForTonight: useCase, getMovieDisplayMetadata: metadata)

        sut.setContentLocale(MovieContentLocale.spanish.locale)
        sut.load()
        await metadata.waitForSpanishRequest()
        sut.setContentLocale(MovieContentLocale.english.locale)
        await waitForTitle("English 101", in: sut)
        await gate.open()
        await Task.yield()

        #expect(visibleTitle(in: sut) == "English 101")
        #expect(await useCase.callCount == 1)
    }

    @Test("Late response for prior set cannot replace a refreshed set")
    func staleSetResponseIsIgnored() async throws {
        let first = try HomeDecisionTestFixtures.snapshot()
        let second = try HomeDecisionTestFixtures.snapshot(
            recommendations: [HomeDecisionTestFixtures.recommendation(movieID: 102)],
            setID: UUID()
        )
        let useCase = LocalizedHomeUseCase(results: [.usable(first), .usable(second)])
        let gate = LocalizedHomeGate()
        let metadata = LocalizedHomeMetadata(blockedMovieID: 101, movieGate: gate)
        let sut = HomeDecisionViewModel(threeForTonight: useCase, getMovieDisplayMetadata: metadata)

        sut.setContentLocale(MovieContentLocale.english.locale)
        sut.load()
        await metadata.waitForBlockedMovieRequest()
        sut.refresh()
        await waitForTitle("English 102", in: sut)
        await gate.open()
        await Task.yield()

        #expect(visibleTitle(in: sut) == "English 102")
        #expect(await useCase.callCount == 2)
    }

    @Test("Restored set uses selected language without regenerating recommendations")
    func restoredSetProjectsSelectedLanguage() async throws {
        let snapshot = try HomeDecisionTestFixtures.snapshot()
        let useCase = LocalizedHomeUseCase(results: [.usable(snapshot), .usable(snapshot)])
        let metadata = LocalizedHomeMetadata()
        let first = HomeDecisionViewModel(threeForTonight: useCase, getMovieDisplayMetadata: metadata)
        first.setContentLocale(MovieContentLocale.english.locale)
        first.load()
        await waitForTitle("English 101", in: first)

        let relaunched = HomeDecisionViewModel(threeForTonight: useCase, getMovieDisplayMetadata: metadata)
        relaunched.setContentLocale(MovieContentLocale.spanish.locale)
        relaunched.load()
        await waitForTitle("Español 101", in: relaunched)

        #expect(await useCase.callCount == 2)
        #expect(visibleTitle(in: relaunched) == "Español 101")
    }

    private func visibleTitle(in model: HomeDecisionViewModel) -> String? {
        guard case let .loaded(set, _, _) = model.state else { return nil }
        return set.items.first?.title
    }

    private func waitForTitle(_ expected: String, in model: HomeDecisionViewModel) async {
        for _ in 0 ..< 1000 {
            if visibleTitle(in: model) == expected { return }
            await Task.yield()
        }
        Issue.record("Expected Home title \(expected), got \(visibleTitle(in: model) ?? "none")")
    }
}

private actor LocalizedHomeUseCase: ThreeForTonightUseCase {
    private var results: [ThreeForTonightResult]
    private(set) var callCount = 0

    init(results: [ThreeForTonightResult]) {
        self.results = results
    }

    func load() throws -> ThreeForTonightResult {
        try next()
    }

    func refresh() throws -> ThreeForTonightResult {
        try next()
    }

    func repairAfterEligibilityChange(_: DecisionEligibilityChange) throws -> ThreeForTonightResult {
        try next()
    }

    func reconcileAfterViewerStateChange(_: DecisionViewerStateChange) throws -> ThreeForTonightResult {
        try next()
    }

    private func next() throws -> ThreeForTonightResult {
        callCount += 1
        guard !results.isEmpty else { throw LocalizedHomeError.missingResult }
        return results.removeFirst()
    }
}

private actor LocalizedHomeMetadata: GetMovieDisplayMetadataUseCase {
    private let spanishGate: LocalizedHomeGate?
    private let blockedMovieID: Int?
    private let movieGate: LocalizedHomeGate?
    private var spanishRequested = false
    private var blockedMovieRequested = false

    init(spanishGate: LocalizedHomeGate? = nil, blockedMovieID: Int? = nil, movieGate: LocalizedHomeGate? = nil) {
        self.spanishGate = spanishGate
        self.blockedMovieID = blockedMovieID
        self.movieGate = movieGate
    }

    func execute(movieID: Int, contentLocale: MovieContentLocale) async throws -> MovieDisplayMetadata {
        if contentLocale == .spanish, let spanishGate {
            spanishRequested = true
            await spanishGate.wait()
        }
        if movieID == blockedMovieID, let movieGate {
            blockedMovieRequested = true
            await movieGate.wait()
        }
        let title = contentLocale == .spanish ? "Español \(movieID)" : "English \(movieID)"
        return MovieDisplayMetadata(movieID: movieID, title: title, genreNames: [18: "Drama", 878: "Science Fiction"])
    }

    func waitForSpanishRequest() async {
        while !spanishRequested {
            await Task.yield()
        }
    }

    func waitForBlockedMovieRequest() async {
        while !blockedMovieRequested {
            await Task.yield()
        }
    }
}

private actor LocalizedHomeGate {
    private var continuations: [CheckedContinuation<Void, Never>] = []
    private var isOpen = false

    func wait() async {
        if isOpen { return }
        await withCheckedContinuation { continuations.append($0) }
    }

    func open() {
        isOpen = true
        let waiting = continuations
        continuations.removeAll()
        for continuation in waiting {
            continuation.resume()
        }
    }
}

private enum LocalizedHomeError: Error { case missingResult }

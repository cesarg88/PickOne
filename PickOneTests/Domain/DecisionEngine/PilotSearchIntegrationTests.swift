import Foundation
@testable import PickOne
import Testing

struct PilotSearchIntegrationTests {
    @Test(arguments: [false, true])
    func measurementFailureCannotChangeSearchOrAddRequests(fails: Bool) async throws {
        let store = MemoryViewingDecisionStore()
        if fails { store.failure = "active" }
        let repository = LocalViewingDecisionRepository(store: store)
        let sink = AwaitablePilotSearchSink(repository: repository)
        let candidate = try CoordinatorTestFixtures.candidate(10)
        let candidates = CoordinatorCandidateRepository(candidatesByPage: [1: [candidate]])
        let availability =
            CoordinatorAvailabilityRepository(evidenceByMovieID: [10: CoordinatorTestFixtures.evidence(10)])
        let coordinator = CoordinatorTestFixtures.makeCoordinator(
            candidateRepository: candidates, availabilityRepository: availability,
            decisionSetRepository: CoordinatorDecisionSetRepository(loadResult: .absent),
            movieRepository: CoordinatorMovieRepository(movies: [10: CoordinatorTestFixtures.movie(10)]),
            diagnosticsSink: sink
        )
        guard case .exhausted = try await coordinator.load() else {
            Issue.record("Expected a partial exhausted set"); return
        }
        await sink.wait()
        #expect(await candidates.requestedPages == [1, 2])
        #expect(await availability.requestedMovieIDs == [10])
        let state = try await repository.snapshot()
        #expect(state.sessions.isEmpty)
        #expect(state.searchEvidence.count == (fails ? 0 : 1))
        if !fails {
            #expect(state.searchEvidence.first?.outcome == .exhausted)
            #expect(state.searchEvidence.first?.stage == .normal)
        }
    }
}

private actor AwaitablePilotSearchSink: RecommendationGenerationDiagnosticsSink {
    let repository: any ViewingDecisionRepository
    private var recorded = false
    private var continuation: CheckedContinuation<Void, Never>?
    init(repository: any ViewingDecisionRepository) {
        self.repository = repository
    }

    func record(_ diagnostics: RecommendationGenerationDiagnostics) async {
        await RecordPilotSearch(repository: repository).record(diagnostics)
        recorded = true
        continuation?.resume()
        continuation = nil
    }

    func wait() async {
        if recorded { return }
        await withCheckedContinuation { continuation = $0 }
    }
}

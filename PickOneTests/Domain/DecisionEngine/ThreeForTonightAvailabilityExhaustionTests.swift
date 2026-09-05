@testable import PickOne
import Testing

@Suite("Three for Tonight conclusive exhaustion")
struct AvailabilityExhaustionTests {
    @Test("partial Availability failure prevents exhaustion and exposes only the prior safe set")
    func unresolvedAvailabilityPreventsPartialExhaustion() async throws {
        let source = try CoordinatorTestFixtures.envelope(currentMovieIDs: [10])
        let recalled = try [20, 21].map(CoordinatorTestFixtures.candidate)
        let decisionSets = CoordinatorDecisionSetRepository(loadResult: .available(source))
        let sut = CoordinatorTestFixtures.makeCoordinator(
            candidateRepository: CoordinatorCandidateRepository(
                candidatesByPage: [1: recalled]
            ),
            availabilityRepository: CoordinatorAvailabilityRepository(
                evidenceByMovieID: [
                    10: CoordinatorTestFixtures.evidence(10),
                    20: CoordinatorTestFixtures.evidence(20),
                ],
                failingMovieIDs: [21]
            ),
            decisionSetRepository: decisionSets,
            movieRepository: CoordinatorMovieRepository(movies: Dictionary(
                uniqueKeysWithValues: [10, 20, 21].map {
                    ($0, CoordinatorTestFixtures.movie($0))
                }
            ))
        )

        guard case let .retryableFailure(reason, retained) = try await sut.refresh() else {
            Issue.record("Expected unresolved Availability failure")
            return
        }

        #expect(reason == .generationUnavailable)
        #expect(retained?.decisionSet.recommendations.map(\.display.movieID) == [10])
        #expect(await decisionSets.load() == .available(source))
        #expect(await decisionSets.replacements.isEmpty)
    }

    @Test("three resolved recommendations may succeed beside an unrelated Availability failure")
    func completeSetCanIgnoreUnrelatedAvailabilityFailure() async throws {
        let recalled = try [20, 21, 22, 23].map(CoordinatorTestFixtures.candidate)
        let decisionSets = CoordinatorDecisionSetRepository(loadResult: .absent)
        let sut = CoordinatorTestFixtures.makeCoordinator(
            candidateRepository: CoordinatorCandidateRepository(
                candidatesByPage: [1: recalled]
            ),
            availabilityRepository: CoordinatorAvailabilityRepository(
                evidenceByMovieID: Dictionary(uniqueKeysWithValues: [20, 21, 22].map {
                    ($0, CoordinatorTestFixtures.evidence($0))
                }),
                failingMovieIDs: [23]
            ),
            decisionSetRepository: decisionSets,
            movieRepository: CoordinatorMovieRepository(movies: Dictionary(
                uniqueKeysWithValues: recalled.map {
                    ($0.movieID, CoordinatorTestFixtures.movie($0.movieID))
                }
            ))
        )

        guard case let .usable(snapshot) = try await sut.load() else {
            Issue.record("Expected complete set")
            return
        }

        #expect(Set(snapshot.decisionSet.recommendations.map(\.display.movieID)) == [20, 21, 22])
        #expect(await decisionSets.load() == .available(snapshot.decisionSet))
    }

    @Test("rollover diagnostics contain one duration for the complete release loop")
    func rolloverRecordsOneCompleteStageDuration() async throws {
        let candidate = try CoordinatorTestFixtures.candidate(10)
        let source = try emptyEnvelope(recentlyShownMovieIDs: [10])
        let diagnostics = RecordingRecommendationDiagnosticsSink()
        let sut = CoordinatorTestFixtures.makeCoordinator(
            candidateRepository: CoordinatorCandidateRepository(
                candidatesByPage: [1: [candidate]]
            ),
            availabilityRepository: CoordinatorAvailabilityRepository(
                evidenceByMovieID: [10: CoordinatorTestFixtures.evidence(10)]
            ),
            decisionSetRepository: CoordinatorDecisionSetRepository(
                loadResult: .available(source)
            ),
            movieRepository: CoordinatorMovieRepository(
                movies: [10: CoordinatorTestFixtures.movie(10)]
            ),
            diagnosticsSink: diagnostics
        )

        guard case .exhausted = try await sut.refresh() else {
            Issue.record("Expected conclusive rollover exhaustion")
            return
        }

        let snapshot = try #require(await diagnostics.firstSnapshot())
        #expect(snapshot.highestRecallStage == .rollover)
        #expect(snapshot.recallStageDurations.map(\.stage) == [.normal, .rollover])
    }

    private func emptyEnvelope(
        recentlyShownMovieIDs: [Int]
    ) throws -> PersistedDecisionSet {
        let source = try CoordinatorTestFixtures.envelope(
            currentMovieIDs: [],
            shownMovieIDs: Set(recentlyShownMovieIDs)
        )
        return try PersistedDecisionSet(
            id: source.id,
            generatedAt: source.generatedAt,
            engineModelVersion: source.engineModelVersion,
            cycle: DecisionCycle(
                id: source.cycle.id,
                identitySignature: source.cycle.identitySignature,
                history: RecommendationHistory(
                    allShownMovieIDs: Set(recentlyShownMovieIDs),
                    recentlyShownMovieIDs: recentlyShownMovieIDs,
                    suppressionEpochID: source.cycle.history.suppressionEpochID
                )
            ),
            sourceViewerStateSnapshotID: source.sourceViewerStateSnapshotID,
            searchPolicyVersion: source.searchPolicyVersion,
            outcome: source.outcome,
            region: source.region,
            selectedProviderIDs: source.selectedProviderIDs,
            recommendations: []
        )
    }
}

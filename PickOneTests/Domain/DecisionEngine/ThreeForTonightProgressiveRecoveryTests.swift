import Foundation
@testable import PickOne
import Synchronization
import Testing

@Suite("Three for Tonight progressive recovery")
struct ThreeForTonightProgressiveRecoveryTests {
    @Test("recall expands from pages 1 through 6 and stops on empty page 8")
    func expandsIntoFirstRecoveryStage() async throws {
        let filler = try CoordinatorTestFixtures.candidate(90)
        let winners = try [100, 101, 102].map(CoordinatorTestFixtures.candidate)
        var pages = Dictionary(
            uniqueKeysWithValues: (1 ... 6).map { ($0, [filler]) }
        )
        pages[7] = winners
        let candidates = CoordinatorCandidateRepository(candidatesByPage: pages)
        let availability = CoordinatorAvailabilityRepository(
            evidenceByMovieID: Dictionary(
                uniqueKeysWithValues: winners.map {
                    ($0.movieID, CoordinatorTestFixtures.evidence($0.movieID))
                }
            )
        )
        let movies = CoordinatorMovieRepository(movies: Dictionary(
            uniqueKeysWithValues: winners.map {
                ($0.movieID, CoordinatorTestFixtures.movie($0.movieID))
            }
        ))
        let diagnostics = RecordingRecommendationDiagnosticsSink()
        let sut = CoordinatorTestFixtures.makeCoordinator(
            candidateRepository: candidates,
            availabilityRepository: availability,
            decisionSetRepository: CoordinatorDecisionSetRepository(loadResult: .absent),
            movieRepository: movies,
            diagnosticsSink: diagnostics
        )

        let result = try await sut.load()
        guard case let .usable(snapshot) = result else {
            Issue.record("Expected a complete set")
            return
        }

        #expect(await candidates.requestedPages == Array(1 ... 8))
        #expect(Set(snapshot.decisionSet.recommendations.map(\.display.movieID)) == [100, 101, 102])
        let recorded = try #require(await diagnostics.snapshots.first)
        #expect(recorded.highestRecallStage == .firstExpansion)
        #expect(recorded.discoverPageRequestCount == 8)
        #expect(recorded.uniqueRecalledCandidateCount == 4)
        #expect(recorded.candidateAvailabilityCheckCount == 4)
        #expect(recorded.maximumSimultaneousDiscoverRequests == 1)
        #expect(recorded.maximumSimultaneousAvailabilityRequests <= 8)
        #expect(diagnosticFieldNames().isDisjoint(with: sensitiveDiagnosticNames))
    }

    @Test("a partial credible set is typed exhaustion rather than failure")
    func partialSetIsTypedExhaustion() async throws {
        let candidate = try CoordinatorTestFixtures.candidate(10)
        let sut = CoordinatorTestFixtures.makeCoordinator(
            candidateRepository: CoordinatorCandidateRepository(
                candidatesByPage: [1: [candidate]]
            ),
            availabilityRepository: CoordinatorAvailabilityRepository(
                evidenceByMovieID: [10: CoordinatorTestFixtures.evidence(10)]
            ),
            decisionSetRepository: CoordinatorDecisionSetRepository(loadResult: .absent),
            movieRepository: CoordinatorMovieRepository(
                movies: [10: CoordinatorTestFixtures.movie(10)]
            )
        )

        guard case let .exhausted(exhaustion) = try await sut.load() else {
            Issue.record("Expected typed partial exhaustion")
            return
        }

        #expect(exhaustion.snapshot.decisionSet.recommendations.count == 1)
        #expect(!exhaustion.canRefresh)
    }

    @Test("exhausted refresh retains a proven-safe active set")
    func exhaustedRefreshRetainsActiveSet() async throws {
        let source = try CoordinatorTestFixtures.envelope(
            currentMovieIDs: [10, 11, 12]
        )
        let sut = CoordinatorTestFixtures.makeCoordinator(
            candidateRepository: CoordinatorCandidateRepository(),
            availabilityRepository: CoordinatorAvailabilityRepository(),
            decisionSetRepository: CoordinatorDecisionSetRepository(
                loadResult: .available(source)
            )
        )

        guard case let .exhausted(exhaustion) = try await sut.refresh() else {
            Issue.record("Expected retained-set exhaustion")
            return
        }

        #expect(exhaustion.snapshot.decisionSet.recommendations.map(\.display.movieID) == [10, 11, 12])
        #expect(exhaustion.snapshot.decisionSet.outcome.isExhausted)
    }

    @Test("fresh zero exhaustion survives relaunch and expires at exactly 24 hours")
    func zeroExhaustionFreshnessAndExplicitRetry() async throws {
        let startedAt = Date(timeIntervalSince1970: 1000)
        let clock = MutableDecisionSetClock(now: startedAt)
        let candidates = CoordinatorCandidateRepository()
        let decisionSets = CoordinatorDecisionSetRepository(loadResult: .absent)
        let sut = CoordinatorTestFixtures.makeCoordinator(
            candidateRepository: candidates,
            availabilityRepository: CoordinatorAvailabilityRepository(),
            decisionSetRepository: decisionSets,
            clock: clock
        )

        guard case let .exhausted(initial) = try await sut.load() else {
            Issue.record("Expected zero exhaustion")
            return
        }
        #expect(initial.snapshot.decisionSet.recommendations.isEmpty)
        #expect(await candidates.requestedPages == [1])

        _ = try await sut.load()
        _ = try await sut.refresh()
        #expect(await candidates.requestedPages == [1])

        clock.setNow(startedAt.addingTimeInterval(24 * 60 * 60))
        guard case let .exhausted(expiredRetry) = try await sut.refresh() else {
            Issue.record("Expected successful re-exhaustion")
            return
        }
        #expect(await candidates.requestedPages == [1, 1])
        #expect(expiredRetry.snapshot.decisionSet.outcome == .exhausted(
            exhaustedAt: startedAt.addingTimeInterval(24 * 60 * 60)
        ))
        #expect(!expiredRetry.canRefresh)
    }

    @Test("never-shown candidates survive three-ID oldest-first rollover")
    func neverShownPriorityAndOldestRollover() async throws {
        let old = try CoordinatorTestFixtures.candidate(10)
        let neverShown = try [100, 101].map(CoordinatorTestFixtures.candidate)
        var pages = Dictionary(
            uniqueKeysWithValues: (1 ... 20).map { ($0, [old]) }
        )
        pages[1] = [old] + neverShown
        let source = try envelope(
            currentMovieIDs: [],
            history: RecommendationHistory(
                allShownMovieIDs: [10, 11, 12, 13],
                recentlyShownMovieIDs: [10, 11, 12, 13],
                suppressionEpochID: .legacyCompatibility
            )
        )
        let availability = [10, 100, 101].reduce(into: [Int: VerifiedAvailabilityEvidence]()) {
            $0[$1] = CoordinatorTestFixtures.evidence($1)
        }
        let movies = [10, 100, 101].reduce(into: [Int: Movie]()) {
            $0[$1] = CoordinatorTestFixtures.movie($1)
        }
        let candidates = CoordinatorCandidateRepository(candidatesByPage: pages)
        let decisionSets = CoordinatorDecisionSetRepository(loadResult: .available(source))
        let sut = CoordinatorTestFixtures.makeCoordinator(
            candidateRepository: candidates,
            availabilityRepository: CoordinatorAvailabilityRepository(
                evidenceByMovieID: availability
            ),
            decisionSetRepository: decisionSets,
            movieRepository: CoordinatorMovieRepository(movies: movies)
        )

        guard case let .usable(snapshot) = try await sut.refresh() else {
            Issue.record("Expected rollover to fill the set")
            return
        }

        #expect(await candidates.requestedPages == Array(1 ... 20))
        #expect(Set(snapshot.decisionSet.recommendations.map(\.display.movieID)) == [10, 100, 101])
        #expect(snapshot.decisionSet.cycle.history.allShownMovieIDs == [10, 11, 12, 13, 100, 101])
        #expect(!snapshot.decisionSet.cycle.history.recentlyShownMovieIDs.contains(11))
        #expect(!snapshot.decisionSet.cycle.history.recentlyShownMovieIDs.contains(12))
    }

    @Test("reaction reconciliation preserves every unaffected credible member")
    func reactionReconciliationRetainsCredibleMembers() async throws {
        let oldProfile = CoordinatorTestFixtures.sparseProfile()
        let newProfile = profile(reactions: [155: .likeIt])
        let source = try CoordinatorTestFixtures.envelope(
            currentMovieIDs: [10, 11, 12],
            profile: oldProfile
        )
        let reaction = try viewerState(movieID: 155, reaction: .likeIt)
        let availability = [10, 11, 12].reduce(into: [Int: VerifiedAvailabilityEvidence]()) {
            $0[$1] = CoordinatorTestFixtures.evidence($1)
        }
        let movies = [10, 11, 12, 155].reduce(into: [Int: Movie]()) {
            $0[$1] = CoordinatorTestFixtures.movie($1)
        }
        let candidates = CoordinatorCandidateRepository()
        let sut = CoordinatorTestFixtures.makeCoordinator(
            profile: newProfile,
            candidateRepository: candidates,
            availabilityRepository: CoordinatorAvailabilityRepository(
                evidenceByMovieID: availability
            ),
            decisionSetRepository: CoordinatorDecisionSetRepository(
                loadResult: .available(source)
            ),
            movieRepository: CoordinatorMovieRepository(movies: movies),
            viewerMovieStates: [reaction]
        )
        let change = try #require(DecisionViewerStateChange(
            movieID: 155,
            impact: .tasteChanged,
            snapshotID: CoordinatorViewerMovieStateRepository.defaultSnapshotID
        ))

        guard case let .usable(snapshot) = try await sut
            .reconcileAfterViewerStateChange(change)
        else {
            Issue.record("Expected stable reconciliation")
            return
        }

        #expect(Set(snapshot.decisionSet.recommendations.map(\.display.movieID)) == [10, 11, 12])
        #expect(snapshot.decisionSet.cycle.id != source.cycle.id)
        #expect(await candidates.requestedPages.isEmpty)
    }
}

private extension PersistedDecisionSetOutcome {
    var isExhausted: Bool {
        if case .exhausted = self { return true }
        return false
    }
}

private extension ThreeForTonightProgressiveRecoveryTests {
    var sensitiveDiagnosticNames: Set<String> {
        ["movieID", "title", "provider", "profile", "feedback"]
    }

    func diagnosticFieldNames() -> Set<String> {
        Set(Mirror(reflecting: RecommendationGenerationDiagnostics(
            outcome: .usable,
            highestRecallStage: .normal,
            totalDuration: 0,
            timeToFirstUsableSet: 0,
            recallStageDurations: [],
            discoverPageRequestCount: 0,
            uniqueRecalledCandidateCount: 0,
            candidateAvailabilityCheckCount: 0,
            availabilityNetworkRequestCount: 0,
            availabilityCacheHitCount: 0,
            reactionMetadataHydrationRequestCount: 0,
            maximumSimultaneousDiscoverRequests: 0,
            maximumSimultaneousAvailabilityRequests: 0,
            maximumTasteHydrationConcurrency: 0
        )).children.compactMap(\.label))
    }

    func envelope(
        currentMovieIDs: [Int],
        history: RecommendationHistory
    ) throws -> PersistedDecisionSet {
        let base = try CoordinatorTestFixtures.envelope(
            currentMovieIDs: currentMovieIDs
        )
        return try PersistedDecisionSet(
            id: base.id,
            generatedAt: base.generatedAt,
            engineModelVersion: base.engineModelVersion,
            cycle: DecisionCycle(
                id: base.cycle.id,
                identitySignature: base.cycle.identitySignature,
                history: history
            ),
            sourceViewerStateSnapshotID: base.sourceViewerStateSnapshotID,
            searchPolicyVersion: base.searchPolicyVersion,
            outcome: base.outcome,
            region: base.region,
            selectedProviderIDs: base.selectedProviderIDs,
            recommendations: base.recommendations
        )
    }

    func profile(reactions: [Int: CalibrationReaction]) -> ViewerProfile {
        ViewerProfile(
            profileSchemaVersion: ViewerProfile.currentSchemaVersion,
            catalogID: .spainHouseholdV1,
            region: .spain,
            selectedServices: [.netflix],
            reactions: reactions
        )
    }

    func viewerState(movieID: Int, reaction: MovieReaction) throws -> ViewerMovieState {
        try ViewerMovieState(
            movieID: movieID,
            displayMetadata: MovieFeedbackMetadata(
                title: "Movie \(movieID)",
                releaseYear: 2024,
                posterPath: nil
            ),
            watchState: .watched,
            preference: .reaction(reaction),
            watchlistIntent: nil,
            stateChangedAt: .distantPast
        )
    }
}

private final class MutableDecisionSetClock: DecisionSetClock, @unchecked Sendable {
    private let value: Mutex<Date>

    init(now: Date) {
        value = Mutex(now)
    }

    func now() -> Date {
        value.withLock { $0 }
    }

    func setNow(_ now: Date) {
        value.withLock { $0 = now }
    }
}

private actor RecordingRecommendationDiagnosticsSink:
    RecommendationGenerationDiagnosticsSink
{
    private(set) var snapshots: [RecommendationGenerationDiagnostics] = []

    func record(_ diagnostics: RecommendationGenerationDiagnostics) {
        snapshots.append(diagnostics)
    }
}

import Foundation
@testable import PickOne
import Testing

@Suite("Three for Tonight Viewer State reconciliation")
struct ViewerStateReconciliationTests {
    @Test("reaction change regenerates one successor cycle with inherited shown history")
    func reactionChangeCreatesSuccessorCycle() async throws {
        let profile = profile(reactions: [155: .likeIt])
        let source = try CoordinatorTestFixtures.envelope(
            currentMovieIDs: [],
            shownMovieIDs: [10, 20],
            profile: profile
        )
        let snapshotID = ViewerStateSnapshotID(rawValue: UUID())
        let reaction = try viewerState(movieID: 155, preference: .reaction(.loveIt))
        let candidate = try CoordinatorTestFixtures.candidate(30)
        let decisionSets = CoordinatorDecisionSetRepository(loadResult: .available(source))
        let sut = CoordinatorTestFixtures.makeCoordinator(
            profile: profile,
            candidateRepository: CoordinatorCandidateRepository(
                candidatesByPage: [1: [candidate]]
            ),
            availabilityRepository: CoordinatorAvailabilityRepository(
                evidenceByMovieID: [30: CoordinatorTestFixtures.evidence(30)]
            ),
            decisionSetRepository: decisionSets,
            movieRepository: CoordinatorMovieRepository(movies: [
                30: CoordinatorTestFixtures.movie(30),
                155: CoordinatorTestFixtures.movie(155),
            ]),
            snapshotID: snapshotID,
            viewerMovieStates: [reaction]
        )
        let change = try #require(DecisionViewerStateChange(
            movieID: 155,
            impact: .tasteChanged,
            snapshotID: snapshotID
        ))

        let result = try await sut.reconcileAfterViewerStateChange(change)
        let snapshot = try #require(result.usableSnapshot)

        #expect(snapshot.decisionSet.cycle.id != source.cycle.id)
        #expect(snapshot.decisionSet.cycle.shownMovieIDs == [10, 20, 30])
        #expect(snapshot.decisionSet.sourceViewerStateSnapshotID == snapshotID)
        #expect(snapshot.decisionSet.recommendations.map(\.display.movieID) == [30])
        #expect(await decisionSets.replacements == [snapshot.decisionSet])
    }

    @Test("eligibility change repairs a stale-source set without resetting its cycle")
    func eligibilityChangeRepairsCurrentCycle() async throws {
        let profile = profile()
        let source = try CoordinatorTestFixtures.envelope(
            currentMovieIDs: [10],
            profile: profile
        )
        let snapshotID = ViewerStateSnapshotID(rawValue: UUID())
        let notInterested = try viewerState(
            movieID: 10,
            preference: .notInterested
        )
        let replacement = try CoordinatorTestFixtures.candidate(20)
        let decisionSets = CoordinatorDecisionSetRepository(loadResult: .available(source))
        let sut = CoordinatorTestFixtures.makeCoordinator(
            profile: profile,
            candidateRepository: CoordinatorCandidateRepository(
                candidatesByPage: [1: [replacement]]
            ),
            availabilityRepository: CoordinatorAvailabilityRepository(
                evidenceByMovieID: [
                    10: CoordinatorTestFixtures.evidence(10),
                    20: CoordinatorTestFixtures.evidence(20),
                ]
            ),
            decisionSetRepository: decisionSets,
            movieRepository: CoordinatorMovieRepository(movies: [
                10: CoordinatorTestFixtures.movie(10),
                20: CoordinatorTestFixtures.movie(20),
            ]),
            snapshotID: snapshotID,
            viewerMovieStates: [notInterested]
        )
        let change = try #require(DecisionViewerStateChange(
            movieID: 10,
            impact: .eligibilityChanged,
            snapshotID: snapshotID
        ))

        let result = try await sut.reconcileAfterViewerStateChange(change)
        let snapshot = try #require(result.usableSnapshot)

        #expect(snapshot.decisionSet.cycle.id == source.cycle.id)
        #expect(snapshot.decisionSet.cycle.shownMovieIDs == [10, 20])
        #expect(snapshot.decisionSet.recommendations.map(\.display.movieID) == [20])
        #expect(snapshot.decisionSet.sourceViewerStateSnapshotID == snapshotID)
    }

    @Test("semantic no-op performs no generation, repair, or persistence")
    func semanticNoOpPerformsNoWork() async throws {
        let profile = profile()
        let source = try CoordinatorTestFixtures.envelope(
            currentMovieIDs: [],
            profile: profile
        )
        let candidates = CoordinatorCandidateRepository()
        let decisionSets = CoordinatorDecisionSetRepository(loadResult: .available(source))
        let sut = CoordinatorTestFixtures.makeCoordinator(
            profile: profile,
            candidateRepository: candidates,
            availabilityRepository: CoordinatorAvailabilityRepository(),
            decisionSetRepository: decisionSets
        )
        let change = try #require(DecisionViewerStateChange(
            movieID: 10,
            impact: .none,
            snapshotID: CoordinatorViewerMovieStateRepository.defaultSnapshotID
        ))

        #expect(try await sut.reconcileAfterViewerStateChange(change) == .usable(
            ThreeForTonightSnapshot(decisionSet: source, savedMovieIDs: [])
        ))
        #expect(await candidates.requestedPages.isEmpty)
        #expect(await decisionSets.replacements.isEmpty)
    }

    @Test("incomplete Taste hydration never runs candidate recall and retains only safe content")
    func incompleteTasteHydrationRetainsSafePriorSet() async throws {
        let profile = profile()
        let source = try CoordinatorTestFixtures.envelope(
            currentMovieIDs: [10],
            profile: profile
        )
        let snapshotID = ViewerStateSnapshotID(rawValue: UUID())
        let reaction = try viewerState(movieID: 155, preference: .reaction(.loveIt))
        let candidates = CoordinatorCandidateRepository()
        let decisionSets = CoordinatorDecisionSetRepository(loadResult: .available(source))
        let sut = CoordinatorTestFixtures.makeCoordinator(
            profile: profile,
            candidateRepository: candidates,
            availabilityRepository: CoordinatorAvailabilityRepository(),
            decisionSetRepository: decisionSets,
            movieRepository: CoordinatorMovieRepository(movies: [:]),
            snapshotID: snapshotID,
            viewerMovieStates: [reaction]
        )
        let change = try #require(DecisionViewerStateChange(
            movieID: 155,
            impact: .tasteChanged,
            snapshotID: snapshotID
        ))

        let result = try await sut.reconcileAfterViewerStateChange(change)

        #expect(result == .retryableFailure(
            reason: .generationUnavailable,
            retained: ThreeForTonightSnapshot(
                decisionSet: source,
                savedMovieIDs: []
            )
        ))
        #expect(await candidates.requestedPages.isEmpty)
        #expect(await decisionSets.replacements.isEmpty)
    }

    @Test("state changed before persistence regenerates against the newest snapshot")
    func staleBeforePersistenceRegenerates() async throws {
        let current = try trustedState(snapshotID: ViewerStateSnapshotID(rawValue: UUID()))
        let latest = try trustedState(snapshotID: ViewerStateSnapshotID(rawValue: UUID()))
        let loader = MutableTrustedDecisionStateLoader(
            current: current,
            next: latest,
            switchOnMatchCall: 1
        )
        let decisionSets = CoordinatorDecisionSetRepository(loadResult: .absent)
        let sut = coordinator(
            trustedStateLoader: loader,
            decisionSetRepository: decisionSets
        )

        let result = try await sut.load()
        let snapshot = try #require(result.usableSnapshot)

        #expect(snapshot.decisionSet.sourceViewerStateSnapshotID == latest.snapshotID)
        #expect(await decisionSets.replacements.count == 1)
        #expect(await decisionSets.replacements.first?.sourceViewerStateSnapshotID == latest.snapshotID)
    }

    @Test("state changed by the persistence race makes the write unusable and regenerates")
    func staleAfterPersistenceRegenerates() async throws {
        let current = try trustedState(snapshotID: ViewerStateSnapshotID(rawValue: UUID()))
        let latest = try trustedState(snapshotID: ViewerStateSnapshotID(rawValue: UUID()))
        let loader = MutableTrustedDecisionStateLoader(current: current, next: latest)
        let decisionSets = CoordinatorDecisionSetRepository(
            loadResult: .absent,
            onReplace: loader.publishNext
        )
        let sut = coordinator(
            trustedStateLoader: loader,
            decisionSetRepository: decisionSets
        )

        let result = try await sut.load()
        let snapshot = try #require(result.usableSnapshot)
        let replacements = await decisionSets.replacements

        #expect(replacements.count == 2)
        #expect(replacements.first?.sourceViewerStateSnapshotID == current.snapshotID)
        #expect(replacements.last?.sourceViewerStateSnapshotID == latest.snapshotID)
        #expect(snapshot.decisionSet == replacements.last)
        #expect(snapshot.decisionSet.sourceViewerStateSnapshotID == latest.snapshotID)
    }

    private func coordinator(
        trustedStateLoader: any TrustedDecisionStateLoading,
        decisionSetRepository: CoordinatorDecisionSetRepository
    ) -> ThreeForTonightCoordinator {
        let movieRepository = CoordinatorMovieRepository()
        let availabilityRepository = CoordinatorAvailabilityRepository()
        return ThreeForTonightCoordinator(
            trustedStateLoader: trustedStateLoader,
            decisionSetRepository: decisionSetRepository,
            inputAssembler: AssembleDecisionEngineInput(
                candidateRepository: CoordinatorCandidateRepository(),
                movieRepository: movieRepository,
                availabilityRepository: availabilityRepository
            ),
            movieRepository: movieRepository,
            availabilityRepository: availabilityRepository,
            signer: StableDecisionCycleSigner()
        )
    }

    private func trustedState(
        snapshotID: ViewerStateSnapshotID
    ) throws -> TrustedDecisionState {
        try TrustedDecisionState(
            profile: profile(),
            viewerMovieState: ViewerMovieStateSnapshot(
                id: snapshotID,
                states: []
            )
        )
    }

    private func viewerState(
        movieID: Int,
        preference: MoviePreference
    ) throws -> ViewerMovieState {
        try ViewerMovieState(
            movieID: movieID,
            displayMetadata: MovieFeedbackMetadata(
                title: "Movie \(movieID)",
                releaseYear: 2024,
                posterPath: nil
            ),
            watchState: preference == .notInterested ? .unwatched : .watched,
            preference: preference,
            watchlistIntent: nil,
            stateChangedAt: .distantPast
        )
    }

    private func profile(
        reactions: [Int: CalibrationReaction] = [:]
    ) -> ViewerProfile {
        ViewerProfile(
            profileSchemaVersion: ViewerProfile.currentSchemaVersion,
            catalogID: .spainHouseholdV1,
            region: .spain,
            selectedServices: [.netflix],
            reactions: reactions
        )
    }
}

private extension ThreeForTonightResult {
    var usableSnapshot: ThreeForTonightSnapshot? {
        guard case let .usable(snapshot) = self else { return nil }
        return snapshot
    }
}

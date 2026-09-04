import Foundation
@testable import PickOne
import Testing

@Suite("Decision Set migration coordination")
struct DecisionSetMigrationCoordinatorTests {
    @Test("current non-empty v2 set migrates without candidate regeneration")
    func nonEmptyV2PreservesCurrentSet() async throws {
        let profile = CoordinatorTestFixtures.sparseProfile()
        let envelope = try CoordinatorTestFixtures.envelope(
            currentMovieIDs: [10, 20],
            shownMovieIDs: [1, 10, 20, 99],
            profile: profile
        )
        let source = try DecisionSetMigrationSource(legacyV2: DecisionSetV2MigrationSource(
            id: envelope.id,
            generatedAt: envelope.generatedAt,
            engineModelVersion: envelope.engineModelVersion,
            cycle: envelope.cycle,
            sourceViewerStateSnapshotID: envelope.sourceViewerStateSnapshotID,
            region: envelope.region,
            selectedProviderIDs: envelope.selectedProviderIDs,
            recommendations: envelope.recommendations
        ))
        let decisionSets = CoordinatorDecisionSetRepository(
            loadResult: .migrationRequired(source)
        )
        let candidates = CoordinatorCandidateRepository()
        let sut = CoordinatorTestFixtures.makeCoordinator(
            profile: profile,
            candidateRepository: candidates,
            availabilityRepository: CoordinatorAvailabilityRepository(),
            decisionSetRepository: decisionSets,
            snapshotID: envelope.sourceViewerStateSnapshotID
        )

        let result = try await sut.load()

        guard let snapshot = result.snapshot else {
            Issue.record("Expected the current v2 recommendations to migrate in place")
            return
        }
        #expect(snapshot.decisionSet.recommendations == envelope.recommendations)
        #expect(snapshot.decisionSet.cycle.history.allShownMovieIDs == [1, 10, 20, 99])
        #expect(snapshot.decisionSet.cycle.history.recentlyShownMovieIDs == [10, 20])
        #expect(await candidates.requestedPages.isEmpty)
        #expect(await decisionSets.replacements == [snapshot.decisionSet])
    }

    @Test("matching v1 signature retains its cycle and complete shown history")
    func matchingSignature() async throws {
        let profile = CoordinatorTestFixtures.sparseProfile()
        let signature = try currentSignature(profile: profile)
        let sourceCycleID = UUID()
        let source = try migrationSource(
            cycleID: sourceCycleID,
            signature: signature,
            shownMovieIDs: [10, 99]
        )
        let snapshotID = ViewerStateSnapshotID(rawValue: UUID())
        let decisionSets = CoordinatorDecisionSetRepository(
            loadResult: .migrationRequired(source)
        )
        let sut = try CoordinatorTestFixtures.makeCoordinator(
            profile: profile,
            candidateRepository: CoordinatorCandidateRepository(candidatesByPage: [
                1: [CoordinatorTestFixtures.candidate(20)],
            ]),
            availabilityRepository: CoordinatorAvailabilityRepository(
                evidenceByMovieID: [20: CoordinatorTestFixtures.evidence(20)]
            ),
            decisionSetRepository: decisionSets,
            movieRepository: CoordinatorMovieRepository(movies: [
                20: CoordinatorTestFixtures.movie(20),
            ]),
            snapshotID: snapshotID
        )

        let result = try await sut.load()
        guard let snapshot = result.snapshot else {
            Issue.record("Expected a persisted v2 migration result")
            return
        }

        #expect(snapshot.decisionSet.cycle.id == sourceCycleID)
        #expect(snapshot.decisionSet.cycle.shownMovieIDs == [10, 20, 99])
        #expect(snapshot.decisionSet.recommendations.map(\.display.movieID) == [20])
        #expect(snapshot.decisionSet.sourceViewerStateSnapshotID == snapshotID)
        #expect(await decisionSets.replacements == [snapshot.decisionSet])
    }

    @Test("changed v1 signature creates a successor with inherited history")
    func changedSignature() async throws {
        let profile = CoordinatorTestFixtures.sparseProfile()
        let oldSignature = try #require(
            DecisionCycleSignature(rawValue: String(repeating: "a", count: 64))
        )
        let sourceCycleID = UUID()
        let snapshotID = ViewerStateSnapshotID(rawValue: UUID())
        let decisionSets = try CoordinatorDecisionSetRepository(
            loadResult: .migrationRequired(migrationSource(
                cycleID: sourceCycleID,
                signature: oldSignature,
                shownMovieIDs: [10, 99]
            ))
        )
        let sut = CoordinatorTestFixtures.makeCoordinator(
            profile: profile,
            candidateRepository: CoordinatorCandidateRepository(),
            availabilityRepository: CoordinatorAvailabilityRepository(),
            decisionSetRepository: decisionSets,
            snapshotID: snapshotID
        )

        let result = try await sut.load()
        guard let snapshot = result.snapshot else {
            Issue.record("Expected a persisted successor cycle")
            return
        }

        let expectedSignature = try currentSignature(profile: profile)
        #expect(snapshot.decisionSet.cycle.id != sourceCycleID)
        #expect(snapshot.decisionSet.cycle.identitySignature == expectedSignature)
        #expect(snapshot.decisionSet.cycle.shownMovieIDs == [10, 99])
        #expect(snapshot.decisionSet.sourceViewerStateSnapshotID == snapshotID)
    }

    @Test("stale v2 source identity regenerates before publication")
    func staleV2Regenerates() async throws {
        let profile = CoordinatorTestFixtures.sparseProfile()
        let envelope = try CoordinatorTestFixtures.envelope(
            currentMovieIDs: [],
            shownMovieIDs: [10],
            profile: profile
        )
        let currentSnapshotID = ViewerStateSnapshotID(rawValue: UUID())
        let decisionSets = CoordinatorDecisionSetRepository(loadResult: .available(envelope))
        let sut = try CoordinatorTestFixtures.makeCoordinator(
            profile: profile,
            candidateRepository: CoordinatorCandidateRepository(candidatesByPage: [
                1: [CoordinatorTestFixtures.candidate(20)],
            ]),
            availabilityRepository: CoordinatorAvailabilityRepository(
                evidenceByMovieID: [20: CoordinatorTestFixtures.evidence(20)]
            ),
            decisionSetRepository: decisionSets,
            movieRepository: CoordinatorMovieRepository(movies: [
                20: CoordinatorTestFixtures.movie(20),
            ]),
            snapshotID: currentSnapshotID
        )

        let result = try await sut.load()
        guard let snapshot = result.snapshot else {
            Issue.record("Expected a regenerated current v2 set")
            return
        }

        #expect(snapshot.decisionSet.id != envelope.id)
        #expect(snapshot.decisionSet.cycle.id == envelope.cycle.id)
        #expect(snapshot.decisionSet.cycle.shownMovieIDs == [10, 20])
        #expect(snapshot.decisionSet.sourceViewerStateSnapshotID == currentSnapshotID)
        #expect(await decisionSets.replacements == [snapshot.decisionSet])
    }

    @Test("v1 regeneration failure publishes and persists nothing")
    func regenerationFailure() async throws {
        let profile = CoordinatorTestFixtures.sparseProfile()
        let decisionSets = try CoordinatorDecisionSetRepository(
            loadResult: .migrationRequired(migrationSource(
                cycleID: UUID(),
                signature: currentSignature(profile: profile),
                shownMovieIDs: [10]
            ))
        )
        let sut = CoordinatorTestFixtures.makeCoordinator(
            profile: profile,
            candidateRepository: CoordinatorCandidateRepository(error: .unavailable),
            availabilityRepository: CoordinatorAvailabilityRepository(),
            decisionSetRepository: decisionSets
        )

        #expect(try await sut.load() == .retryableFailure(
            reason: .recoveryFailed,
            retained: nil
        ))
        #expect(await decisionSets.replacements.isEmpty)
    }

    @Test("v2 persistence failure never publishes regenerated v1 content")
    func persistenceFailure() async throws {
        let profile = CoordinatorTestFixtures.sparseProfile()
        let decisionSets = try CoordinatorDecisionSetRepository(
            loadResult: .migrationRequired(migrationSource(
                cycleID: UUID(),
                signature: currentSignature(profile: profile),
                shownMovieIDs: [10]
            )),
            replaceError: .unavailable
        )
        let sut = CoordinatorTestFixtures.makeCoordinator(
            profile: profile,
            candidateRepository: CoordinatorCandidateRepository(),
            availabilityRepository: CoordinatorAvailabilityRepository(),
            decisionSetRepository: decisionSets
        )

        #expect(try await sut.load() == .retryableFailure(
            reason: .recoveryFailed,
            retained: nil
        ))
        #expect(await decisionSets.replacements.isEmpty)
    }

    private func currentSignature(
        profile: ViewerProfile
    ) throws -> DecisionCycleSignature {
        try StableDecisionCycleSigner().signature(for: DecisionCycleIdentity(
            engineModelVersion: .p1Model,
            profile: profile
        ))
    }

    private func migrationSource(
        cycleID: UUID,
        signature: DecisionCycleSignature,
        shownMovieIDs: Set<Int>
    ) throws -> DecisionSetMigrationSource {
        try DecisionSetMigrationSource(
            cycle: DecisionCycle(
                id: cycleID,
                identitySignature: signature,
                shownMovieIDs: shownMovieIDs
            ),
            region: .spain,
            selectedProviderIDs: [PilotStreamingService.netflix.providerID],
            recommendations: []
        )
    }
}

private extension ThreeForTonightResult {
    var snapshot: ThreeForTonightSnapshot? {
        switch self {
            case let .usable(snapshot): snapshot
            case let .exhausted(exhaustion): exhaustion.snapshot
            case .retryableFailure: nil
        }
    }
}

@testable import PickOne
import Testing

@Suite("Three for Tonight direct repair")
struct ThreeForTonightCoordinatorRepairTests {
    @Test("direct Watchlist repair replaces a watched current member")
    func directWatchlistRepair() async throws {
        let envelope = try CoordinatorTestFixtures.envelope(currentMovieIDs: [10])
        let replacement = try CoordinatorTestFixtures.candidate(20)
        let availability = CoordinatorAvailabilityRepository(evidenceByMovieID: [
            10: CoordinatorTestFixtures.evidence(10),
            20: CoordinatorTestFixtures.evidence(20),
        ])
        let decisionSets = CoordinatorDecisionSetRepository(loadResult: .available(envelope))
        let sut = try CoordinatorTestFixtures.makeCoordinator(
            candidateRepository: CoordinatorCandidateRepository(candidatesByPage: [1: [replacement]]),
            availabilityRepository: availability,
            decisionSetRepository: decisionSets,
            movieRepository: CoordinatorMovieRepository(movies: [
                10: CoordinatorTestFixtures.movie(10),
                20: CoordinatorTestFixtures.movie(20),
            ]),
            viewerMovieStates: [CoordinatorTestFixtures.watchedState(10)]
        )
        let change = try #require(DecisionEligibilityChange(movieID: 10, cause: .watchlist))

        let result = try await sut.repairAfterEligibilityChange(change)
        let snapshot = try #require(result.usableSnapshot)

        #expect(snapshot.decisionSet.recommendations.map(\.display.movieID) == [20])
        #expect(snapshot.decisionSet.cycle.id == envelope.cycle.id)
        #expect(snapshot.decisionSet.cycle.shownMovieIDs == [10, 20])
        #expect(await decisionSets.replacements == [snapshot.decisionSet])
    }

    @Test("availability repair reloads evidence and returns an honest smaller set")
    func directAvailabilityRepairReturnsSmallerSet() async throws {
        let envelope = try CoordinatorTestFixtures.envelope(currentMovieIDs: [10, 11])
        let availability = CoordinatorAvailabilityRepository(evidenceByMovieID: [
            11: CoordinatorTestFixtures.evidence(11),
        ])
        let decisionSets = CoordinatorDecisionSetRepository(loadResult: .available(envelope))
        let sut = CoordinatorTestFixtures.makeCoordinator(
            candidateRepository: CoordinatorCandidateRepository(),
            availabilityRepository: availability,
            decisionSetRepository: decisionSets,
            movieRepository: CoordinatorMovieRepository(movies: [
                10: CoordinatorTestFixtures.movie(10),
                11: CoordinatorTestFixtures.movie(11),
            ])
        )
        let change = try #require(DecisionEligibilityChange(movieID: 10, cause: .availability))

        let result = try await sut.repairAfterEligibilityChange(change)
        let snapshot = try #require(result.usableSnapshot)

        #expect(snapshot.decisionSet.recommendations.map(\.display.movieID) == [11])
        #expect(snapshot.decisionSet.recommendations.map(\.role) == [.safeChoice])
        #expect(await availability.requests.contains(CoordinatorAvailabilityRequest(
            movieID: 10,
            policy: .reloadIgnoringCache
        )))
    }

    @Test("availability repair may persist an honest empty set")
    func directAvailabilityRepairReturnsEmptySet() async throws {
        let envelope = try CoordinatorTestFixtures.envelope(currentMovieIDs: [10])
        let decisionSets = CoordinatorDecisionSetRepository(loadResult: .available(envelope))
        let sut = CoordinatorTestFixtures.makeCoordinator(
            candidateRepository: CoordinatorCandidateRepository(),
            availabilityRepository: CoordinatorAvailabilityRepository(),
            decisionSetRepository: decisionSets,
            movieRepository: CoordinatorMovieRepository(movies: [
                10: CoordinatorTestFixtures.movie(10),
            ])
        )
        let change = try #require(DecisionEligibilityChange(movieID: 10, cause: .availability))

        let result = try await sut.repairAfterEligibilityChange(change)
        let snapshot = try #require(result.usableSnapshot)

        #expect(snapshot.decisionSet.recommendations.isEmpty)
        #expect(snapshot.decisionSet.cycle.id == envelope.cycle.id)
        #expect(snapshot.decisionSet.cycle.shownMovieIDs == [10])
        #expect(await decisionSets.replacements == [snapshot.decisionSet])
    }

    @Test("a repair change for an old shown movie never makes it selectable")
    func oldShownChangeStaysExcluded() async throws {
        let envelope = try CoordinatorTestFixtures.envelope(
            currentMovieIDs: [10],
            shownMovieIDs: [10, 20]
        )
        let oldCandidate = try CoordinatorTestFixtures.candidate(20)
        let availability = CoordinatorAvailabilityRepository(evidenceByMovieID: [
            10: CoordinatorTestFixtures.evidence(10),
            20: CoordinatorTestFixtures.evidence(20),
        ])
        let decisionSets = CoordinatorDecisionSetRepository(loadResult: .available(envelope))
        let sut = CoordinatorTestFixtures.makeCoordinator(
            candidateRepository: CoordinatorCandidateRepository(candidatesByPage: [1: [oldCandidate]]),
            availabilityRepository: availability,
            decisionSetRepository: decisionSets,
            movieRepository: CoordinatorMovieRepository(movies: [
                10: CoordinatorTestFixtures.movie(10),
                20: CoordinatorTestFixtures.movie(20),
            ])
        )
        let change = try #require(DecisionEligibilityChange(movieID: 20, cause: .availability))

        let result = try await sut.repairAfterEligibilityChange(change)
        let snapshot = try #require(result.usableSnapshot)

        #expect(snapshot.decisionSet.recommendations.map(\.display.movieID) == [10])
        #expect(snapshot.decisionSet.cycle.shownMovieIDs == [10, 20])
    }

    @Test("repair failure retains only members proven safe after rehydration")
    func failedRepairUsesRehydratedSafeRetainedSet() async throws {
        let envelope = try CoordinatorTestFixtures.envelope(currentMovieIDs: [10, 11, 12])
        let availability = CoordinatorAvailabilityRepository(evidenceByMovieID: [
            10: CoordinatorTestFixtures.evidence(10),
            12: CoordinatorTestFixtures.evidence(12),
        ])
        let decisionSets = CoordinatorDecisionSetRepository(
            loadResult: .available(envelope),
            replaceError: .unavailable
        )
        let sut = CoordinatorTestFixtures.makeCoordinator(
            candidateRepository: CoordinatorCandidateRepository(),
            availabilityRepository: availability,
            decisionSetRepository: decisionSets,
            movieRepository: CoordinatorMovieRepository(movies: [
                10: CoordinatorTestFixtures.movie(10),
                11: CoordinatorTestFixtures.movie(11),
                12: CoordinatorTestFixtures.movie(12),
            ])
        )
        let change = try #require(DecisionEligibilityChange(movieID: 10, cause: .availability))

        let result = try await sut.repairAfterEligibilityChange(change)
        guard case let .retryableFailure(reason, retained) = result else {
            Issue.record("Expected a retryable persistence failure")
            return
        }

        #expect(reason == .persistenceFailed)
        #expect(retained?.decisionSet.recommendations.map(\.display.movieID) == [10, 12])
        #expect(retained?.decisionSet.recommendations.map(\.role) == [.safeChoice, .stretchChoice])
        #expect(await decisionSets.replacements.isEmpty)
    }

    @Test("rehydration failure excludes an earlier member already proven unsafe")
    func rehydrationFailureExcludesEarlierUnsafeMember() async throws {
        let envelope = try CoordinatorTestFixtures.envelope(currentMovieIDs: [10, 11])
        let decisionSets = CoordinatorDecisionSetRepository(loadResult: .available(envelope))
        let sut = CoordinatorTestFixtures.makeCoordinator(
            candidateRepository: CoordinatorCandidateRepository(),
            availabilityRepository: CoordinatorAvailabilityRepository(),
            decisionSetRepository: decisionSets,
            movieRepository: CoordinatorMovieRepository(movies: [
                10: CoordinatorTestFixtures.movie(10),
            ])
        )
        let change = try #require(DecisionEligibilityChange(movieID: 11, cause: .availability))

        let result = try await sut.repairAfterEligibilityChange(change)
        guard case let .retryableFailure(reason, retained) = result else {
            Issue.record("Expected a retryable rehydration failure")
            return
        }

        #expect(reason == .repairFailed)
        #expect(retained?.decisionSet.recommendations.isEmpty == true)
        #expect(await decisionSets.replacements.isEmpty)
    }
}

private extension ThreeForTonightResult {
    var usableSnapshot: ThreeForTonightSnapshot? {
        switch self {
            case let .usable(snapshot): snapshot
            case let .exhausted(exhaustion): exhaustion.snapshot
            case .retryableFailure: nil
        }
    }
}

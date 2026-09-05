@testable import PickOne
import Testing

@Suite("Three for Tonight caller cancellation")
struct ThreeForTonightCallerCancellationTests {
    @Test("cancellation after replacement restores the previous decision set")
    func cancellationAfterReplaceRollsBack() async throws {
        let candidate = try CoordinatorTestFixtures.candidate(10)
        let decisionSets = CoordinatorDecisionSetRepository(
            loadResult: .absent,
            delayAfterReplace: .seconds(30)
        )
        let sut = CoordinatorTestFixtures.makeCoordinator(
            candidateRepository: CoordinatorCandidateRepository(
                candidatesByPage: [1: [candidate]]
            ),
            availabilityRepository: CoordinatorAvailabilityRepository(
                evidenceByMovieID: [10: CoordinatorTestFixtures.evidence(10)]
            ),
            decisionSetRepository: decisionSets,
            movieRepository: CoordinatorMovieRepository(
                movies: [10: CoordinatorTestFixtures.movie(10)]
            )
        )
        let caller = Task { try await sut.load() }
        try await waitForReplacement(in: decisionSets)

        caller.cancel()

        await #expect(throws: CancellationError.self) {
            _ = try await caller.value
        }
        #expect(await decisionSets.load() == .absent)
        #expect(await decisionSets.inFlightPublicationCount == 0)
    }

    @Test("cancellation surfaces a failed persistence restoration")
    func cancellationSurfacesRestorationFailure() async throws {
        let candidate = try CoordinatorTestFixtures.candidate(10)
        let decisionSets = CoordinatorDecisionSetRepository(
            loadResult: .absent,
            restoreError: .unavailable,
            delayAfterReplace: .seconds(30)
        )
        let sut = CoordinatorTestFixtures.makeCoordinator(
            candidateRepository: CoordinatorCandidateRepository(
                candidatesByPage: [1: [candidate]]
            ),
            availabilityRepository: CoordinatorAvailabilityRepository(
                evidenceByMovieID: [10: CoordinatorTestFixtures.evidence(10)]
            ),
            decisionSetRepository: decisionSets,
            movieRepository: CoordinatorMovieRepository(
                movies: [10: CoordinatorTestFixtures.movie(10)]
            )
        )
        let caller = Task { try await sut.load() }
        try await waitForReplacement(in: decisionSets)

        caller.cancel()

        #expect(try await caller.value == .retryableFailure(
            reason: .persistenceFailed,
            retained: nil
        ))
        #expect(await decisionSets.load() == .absent)
    }

    @Test("a replacement starts from committed history while prior staging is cancelled")
    func overlappingReplacementDoesNotInheritProvisionalHistory() async throws {
        let source = try CoordinatorTestFixtures.envelope(currentMovieIDs: [10])
        let firstCandidate = try CoordinatorTestFixtures.candidate(20)
        let secondCandidate = try CoordinatorTestFixtures.candidate(30)
        let decisionSets = CoordinatorDecisionSetRepository(
            loadResult: .available(source),
            delayAfterReplace: .seconds(30)
        )
        let sut = CoordinatorTestFixtures.makeCoordinator(
            candidateRepository: CoordinatorCandidateRepository(
                candidateBatchesByPage: [1: [[firstCandidate], [secondCandidate]]]
            ),
            availabilityRepository: CoordinatorAvailabilityRepository(
                evidenceByMovieID: Dictionary(uniqueKeysWithValues: [10, 20, 30].map {
                    ($0, CoordinatorTestFixtures.evidence($0))
                })
            ),
            decisionSetRepository: decisionSets,
            movieRepository: CoordinatorMovieRepository(
                movies: Dictionary(uniqueKeysWithValues: [10, 20, 30].map {
                    ($0, CoordinatorTestFixtures.movie($0))
                })
            )
        )
        let first = Task { try await sut.refresh() }
        try await waitForReplacement(in: decisionSets, count: 1)

        let second = try await sut.refresh()

        await #expect(throws: CancellationError.self) {
            _ = try await first.value
        }
        guard case let .exhausted(exhaustion) = second else {
            Issue.record("Expected the second partial replacement to commit")
            return
        }
        let snapshot = exhaustion.snapshot
        #expect(snapshot.decisionSet.recommendations.map(\.display.movieID) == [30])
        #expect(snapshot.decisionSet.cycle.history.allShownMovieIDs == [10, 30])
        #expect(!snapshot.decisionSet.cycle.history.allShownMovieIDs.contains(20))
        #expect(await decisionSets.load() == .available(snapshot.decisionSet))
        #expect(await decisionSets.inFlightPublicationCount == 0)
    }

    @Test(
        "caller cancellation stops the owned operation",
        arguments: CoordinatorInvocation.allCases
    )
    func callerCancellationStopsOwnedOperation(
        invocation: CoordinatorInvocation
    ) async throws {
        let candidates = CoordinatorCandidateRepository(delay: .milliseconds(50))
        let decisionSets = CoordinatorDecisionSetRepository(loadResult: .absent)
        let sut = CoordinatorTestFixtures.makeCoordinator(
            candidateRepository: candidates,
            availabilityRepository: CoordinatorAvailabilityRepository(),
            decisionSetRepository: decisionSets
        )
        let caller = Task {
            try await invocation.execute(on: sut)
        }
        while await candidates.requestedPages.isEmpty {
            await Task.yield()
        }

        caller.cancel()

        await #expect(throws: CancellationError.self) {
            _ = try await caller.value
        }
        #expect(await decisionSets.replacements.isEmpty)
    }

    private func waitForReplacement(
        in repository: CoordinatorDecisionSetRepository,
        count: Int = 1
    ) async throws {
        for _ in 0 ..< 100 {
            if await repository.replacements.count >= count {
                return
            }
            try await Task.sleep(for: .milliseconds(10))
        }
        Issue.record("Timed out waiting for persisted replacement")
        throw CoordinatorTestError.unavailable
    }
}

enum CoordinatorInvocation: CaseIterable, CustomTestStringConvertible, Sendable {
    case load
    case refresh
    case repair

    var testDescription: String {
        switch self {
            case .load: "load"
            case .refresh: "refresh"
            case .repair: "repairAfterEligibilityChange"
        }
    }

    func execute(on coordinator: ThreeForTonightCoordinator) async throws -> ThreeForTonightResult {
        switch self {
            case .load:
                return try await coordinator.load()
            case .refresh:
                return try await coordinator.refresh()
            case .repair:
                guard let change = DecisionEligibilityChange(
                    movieID: 10,
                    cause: .watchlist
                ) else {
                    throw CoordinatorTestError.unavailable
                }
                return try await coordinator.repairAfterEligibilityChange(
                    change
                )
        }
    }
}

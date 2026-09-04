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
        in repository: CoordinatorDecisionSetRepository
    ) async throws {
        for _ in 0 ..< 100 {
            if await !repository.replacements.isEmpty {
                return
            }
            try await Task.sleep(for: .milliseconds(10))
        }
        Issue.record("Timed out waiting for persisted replacement")
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

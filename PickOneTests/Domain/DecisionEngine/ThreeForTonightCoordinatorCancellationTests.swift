@testable import PickOne
import Testing

@Suite("Three for Tonight caller cancellation")
struct ThreeForTonightCallerCancellationTests {
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

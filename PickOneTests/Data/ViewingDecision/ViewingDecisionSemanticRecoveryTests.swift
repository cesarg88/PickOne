import Foundation
@testable import PickOne
import Testing

struct ViewingDecisionSemanticRecoveryTests {
    @Test(arguments: ["cancelledFinal", "supersededFinal", "missingFinal", "differentFinal"])
    func contradictoryOpenSessionIsQuarantinedAndPreviousRestored(contradiction: String) async throws {
        let store = MemoryViewingDecisionStore()
        let repository = LocalViewingDecisionRepository(store: store)
        let surface = try ViewingDecisionTestFixtures.surface()
        let first = try #require(surface.recommendations.first)
        let second = try #require(surface.recommendations.last)
        _ = try await repository.apply(operation(.activate(surface), 0))
        _ = try await repository.apply(operation(.pick(first, snapshot: surface, isVisible: true), 10))
        _ = try await repository.apply(operation(.pick(second, snapshot: surface, isVisible: true), 20))
        let validBytes = try #require(store.active)
        let expected = try ViewingDecisionEnvelope.decode(validBytes).state
        var contradictory = try ViewingDecisionEnvelope.decode(validBytes)
        try #require(contradictory.state.decisions.count == 2 && contradictory.state.sessions.count == 1)
        switch contradiction {
            case "cancelledFinal": contradictory.state.decisions[1].status = .cancelled
            case "supersededFinal": contradictory.state.decisions[1].status = .superseded
            case "missingFinal": contradictory.state.sessions[0].finalDecisionID = nil
            default: contradictory.state.sessions[0].finalDecisionID = contradictory.state.decisions[0].id
        }
        let invalidBytes = try contradictory.encoded()
        #expect(throws: ViewingDecisionError.invalidData) { try ViewingDecisionEnvelope.decode(invalidBytes) }
        store.previous = validBytes
        store.active = invalidBytes
        let recovered = try await LocalViewingDecisionRepository(store: store).snapshot()
        #expect(recovered == expected)
        #expect(store.quarantined == [invalidBytes])
        #expect(store.active == validBytes)
        #expect(try await LocalViewingDecisionRepository(store: store).snapshot() == expected)
    }

    @Test func closedSessionCanRetainItsSupersededFinalDecision() async throws {
        let repository = LocalViewingDecisionRepository(store: MemoryViewingDecisionStore())
        let surface = try ViewingDecisionTestFixtures.surface()
        let first = try #require(surface.recommendations.first)
        let second = try #require(surface.recommendations.last)
        _ = try await repository.apply(operation(.activate(surface), 0))
        _ = try await repository.apply(operation(.pick(first, snapshot: surface, isVisible: true), 10))
        _ = try await repository.apply(operation(.pause, 1810))
        _ = try await repository.apply(operation(.activate(surface), 1811))
        _ = try await repository.apply(operation(.pick(second, snapshot: surface, isVisible: true), 1820))
        let snapshot = try await repository.snapshot()
        #expect(snapshot.sessions.first?.status == .decided)
        #expect(snapshot.decisions.first?.status == .superseded)
        #expect(snapshot.sessions.first?.finalDecisionID == snapshot.decisions.first?.id)
        #expect(snapshot.openSession?.finalDecisionID == snapshot.activeDecision?.id)
    }

    private func operation(_ action: ViewingDecisionAction, _ seconds: Double) -> ViewingDecisionOperation {
        ViewingDecisionOperation(action: action, moment: ViewingDecisionTestFixtures.moment(seconds))
    }
}

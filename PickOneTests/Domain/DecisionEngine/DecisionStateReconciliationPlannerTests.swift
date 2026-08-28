import Foundation
@testable import PickOne
import Testing

@Suite("Decision state reconciliation planning")
struct DecisionStateReconciliationPlannerTests {
    @Test("Taste changes create one successor cycle with complete inherited history")
    func tasteChangeCreatesSuccessor() throws {
        let sourceID = UUID()
        let successorID = UUID()
        let snapshotID = ViewerStateSnapshotID(rawValue: UUID())
        let source = try DecisionCycle(
            id: sourceID,
            identitySignature: signature("a"),
            shownMovieIDs: [10, 20, 30]
        )
        let change = try #require(DecisionViewerStateChange(
            movieID: 40,
            impact: .tasteChanged,
            snapshotID: snapshotID
        ))

        let plan = try DecisionStateReconciliationPlanner().plan(
            change: change,
            sourceCycle: source,
            currentSignature: signature("b"),
            makeCycleID: { successorID }
        )

        guard case let .successorCycle(cycle) = plan else {
            Issue.record("Expected a successor cycle")
            return
        }
        #expect(cycle.id == successorID)
        #expect(cycle.id != sourceID)
        #expect(try cycle.identitySignature == signature("b"))
        #expect(cycle.shownMovieIDs == [10, 20, 30])
    }

    @Test(
        "Eligibility and Watchlist-only changes repair without changing cycle identity",
        arguments: [
            ViewerMovieStateChangeImpact.eligibilityChanged,
            .watchlistIntentChanged,
        ]
    )
    func eligibilityChangesRepair(
        impact: ViewerMovieStateChangeImpact
    ) throws {
        let source = try DecisionCycle(
            id: UUID(),
            identitySignature: signature("a"),
            shownMovieIDs: [10]
        )
        let change = try #require(DecisionViewerStateChange(
            movieID: 10,
            impact: impact,
            snapshotID: ViewerStateSnapshotID(rawValue: UUID())
        ))

        #expect(try DecisionStateReconciliationPlanner().plan(
            change: change,
            sourceCycle: source,
            currentSignature: source.identitySignature,
            makeCycleID: { UUID() }
        ) == .repair(movieID: 10))
    }

    @Test("semantic no-op plans no Decision Engine work")
    func semanticNoOpPlansNoWork() throws {
        let source = try DecisionCycle(
            id: UUID(),
            identitySignature: signature("a"),
            shownMovieIDs: [10]
        )
        let change = try #require(DecisionViewerStateChange(
            movieID: 10,
            impact: .none,
            snapshotID: ViewerStateSnapshotID(rawValue: UUID())
        ))

        #expect(try DecisionStateReconciliationPlanner().plan(
            change: change,
            sourceCycle: source,
            currentSignature: source.identitySignature,
            makeCycleID: { UUID() }
        ) == .none)
    }

    private func signature(_ character: Character) throws -> DecisionCycleSignature {
        guard let signature = DecisionCycleSignature(
            rawValue: String(repeating: character, count: 64)
        ) else {
            throw ReconciliationPlannerTestError.invalidSignature
        }
        return signature
    }
}

private enum ReconciliationPlannerTestError: Error {
    case invalidSignature
}

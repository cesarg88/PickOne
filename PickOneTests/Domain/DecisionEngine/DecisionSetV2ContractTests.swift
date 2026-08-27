import Foundation
@testable import PickOne
import Testing

@Suite("Decision Set v2 contract")
struct DecisionSetV2ContractTests {
    @Test("a publishable Decision Set carries its Viewer State source identity")
    func sourceSnapshotIdentity() throws {
        let sourceID = ViewerStateSnapshotID(rawValue: UUID())
        let signature = try #require(
            DecisionCycleSignature(rawValue: String(repeating: "a", count: 64))
        )

        let decisionSet = try PersistedDecisionSet(
            id: UUID(),
            generatedAt: Date(timeIntervalSince1970: 1000),
            engineModelVersion: .p1Model,
            cycle: DecisionCycle(
                id: UUID(),
                identitySignature: signature
            ),
            sourceViewerStateSnapshotID: sourceID,
            region: .spain,
            selectedProviderIDs: [PilotStreamingService.netflix.providerID],
            recommendations: []
        )

        #expect(decisionSet.sourceViewerStateSnapshotID == sourceID)
    }
}

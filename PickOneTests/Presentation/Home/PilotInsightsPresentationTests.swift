import Foundation
@testable import PickOne
import Testing

@MainActor
struct PilotInsightsPresentationTests {
    @Test func unavailableIsNeverZeroAndRetryRecovers() async {
        let store = MemoryViewingDecisionStore()
        store.failure = "read"
        let repository = LocalViewingDecisionRepository(store: store)
        let model = PilotInsightsViewModel(repository: repository)
        await model.load()
        #expect(model.isUnavailable)
        #expect(model.summary == nil)
        #expect(!model.isBusy)
        await model.prepareExport()
        #expect(model.actionFailed)
        #expect(model.exportData == nil)
        store.failure = nil
        await model.load()
        #expect(!model.isUnavailable)
        #expect(model.summary?.sessions == 0)
        await model.prepareExport()
        #expect(!model.actionFailed)
        #expect(model.exportData != nil)
        model.discardExport()
        #expect(model.exportData == nil)
    }

    @Test func deleteFailureKeepsReportAndRetryClearsOnlyCompletedHistory() async throws {
        let store = MemoryViewingDecisionStore()
        let repository = LocalViewingDecisionRepository(store: store)
        _ = try await repository.apply(.init(
            action: .activate(ViewingDecisionTestFixtures.surface()), moment: ViewingDecisionTestFixtures.moment(0)
        ))
        _ = try await repository.apply(.init(action: .expire, moment: ViewingDecisionTestFixtures.moment(1800)))
        let model = PilotInsightsViewModel(
            repository: repository,
            now: { ViewingDecisionTestFixtures.moment(2000).wall }
        )
        await model.load()
        #expect(model.summary?.sessions == 1)
        store.failure = "active"
        await model.delete()
        #expect(model.actionFailed)
        #expect(model.summary?.sessions == 1)
        store.failure = nil
        await model.delete()
        #expect(!model.actionFailed)
        #expect(model.summary?.sessions == 0)
    }
}

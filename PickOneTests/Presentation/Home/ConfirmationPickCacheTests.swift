import Foundation
@testable import PickOne
import Testing

@MainActor
struct ConfirmationPickCacheTests {
    @Test(arguments: [false, true], [false, true])
    func closingOutcomeImmediatelyRefreshesPickCache(watched: Bool, failedCancellation: Bool) async throws {
        let harness = try await ConfirmationHarness.make()
        let repository = LocalViewingDecisionRepository(store: harness.decisionFiles)
        let pick = HomePickViewModel(manage: ManageViewingDecision(repository: repository), clock: { harness.now })
        pick.setActive(true)
        await pick.waitForPendingOperations()
        #expect(pick.activeDecision?.id == harness.decisionID)
        if failedCancellation {
            harness.decisionFiles.failAtWrite = harness.decisionFiles.writeAttempts + 1
            pick.cancel()
            await pick.waitForPendingOperations()
            #expect(pick.failedMovieIDs == [1])
            harness.decisionFiles.failAtWrite = nil
        }
        let coordinator = ConfirmViewingDecision(
            decisions: repository, viewerState: harness.viewerRepository(),
            metadata: { _ in harness.metadata }, moment: { harness.now }
        )
        let confirmation = ViewingConfirmationViewModel(
            coordinator: coordinator, now: { harness.now.wall },
            refreshPickState: { try await pick.refreshDecision() }
        )
        await confirmation.refresh()
        let decision = try #require(confirmation.automatic)
        if watched { confirmation.watched(decision) } else { confirmation.notWatched(decision) }
        await confirmation.waitForAction()
        #expect(!confirmation.failure)
        #expect(pick.activeDecision == nil)
        #expect(!pick.isShowingPickFeedback)
        let committedBytes = try harness.decisionFiles.readActive()
        let writes = harness.decisionFiles.writeAttempts
        pick.cancel()
        pick.retry(movieID: 1)
        await pick.waitForPendingOperations()
        #expect(pick.failedMovieIDs.isEmpty)
        #expect(harness.decisionFiles.writeAttempts == writes)
        #expect(try harness.decisionFiles.readActive() == committedBytes)
        let relaunchedRepository = LocalViewingDecisionRepository(store: harness.decisionFiles)
        let relaunchedPick = HomePickViewModel(manage: ManageViewingDecision(repository: relaunchedRepository))
        try await relaunchedPick.refreshDecision()
        #expect(try harness.decisionFiles.readActive() == committedBytes)
        #expect(relaunchedPick.activeDecision == nil)
        #expect(try await relaunchedRepository.snapshot().decisions.first?
            .status == (watched ? .confirmedWatched : .notWatched))
    }
}

import Foundation
@testable import PickOne
import Testing

@MainActor
@Suite("Home Pick reconciliation", .serialized)
struct HomeDecisionPickReconciliationTests {
    @Test("A committed exclusion rejects Pick until its replacement set is published")
    func committedFeedbackBlocksPickDuringReconciliation() async throws {
        let initial = try HomeDecisionTestFixtures.snapshot(recommendations: [
            HomeDecisionTestFixtures.recommendation(movieID: 101, role: .safeChoice),
            HomeDecisionTestFixtures.recommendation(movieID: 202, role: .stretchChoice),
            HomeDecisionTestFixtures.recommendation(movieID: 303, role: .discoveryChoice),
        ])
        let replacement = try HomeDecisionTestFixtures.snapshot(recommendations: [
            HomeDecisionTestFixtures.recommendation(movieID: 101, role: .safeChoice),
            HomeDecisionTestFixtures.recommendation(movieID: 404, role: .stretchChoice),
            HomeDecisionTestFixtures.recommendation(movieID: 303, role: .discoveryChoice),
        ])
        let gate = HomeDecisionOperationGate()
        let useCase = GatedHomeDecisionUseCase(
            loadResult: .usable(initial), repairResult: .usable(replacement), gate: gate
        )
        let repository = LocalViewingDecisionRepository(store: MemoryViewingDecisionStore())
        let pick = HomePickViewModel(manage: ManageViewingDecision(repository: repository))
        let home = HomeDecisionViewModel(threeForTonight: useCase, pickModel: pick)
        home.load()
        await waitForItems([101, 202, 303], in: home)
        pick.showHome()
        pick.setActive(true)
        await pick.waitForPendingOperations()

        let metadata = try MovieFeedbackMetadata(title: "Excluded", releaseYear: 2024, posterPath: nil)
        let change = ViewerMovieStateChange(
            state: nil, impact: .eligibilityChanged, snapshotID: ViewerStateSnapshotID(rawValue: UUID())
        )
        let feedback = HomeQuickFeedbackViewModel(
            movieID: 202, metadata: metadata,
            updateViewerMovieState: CommittedHomeFeedbackUpdate(change: change),
            viewerStateDidChange: home.reconcile
        )
        await feedback.submit(.markWatched)
        await useCase.waitForRepairStart()
        #expect(feedback.state == .submitted)
        guard case let .loaded(retained, _, _) = home.state else {
            Issue.record("Expected old role slot during reconciliation")
            return
        }
        #expect(retained.items.map(\.id) == [101, 202, 303])
        #expect(pick.awaitingSafeSetMovieIDs.contains(202))
        pick.pick(movieID: 202, title: "Excluded")
        await pick.waitForPendingOperations()
        #expect(try await repository.snapshot().activeDecision == nil)

        await gate.open()
        await waitForItems([101, 404, 303], in: home)
        #expect(pick.awaitingSafeSetMovieIDs.isEmpty)
        pick.pick(movieID: 404, title: "Replacement")
        await pick.waitForPendingOperations()
        #expect(try await repository.snapshot().activeDecision?.recommendation.movieID == 404)
    }

    @Test("A retained unsafe set keeps Pick blocked until a later safe refresh")
    func failedFeedbackReconciliationRetainsPickHold() async throws {
        let initial = try HomeDecisionTestFixtures.snapshot()
        let replacement = try HomeDecisionTestFixtures.snapshot(
            recommendations: [HomeDecisionTestFixtures.recommendation(movieID: 202)],
            setID: UUID()
        )
        let useCase = HomeDecisionUseCase(results: [
            .success(.usable(initial)),
            .success(.retryableFailure(reason: .repairFailed, retained: initial)),
            .success(.usable(replacement)),
        ])
        let repository = LocalViewingDecisionRepository(store: MemoryViewingDecisionStore())
        let pick = HomePickViewModel(manage: ManageViewingDecision(repository: repository))
        let home = HomeDecisionViewModel(threeForTonight: useCase, pickModel: pick)
        home.load()
        await waitForItems([101], in: home)
        pick.showHome()
        pick.setActive(true)
        await pick.waitForPendingOperations()

        let change = try #require(DecisionViewerStateChange(
            movieID: 101, impact: .eligibilityChanged,
            snapshotID: ViewerStateSnapshotID(rawValue: UUID())
        ))
        home.reconcile(after: change)
        await useCase.waitForCallCount(2)
        await waitUntilSettled(home)
        #expect(pick.awaitingSafeSetMovieIDs == [101])
        pick.pick(movieID: 101)
        await pick.waitForPendingOperations()
        #expect(try await repository.snapshot().activeDecision == nil)

        home.refresh()
        await waitForItems([202], in: home)
        #expect(pick.awaitingSafeSetMovieIDs.isEmpty)
    }

    private func waitUntilSettled(_ sut: HomeDecisionViewModel) async {
        for _ in 0 ..< 100 {
            switch sut.state {
                case .loading:
                    await Task.yield()
                case let .loaded(_, isRefreshing, _) where isRefreshing:
                    await Task.yield()
                case let .empty(isRefreshing, _) where isRefreshing:
                    await Task.yield()
                default:
                    return
            }
        }
    }

    private func waitForItems(_ expectedIDs: [Int], in sut: HomeDecisionViewModel) async {
        for _ in 0 ..< 100 {
            if case let .loaded(set, _, _) = sut.state,
               set.items.map(\.id) == expectedIDs
            {
                return
            }
            await Task.yield()
        }
    }
}

private actor CommittedHomeFeedbackUpdate: UpdateViewerMovieStateUseCase {
    let change: ViewerMovieStateChange

    init(change: ViewerMovieStateChange) {
        self.change = change
    }

    func execute(
        transition _: ViewerMovieStateTransition,
        metadata _: MovieFeedbackMetadata
    ) async throws -> ViewerMovieStateChange {
        change
    }
}

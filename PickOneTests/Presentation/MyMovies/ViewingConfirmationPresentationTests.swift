import Foundation
@testable import PickOne
import Testing

@MainActor
struct ViewingConfirmationPresentationTests {
    @Test func thirdPostponementMovesToMyMoviesAndCanBeResolvedThere() async throws {
        let harness = try await ConfirmationHarness.make()
        let repository = LocalViewingDecisionRepository(store: harness.decisionFiles)
        for day in 0 ... 2 {
            let moment = DecisionMoment(
                wall: harness.now.wall.addingTimeInterval(Double(day) * 24 * 3600),
                monotonicSeconds: 0,
                runtimeID: UUID()
            )
            _ = try await repository.apply(.init(action: .confirmation(.notYet(harness.decisionID)), moment: moment))
        }
        let now = DecisionMoment(
            wall: harness.now.wall.addingTimeInterval(2 * 24 * 3600),
            monotonicSeconds: 0,
            runtimeID: UUID()
        )
        let coordinator = ConfirmViewingDecision(
            decisions: repository,
            viewerState: harness.viewerRepository(),
            metadata: { _ in harness.metadata },
            moment: { now }
        )
        let model = ViewingConfirmationViewModel(coordinator: coordinator, now: { now.wall })
        await model.refresh()
        #expect(model.automatic == nil)
        #expect(model.manual.map(\.id) == [harness.decisionID])
        try model.notWatched(#require(model.manual.first))
        await model.waitForAction()
        #expect(model.manual.isEmpty)
        #expect(model.automatic == nil)
        #expect(try await harness.viewerRepository().state(movieID: 1) == nil)
    }

    @Test func watchedOffersOptionalReactionAndNotNowPreservesProvenance() async throws {
        let harness = try await ConfirmationHarness.make()
        let model = ViewingConfirmationViewModel(coordinator: harness.coordinator(), now: { harness.now.wall })
        await model.refresh()
        let decision = try #require(model.automatic)
        model.watched(decision)
        await model.waitForAction()
        #expect(model.satisfaction?.id == decision.id)
        #expect(model.automatic == nil)
        model.skipSatisfaction()
        #expect(model.satisfaction == nil)
        let movie = try #require(try await harness.viewerRepository().state(movieID: 1))
        #expect(movie.reaction == nil)
        #expect(MyMoviesPresentationMapper.map([movie]).first?.hasPickOneProvenance == true)
    }

    @Test func failedAnswerIsRetryableAndNeverClaimsSuccess() async throws {
        let harness = try await ConfirmationHarness.make()
        let model = ViewingConfirmationViewModel(coordinator: harness.coordinator(), now: { harness.now.wall })
        await model.refresh()
        let decision = try #require(model.automatic)
        harness.decisionFiles.failAtWrite = harness.decisionFiles.writeAttempts + 1
        model.watched(decision)
        await model.waitForAction()
        #expect(model.failure)
        #expect(model.satisfaction == nil)
        #expect(try await harness.viewerRepository().state(movieID: 1) == nil)
        harness.decisionFiles.failAtWrite = nil
        model.retry()
        await model.waitForAction()
        #expect(!model.failure)
        #expect(model.satisfaction != nil)
        #expect(try await harness.coordinator().snapshot().confirmationOperations.count == 1)
    }

    @Test func directWatchedAndReactionHaveNoBadge() throws {
        let metadata = try MovieFeedbackMetadata(title: "Movie", releaseYear: nil, posterPath: nil)
        for action in [ViewerMovieStateTransition.Action.markWatched, .assignReaction(.likeIt)] {
            let result = try ViewerMovieStateReducer.reduce(
                current: nil,
                transition: .init(movieID: 1, action: action),
                metadata: metadata,
                at: Date()
            )
            let movie = try #require(result.state)
            #expect(!MyMoviesPresentationMapper.map([movie])[0].hasPickOneProvenance)
        }
    }
}

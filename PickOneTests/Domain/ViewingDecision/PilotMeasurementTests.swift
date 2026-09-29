import Foundation
@testable import PickOne
import Testing

struct PilotMeasurementTests {
    @Test func observationsAndSuccessfulFeedbackAreDeduplicated() throws {
        var state = ViewingDecisionState()
        let surface = try ViewingDecisionTestFixtures.surface()
        try state.apply(.activate(surface), at: ViewingDecisionTestFixtures.moment(0))
        try state.apply(.observe(surface), at: ViewingDecisionTestFixtures.moment(1))
        let sessionID = try #require(state.openSession?.id)
        try state.apply(.alreadyWatched(sessionID, movieID: 1), at: ViewingDecisionTestFixtures.moment(2))
        try state.apply(.alreadyWatched(sessionID, movieID: 1), at: ViewingDecisionTestFixtures.moment(3))
        let summary = PilotMeasurementSummary(state: state)
        #expect(summary.observedMovies == 2)
        #expect(summary.alreadyWatched == 1)
        #expect(summary.alreadyWatchedRate == 0.5)
        #expect(summary.firstPickMeanSeconds == nil)
        #expect(summary.confirmationRate == nil)
    }
}

extension PilotMeasurementTests {
    @Test func funnelTimingAndSatisfactionRemainDistinct() throws {
        var state = ViewingDecisionState()
        let surface = try ViewingDecisionTestFixtures.surface()
        let first = try #require(surface.recommendations.first)
        let second = try #require(surface.recommendations.last)
        try state.apply(.activate(surface), at: ViewingDecisionTestFixtures.moment(0))
        try state.apply(.pick(first, snapshot: surface, isVisible: true), at: ViewingDecisionTestFixtures.moment(10))
        try state.apply(.refresh(surface), at: ViewingDecisionTestFixtures.moment(12))
        try state.apply(.pick(second, snapshot: surface, isVisible: true), at: ViewingDecisionTestFixtures.moment(20))
        let id = try #require(state.activeDecision?.id)
        try state.apply(.confirmation(.notYet(id)), at: ViewingDecisionTestFixtures.moment(50000))
        try complete(&state, id: id, reaction: nil, at: 150_000)
        try complete(&state, id: id, reaction: .itWasOkay, at: 150_001)
        try state.apply(
            .pick(first, snapshot: surface, isVisible: false),
            at: ViewingDecisionTestFixtures.moment(150_010)
        )
        let unavailableID = try #require(state.activeDecision?.id)
        try complete(&state, id: unavailableID, reaction: nil, at: 200_000)
        let summary = PilotMeasurementSummary(state: state)
        #expect(summary.sessions == 1)
        #expect(summary.sessionsWithPick == 1)
        #expect(summary.sessionsConfirmedWatched == 1)
        #expect(summary.picks == 3)
        #expect(summary.confirmedWatched == 2)
        #expect(summary.superseded == 1)
        #expect(summary.postponements == 1)
        #expect(summary.firstPickSamples == 1)
        #expect(summary.finalPickSamples == 1)
        #expect(summary.firstPickMeanSeconds == 10)
        #expect(summary.finalPickMeanSeconds == 20)
        #expect(summary.itWasOkay == 1)
        #expect(summary.satisfactionUnavailable == 1)
        #expect(summary.loveIt + summary.likeIt + summary.didNotLikeIt == 0)
        #expect(summary.confirmationRate == 2.0 / 3.0)
        #expect(summary.observedSets == 1)
        #expect(summary.refreshes == 1)
    }

    @Test func semanticSearchIsBoundedAndDoesNotChangeSessionTime() throws {
        var state = ViewingDecisionState()
        let surface = try ViewingDecisionTestFixtures.surface()
        try state.apply(.activate(surface), at: ViewingDecisionTestFixtures.moment(0))
        let session = state.openSession
        let evidence = PilotSearchEvidence(
            id: UUID(), recordedAt: ViewingDecisionTestFixtures.moment(1).wall,
            duration: 2.5, stage: .firstExpansion, outcome: .exhausted
        )
        for _ in 0 ..< 2 {
            try state.apply(.search(evidence), at: ViewingDecisionTestFixtures.moment(100))
        }
        #expect(state.searchEvidence.count == 1)
        #expect(state.openSession == session)
        #expect(PilotMeasurementSummary(state: state).searchMeanSeconds == 2.5)
        #expect(PilotMeasurementSummary(state: state).expandedSearches == 1)
        for index in 0 ..< 1001 {
            let sample = PilotSearchEvidence(
                id: UUID(), recordedAt: ViewingDecisionTestFixtures.moment(Double(index)).wall,
                duration: 1, stage: .normal, outcome: .usable
            )
            try state.apply(.search(sample), at: ViewingDecisionTestFixtures.moment(Double(index)))
        }
        #expect(state.searchEvidence.count == 1000)
        #expect(state.openSession == session)
    }

    private func complete(
        _ state: inout ViewingDecisionState, id: ViewingDecisionID, reaction: MovieReaction?, at seconds: Double
    ) throws {
        let decision = try #require(state.decisions.first { $0.id == id })
        let operation = ViewingConfirmationOperation(
            id: UUID(), decisionID: id, movieID: decision.recommendation.movieID,
            createdAt: ViewingDecisionTestFixtures.moment(seconds).wall, reaction: reaction
        )
        try state.confirm(.prepare(operation), at: operation.createdAt)
        for stage in [
            ViewingConfirmationOperation.Stage.applyingViewerMovieState,
            .viewerMovieStateCommitted,
            .completed,
        ] {
            try state.confirm(.advance(operation.id, stage), at: operation.createdAt)
        }
    }
}

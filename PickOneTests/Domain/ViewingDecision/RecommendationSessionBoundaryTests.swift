import Foundation
@testable import PickOne
import Testing

struct RecommendationSessionBoundaryTests {
    @Test func inactivityBoundaryAbandonsAndReusesOldSet() throws {
        var state = ViewingDecisionState()
        let surface = try ViewingDecisionTestFixtures.surface()
        try state.apply(.activate(surface), at: ViewingDecisionTestFixtures.moment(0))
        let original = state.openSession?.id
        try state.apply(.pause, at: ViewingDecisionTestFixtures.moment(20))
        try state.apply(.activate(surface), at: ViewingDecisionTestFixtures.moment(1800))
        #expect(state.sessions.count == 2)
        #expect(state.sessions.first?.status == .abandoned)
        #expect(state.sessions.first?.foregroundDuration == 20)
        #expect(state.openSession?.id != original)
        let selection = try #require(surface.recommendations.first)
        try state.apply(
            .pick(selection, snapshot: surface, isVisible: true),
            at: ViewingDecisionTestFixtures.moment(1810)
        )
        #expect(state.activeDecision?.sessionID == state.openSession?.id)
        #expect(state.activeDecision?.timing == .available(10))
    }

    @Test func detailAndRefreshStayInSessionAndDeduplicateSets() throws {
        var state = ViewingDecisionState()
        let surface = try ViewingDecisionTestFixtures.surface()
        let next = try ViewingDecisionTestFixtures.surface()
        try state.apply(.activate(surface), at: ViewingDecisionTestFixtures.moment(0))
        try state.apply(.observe(surface), at: ViewingDecisionTestFixtures.moment(10))
        try state.apply(.refresh(surface), at: ViewingDecisionTestFixtures.moment(20))
        try state.apply(.observe(next), at: ViewingDecisionTestFixtures.moment(30))
        try state.apply(.observe(next), at: ViewingDecisionTestFixtures.moment(40))
        #expect(state.sessions.count == 1)
        #expect(state.openSession?.observedSetIDs.count == 2)
        #expect(state.openSession?.refreshCount == 1)
        try state.apply(.expire, at: ViewingDecisionTestFixtures.moment(1839))
        #expect(state.openSession != nil)
        try state.apply(.expire, at: ViewingDecisionTestFixtures.moment(1840))
        #expect(state.openSession == nil)
        #expect(state.sessions.first?.endedAt == ViewingDecisionTestFixtures.moment(1840).wall)
    }

    @Test func activePickFinalizesAndSurvivesBoundary() throws {
        var state = ViewingDecisionState()
        let surface = try ViewingDecisionTestFixtures.surface()
        let selection = try #require(surface.recommendations.first)
        try state.apply(.activate(surface), at: ViewingDecisionTestFixtures.moment(0))
        try state.apply(
            .pick(selection, snapshot: surface, isVisible: true),
            at: ViewingDecisionTestFixtures.moment(15)
        )
        let decision = state.activeDecision
        try state.apply(.expire, at: ViewingDecisionTestFixtures.moment(1815))
        #expect(state.sessions.first?.status == .decided)
        #expect(state.sessions.first?.finalDecisionID == decision?.id)
        #expect(state.activeDecision == decision)
        try state.apply(.observe(surface), at: ViewingDecisionTestFixtures.moment(2000))
        #expect(state.sessions.count == 2)
        #expect(state.activeDecision == decision)
    }

    @Test func pickWithoutActiveSurfaceHasUnavailableTiming() throws {
        var state = ViewingDecisionState()
        let surface = try ViewingDecisionTestFixtures.surface()
        let selection = try #require(surface.recommendations.first)
        try state.apply(
            .pick(selection, snapshot: surface, isVisible: false),
            at: ViewingDecisionTestFixtures.moment(50)
        )
        #expect(state.sessions.isEmpty)
        #expect(state.activeDecision?.sessionID == nil)
        #expect(state.activeDecision?.timing == .unavailable)
    }

    @Test func pickRecoversFromVisibleEvidenceWhenObservationWasMissing() throws {
        var state = ViewingDecisionState()
        let surface = try ViewingDecisionTestFixtures.surface()
        let selection = try #require(surface.recommendations.first)
        try state.apply(.activate(nil), at: ViewingDecisionTestFixtures.moment(0))
        try state.apply(
            .pick(selection, snapshot: surface, isVisible: true),
            at: ViewingDecisionTestFixtures.moment(10)
        )
        #expect(state.sessions.count == 1)
        #expect(state.activeDecision?.sessionID == state.openSession?.id)
    }

    @Test func cancellationRetryAfterNewerLifecycleStillCancelsTheSamePick() throws {
        var state = ViewingDecisionState()
        let surface = try ViewingDecisionTestFixtures.surface()
        let selection = try #require(surface.recommendations.first)
        try state.apply(.activate(surface), at: ViewingDecisionTestFixtures.moment(0))
        try state.apply(
            .pick(selection, snapshot: surface, isVisible: true),
            at: ViewingDecisionTestFixtures.moment(10)
        )
        let id = try #require(state.activeDecision?.id)
        try state.apply(.observe(surface), at: ViewingDecisionTestFixtures.moment(30))
        try state.apply(.cancel(id), at: ViewingDecisionTestFixtures.moment(20))
        #expect(state.activeDecision == nil)
        #expect(state.openSession?.lastActivityAt == ViewingDecisionTestFixtures.moment(30).wall)
    }

    @Test func mismatchedCardIsRejectedWithoutMutation() throws {
        var state = ViewingDecisionState()
        let surface = try ViewingDecisionTestFixtures.surface()
        let other = try ViewingDecisionTestFixtures.surface()
        let selection = try #require(other.recommendations.first)
        #expect(throws: ViewingDecisionError.invalidRecommendation) {
            try state.apply(
                .pick(selection, snapshot: surface, isVisible: true),
                at: ViewingDecisionTestFixtures.moment(0)
            )
        }
        #expect(state == ViewingDecisionState())
    }

    @Test func staleLifecycleCannotPauseNewerForegroundAndStaleCancelCannotCancelReplacement() throws {
        var state = ViewingDecisionState()
        let surface = try ViewingDecisionTestFixtures.surface()
        let first = try #require(surface.recommendations.first)
        let last = try #require(surface.recommendations.last)
        try state.apply(.activate(surface), at: ViewingDecisionTestFixtures.moment(10))
        try state.apply(.pause, at: ViewingDecisionTestFixtures.moment(0))
        #expect(state.isActive)
        try state.apply(.pick(first, snapshot: surface, isVisible: true), at: ViewingDecisionTestFixtures.moment(20))
        let oldID = try #require(state.activeDecision?.id)
        try state.apply(.pick(last, snapshot: surface, isVisible: true), at: ViewingDecisionTestFixtures.moment(30))
        #expect(throws: ViewingDecisionError.staleDecision) {
            try state.apply(.cancel(oldID), at: ViewingDecisionTestFixtures.moment(40))
        }
        #expect(state.activeDecision?.recommendation == last)
    }
}

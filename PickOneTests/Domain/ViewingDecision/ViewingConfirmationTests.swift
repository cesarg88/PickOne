import Foundation
@testable import PickOne
import Testing

struct ViewingConfirmationTests {
    @Test func confirmationBeforeLifecycleRecoveryPreservesSessionInactivityBoundary() throws {
        var state = ViewingDecisionState()
        let start = Date(timeIntervalSince1970: 1000)
        let card = PickRecommendation(movieID: 1, setID: UUID(), cycleID: UUID(), role: .safeChoice)
        let surface = try ViewingDecisionSurface(recommendations: [card])
        let moment = DecisionMoment(wall: start, monotonicSeconds: 0, runtimeID: UUID())
        try state.apply(.activate(surface), at: moment)
        try state.apply(.pick(card, snapshot: surface, isVisible: true), at: moment)
        let id = try #require(state.activeDecision?.id)
        try state.apply(.confirmation(.notWatched(id)), at: .init(
            wall: start.addingTimeInterval(12 * 3600), monotonicSeconds: 0, runtimeID: UUID()
        ))
        #expect(state.sessions.first?.endedAt == start.addingTimeInterval(30 * 60))
        #expect(state.sessions.first?.status == .decided)
        #expect(state.sessions.first?.finalDecisionID == id)
    }

    @Test func eligibilityAndThreePostponements() throws {
        var state = ViewingDecisionState()
        let start = Date(timeIntervalSince1970: 1000)
        let card = PickRecommendation(movieID: 1, setID: UUID(), cycleID: UUID(), role: .safeChoice)
        let surface = try ViewingDecisionSurface(recommendations: [card])
        let runtime = UUID()
        func moment(_ hours: Double) -> DecisionMoment {
            DecisionMoment(
                wall: start.addingTimeInterval(hours * 3600),
                monotonicSeconds: hours * 3600,
                runtimeID: runtime
            )
        }
        try state.apply(.pick(card, snapshot: surface, isVisible: false), at: moment(0))
        let decision = try #require(state.activeDecision)
        #expect(!decision.isAutomaticallyEligible(at: moment(11.999).wall))
        #expect(decision.isAutomaticallyEligible(at: moment(12).wall))
        for hour in [12.0, 36, 60] {
            try state.apply(.confirmation(.notYet(decision.id)), at: moment(hour))
            #expect(state.activeDecision?.isAutomaticallyEligible(at: moment(hour + 23.999).wall) == false)
        }
        #expect(state.activeDecision?.postponementCount == 3)
        #expect(state.activeDecision?.isAutomaticallyEligible(at: moment(100).wall) == false)
        #expect(state.manualConfirmations.map(\.id) == [decision.id])
        try state.apply(.confirmation(.notWatched(decision.id)), at: moment(100))
        #expect(state.activeDecision == nil)
        #expect(state.decisions.last?.status == .notWatched)
    }
}

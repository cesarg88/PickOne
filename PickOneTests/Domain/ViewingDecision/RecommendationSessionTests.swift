import Foundation
@testable import PickOne
import Testing

struct RecommendationSessionTests {
    @Test func foregroundPickReplacementAndCancellation() throws {
        var state = ViewingDecisionState()
        let surface = try ViewingDecisionTestFixtures.surface()
        let first = try #require(surface.recommendations.first)
        let second = try #require(surface.recommendations.last)
        try state.apply(.activate(surface), at: ViewingDecisionTestFixtures.moment(0))
        try state.apply(.pause, at: ViewingDecisionTestFixtures.moment(10))
        try state.apply(.activate(surface), at: ViewingDecisionTestFixtures.moment(110))
        try state.apply(.pick(first, snapshot: surface, isVisible: true), at: ViewingDecisionTestFixtures.moment(120))
        #expect(state.sessions.first?.firstPickTiming == .available(20))
        try state.apply(.pick(second, snapshot: surface, isVisible: true), at: ViewingDecisionTestFixtures.moment(130))
        #expect(state.activeDecision?.timing == .available(30))
        #expect(state.decisions.first?.status == .superseded)
        let active = try #require(state.activeDecision)
        try state.apply(.cancel(active.id), at: ViewingDecisionTestFixtures.moment(140))
        #expect(state.activeDecision == nil)
        #expect(state.decisions.last?.status == .cancelled)
        #expect(state.sessions.first?.firstPickTiming == .available(20))
    }
}

enum ViewingDecisionTestFixtures {
    static let runtimeID = UUID()
    static func moment(_ seconds: Double, runtimeID: UUID = runtimeID) -> DecisionMoment {
        DecisionMoment(
            wall: Date(timeIntervalSince1970: 100_000 + seconds),
            monotonicSeconds: seconds,
            runtimeID: runtimeID
        )
    }

    static func surface() throws -> ViewingDecisionSurface {
        let setID = UUID()
        let cycleID = UUID()
        return try ViewingDecisionSurface(recommendations: [1, 2].map {
            PickRecommendation(
                movieID: $0,
                setID: setID,
                cycleID: cycleID,
                role: $0 == 1 ? .safeChoice : .stretchChoice
            )
        })
    }
}

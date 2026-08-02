@testable import PickOne
import Testing

@Suite("Calibration flow tests")
struct CalibrationFlowTests {
    @Test("primary and reserve positions remain available below target")
    func primaryAndReserve() {
        #expect(destination(position: 0, informativeCount: 0) == .movie(position: 0))
        #expect(destination(position: 12, informativeCount: 2) == .movie(position: 12))
        #expect(destination(position: 14, informativeCount: 2) == .movie(position: 14))
    }

    @Test("eight signals complete immediately")
    func earlyEight() {
        #expect(destination(position: 8, informativeCount: 8) == .completion)
        #expect(destination(position: 13, informativeCount: 8) == .completion)
    }

    @Test("normal exhaustion branches by signal count")
    func normalExhaustion() {
        #expect(destination(position: 15, informativeCount: 2) == .lowSignalDecision)
        #expect(destination(position: 15, informativeCount: 3) == .completion)
        #expect(destination(position: 15, informativeCount: 7) == .completion)
    }

    @Test("optional extension ends at target or after six answers")
    func optionalExtension() {
        #expect(
            destination(position: 15, informativeCount: 2, extensionAccepted: true)
                == .movie(position: 15)
        )
        #expect(
            destination(position: 18, informativeCount: 8, extensionAccepted: true)
                == .completion
        )
        #expect(
            destination(position: 21, informativeCount: 1, extensionAccepted: true)
                == .completion
        )
    }

    private func destination(
        position: Int,
        informativeCount: Int,
        extensionAccepted: Bool = false
    ) -> CalibrationDestination {
        CalibrationFlow.destination(
            position: position,
            reactions: ViewerProfileTestFixtures.reactions(count: informativeCount),
            optionalExtensionAccepted: extensionAccepted,
            catalog: .spainHouseholdV1
        )
    }
}

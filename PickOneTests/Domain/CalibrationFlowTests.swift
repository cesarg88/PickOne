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

    @Test("Back may retain later answers only as one coherent prefix")
    func backPreservesCoherentPrefix() throws {
        let valid = FirstOnboardingDraft(
            catalogID: ViewerProfileTestFixtures.catalog.id,
            step: .calibration,
            selectedServices: [.netflix],
            reactions: ViewerProfileTestFixtures.reactions(count: 5),
            currentCatalogPosition: 2,
            optionalExtensionAccepted: false
        )

        try ViewerProfileValidator.validate(
            draft: valid,
            catalog: ViewerProfileTestFixtures.catalog
        )

        var reactionsWithGap = valid.reactions
        reactionsWithGap[ViewerProfileTestFixtures.catalog.movies[3].id] = nil
        let invalid = FirstOnboardingDraft(
            catalogID: valid.catalogID,
            step: valid.step,
            selectedServices: valid.selectedServices,
            reactions: reactionsWithGap,
            currentCatalogPosition: valid.currentCatalogPosition,
            optionalExtensionAccepted: valid.optionalExtensionAccepted
        )
        #expect(throws: ViewerProfileValidationError.inconsistentProgress) {
            try ViewerProfileValidator.validate(
                draft: invalid,
                catalog: ViewerProfileTestFixtures.catalog
            )
        }
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

@testable import PickOne
import Testing

@Suite("Viewer profile catalog and reaction tests")
struct ViewerProfileCatalogTests {
    @Test("accepted calibration catalog is fixed, unique, and ordered")
    func acceptedCatalog() {
        let catalog = CalibrationCatalog.spainHouseholdV1

        #expect(catalog.id.rawValue == "es-household-calibration-v1")
        #expect(catalog.primary.count == 12)
        #expect(catalog.reserve.count == 3)
        #expect(catalog.optionalExtension.count == 6)
        #expect(Set(catalog.movies.map(\.id)).count == 21)
        #expect(
            catalog.movies.map(\.id) == [
                238, 11036, 155, 1417, 18785, 129, 157336, 419430,
                496243, 354912, 546554, 76341, 120, 313369, 77338,
                278, 98, 194, 120467, 447332, 906126,
            ]
        )
        #expect(catalog.movies.allSatisfy { !$0.titleKnownInSpain.isEmpty })
        #expect(catalog.movies.allSatisfy { !$0.originalOrEnglishTitle.isEmpty })
        #expect(catalog.movies.prefix(8).contains { $0.originalLanguage == "es" })
        #expect(catalog.movies.prefix(8).contains { $0.originalLanguage == "ja" })
    }

    @Test("reaction semantics preserve informative and seen meaning")
    func reactionSemantics() {
        let informative: [CalibrationReaction] = [
            .loveIt, .likeIt, .itWasOkay, .didNotLikeIt,
        ]
        let noninformative: [CalibrationReaction] = [
            .haveNotSeenIt, .doNotKnowIt,
        ]

        #expect(informative.allSatisfy { $0.isInformativeSignal })
        #expect(informative.allSatisfy { $0.meansWatchedInCalibration })
        #expect(noninformative.allSatisfy { !$0.isInformativeSignal })
        #expect(noninformative.allSatisfy { !$0.meansWatchedInCalibration })
        #expect(CalibrationReaction.allCases.map(\.title) == [
            "Love it", "Like it", "It was okay", "Didn't like it",
            "Haven't seen it", "Don't know it",
        ])
    }

    @Test("informative count is derived from raw reactions")
    func derivedCount() {
        let draft = FirstOnboardingDraft(
            catalogID: .spainHouseholdV1,
            step: .calibration,
            selectedServices: [.netflix],
            reactions: [
                238: .loveIt,
                11036: .itWasOkay,
                155: .haveNotSeenIt,
                1417: .doNotKnowIt,
            ],
            currentCatalogPosition: 4,
            optionalExtensionAccepted: false
        )

        #expect(draft.informativeSignalCount == 2)
    }
}

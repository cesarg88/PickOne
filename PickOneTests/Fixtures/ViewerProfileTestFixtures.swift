@testable import PickOne

enum ViewerProfileTestFixtures {
    static let catalog = CalibrationCatalog.spainHouseholdV1

    static func reactions(
        count: Int,
        reaction: CalibrationReaction = .loveIt
    ) -> [Int: CalibrationReaction] {
        Dictionary(
            uniqueKeysWithValues: catalog.movies.prefix(count).map { ($0.id, reaction) }
        )
    }

    static func firstDraft(
        step: FirstOnboardingStep = .completion,
        services: [PilotStreamingService] = [.netflix],
        reactionCount: Int = 8,
        position: Int = 8,
        extensionAccepted: Bool = false
    ) -> FirstOnboardingDraft {
        FirstOnboardingDraft(
            catalogID: catalog.id,
            step: step,
            selectedServices: services,
            reactions: reactions(count: reactionCount),
            currentCatalogPosition: position,
            optionalExtensionAccepted: extensionAccepted
        )
    }

    static func recalibrationDraft(
        reactionCount: Int = 8,
        position: Int = 8,
        extensionAccepted: Bool = false
    ) -> RecalibrationDraft {
        RecalibrationDraft(
            catalogID: catalog.id,
            reactions: reactions(count: reactionCount, reaction: .likeIt),
            currentCatalogPosition: position,
            optionalExtensionAccepted: extensionAccepted
        )
    }

    static func completedProfile(
        in repository: DefaultViewerProfileRepository,
        services: [PilotStreamingService] = [.netflix]
    ) async throws -> ViewerProfile {
        _ = try await repository.beginFirstOnboarding(catalog: catalog)
        try await repository.saveFirstOnboardingDraft(
            firstDraft(services: services)
        )
        return try await repository.completeFirstOnboarding()
    }
}

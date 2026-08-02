enum ViewerProfileValidator {
    static func validate(
        profile: ViewerProfile,
        catalog: CalibrationCatalog
    ) throws {
        guard profile.profileSchemaVersion == ViewerProfile.currentSchemaVersion else {
            throw ViewerProfileValidationError.unsupportedProfileVersion
        }
        guard profile.region == .spain else {
            throw ViewerProfileValidationError.unsupportedRegion
        }
        guard !profile.selectedServices.isEmpty else {
            throw ViewerProfileValidationError.emptyServiceSelection
        }
        try validateCatalog(profile.catalogID, expected: catalog)
        try validateServices(profile.selectedServices)
        try validateReactions(profile.reactions, catalog: catalog)
    }

    static func validate(
        draft: FirstOnboardingDraft,
        catalog: CalibrationCatalog
    ) throws {
        try validateCatalog(draft.catalogID, expected: catalog)
        try validateServices(draft.selectedServices)
        try validateProgress(
            position: draft.currentCatalogPosition,
            reactions: draft.reactions,
            optionalExtensionAccepted: draft.optionalExtensionAccepted,
            catalog: catalog
        )

        let destination = CalibrationFlow.destination(
            position: draft.currentCatalogPosition,
            reactions: draft.reactions,
            optionalExtensionAccepted: draft.optionalExtensionAccepted,
            catalog: catalog
        )
        let stepIsConsistent: Bool = switch draft.step {
            case .services:
                draft.currentCatalogPosition == 0
            case .calibration:
                if case .movie = destination { true } else { false }
            case .lowSignalDecision:
                destination == .lowSignalDecision
            case .completion:
                destination == .completion || destination == .lowSignalDecision
        }
        guard stepIsConsistent else {
            throw ViewerProfileValidationError.inconsistentProgress
        }
    }

    static func validate(
        draft: RecalibrationDraft,
        catalog: CalibrationCatalog
    ) throws {
        try validateCatalog(draft.catalogID, expected: catalog)
        try validateProgress(
            position: draft.currentCatalogPosition,
            reactions: draft.reactions,
            optionalExtensionAccepted: draft.optionalExtensionAccepted,
            catalog: catalog
        )
    }

    static func validateServices(
        _ services: [PilotStreamingService]
    ) throws {
        let allowlistedIDs = Set(PilotStreamingService.allowlist.map(\.providerID))
        let ids = services.map(\.providerID)
        guard Set(ids).count == ids.count, ids.allSatisfy(allowlistedIDs.contains) else {
            throw ViewerProfileValidationError.unsupportedService
        }
    }

    private static func validateCatalog(
        _ catalogID: CalibrationCatalogID,
        expected catalog: CalibrationCatalog
    ) throws {
        guard catalogID == catalog.id else {
            throw ViewerProfileValidationError.unsupportedCatalog
        }
    }

    private static func validateReactions(
        _ reactions: [Int: CalibrationReaction],
        catalog: CalibrationCatalog
    ) throws {
        guard reactions.keys.allSatisfy(catalog.contains(movieID:)) else {
            throw ViewerProfileValidationError.unknownMovie
        }
    }

    private static func validateProgress(
        position: Int,
        reactions: [Int: CalibrationReaction],
        optionalExtensionAccepted: Bool,
        catalog: CalibrationCatalog
    ) throws {
        try validateReactions(reactions, catalog: catalog)
        guard position >= 0, position <= catalog.movies.count else {
            throw ViewerProfileValidationError.invalidCatalogPosition
        }
        guard optionalExtensionAccepted ? position >= CalibrationFlow.normalLimit : position <= CalibrationFlow
            .normalLimit
        else {
            throw ViewerProfileValidationError.inconsistentProgress
        }
        let precedingIDs = catalog.movies.prefix(position).map(\.id)
        guard precedingIDs.allSatisfy({ reactions[$0] != nil }) else {
            throw ViewerProfileValidationError.inconsistentProgress
        }
    }
}

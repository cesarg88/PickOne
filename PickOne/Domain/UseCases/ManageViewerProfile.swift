protocol ManageViewerProfileUseCase: Sendable {
    var catalog: CalibrationCatalog { get }

    func loadState() async -> ViewerProfileLoadState
    func beginFirstOnboarding() async throws -> FirstOnboardingDraft
    func selectServices(
        _ services: [PilotStreamingService],
        in draft: FirstOnboardingDraft
    ) async throws -> FirstOnboardingDraft
    func beginCalibration(
        from draft: FirstOnboardingDraft,
        snapshot: CalibrationCatalogSnapshot?
    ) async throws -> FirstOnboardingDraft
    func react(
        _ reaction: CalibrationReaction,
        in draft: FirstOnboardingDraft
    ) async throws -> FirstOnboardingDraft
    func react(
        _ reaction: CalibrationReaction,
        in draft: RecalibrationDraft
    ) async throws -> RecalibrationDraft
    func goBack(in draft: FirstOnboardingDraft) async throws -> FirstOnboardingDraft
    func goBack(in draft: RecalibrationDraft) async throws -> RecalibrationDraft
    func acceptOptionalExtension(in draft: FirstOnboardingDraft) async throws -> FirstOnboardingDraft
    func acceptOptionalExtension(in draft: RecalibrationDraft) async throws -> RecalibrationDraft
    func continueWithLowSignals(in draft: FirstOnboardingDraft) async throws -> FirstOnboardingDraft
    func completeFirstOnboarding() async throws -> ViewerProfile
    func beginRecalibration(snapshot: CalibrationCatalogSnapshot) async throws -> RecalibrationDraft
    func completeRecalibration() async throws -> ViewerProfile
    func updateServices(_ services: [PilotStreamingService]) async throws -> ViewerProfile
    func resetDraft() async throws
    func resetProfileAndDraft() async throws
}

struct ManageViewerProfile: ManageViewerProfileUseCase {
    let catalog: CalibrationCatalog
    private let repository: ViewerProfileRepository

    init(
        repository: ViewerProfileRepository,
        catalog: CalibrationCatalog
    ) {
        self.repository = repository
        self.catalog = catalog
    }

    func loadState() async -> ViewerProfileLoadState {
        await repository.loadState()
    }

    func beginFirstOnboarding() async throws -> FirstOnboardingDraft {
        try await repository.beginFirstOnboarding(catalog: catalog)
    }

    func selectServices(
        _ services: [PilotStreamingService],
        in draft: FirstOnboardingDraft
    ) async throws -> FirstOnboardingDraft {
        let updated = try FirstOnboardingDraft(
            catalog: draft.catalog,
            step: draft.step,
            selectedServices: validatedServices(services),
            reactions: draft.reactions,
            currentCatalogPosition: draft.currentCatalogPosition,
            optionalExtensionAccepted: draft.optionalExtensionAccepted,
            isCatalogFrozen: draft.isCatalogFrozen
        )
        try await repository.saveFirstOnboardingDraft(updated)
        return updated
    }

    func beginCalibration(
        from draft: FirstOnboardingDraft,
        snapshot: CalibrationCatalogSnapshot?
    ) async throws -> FirstOnboardingDraft {
        guard !draft.selectedServices.isEmpty else {
            throw ViewerProfileRepositoryError.validation(.emptyServiceSelection)
        }
        return try await repository.beginCalibration(
            from: draft,
            snapshot: snapshot
        )
    }

    func react(
        _ reaction: CalibrationReaction,
        in draft: FirstOnboardingDraft
    ) async throws -> FirstOnboardingDraft {
        let progress = try advancedProgress(
            reaction: reaction,
            position: draft.currentCatalogPosition,
            reactions: draft.reactions,
            optionalExtensionAccepted: draft.optionalExtensionAccepted,
            catalog: draft.catalog
        )
        let updated = FirstOnboardingDraft(
            catalog: draft.catalog,
            step: firstStep(for: progress.destination),
            selectedServices: draft.selectedServices,
            reactions: progress.reactions,
            currentCatalogPosition: progress.position,
            optionalExtensionAccepted: draft.optionalExtensionAccepted,
            isCatalogFrozen: draft.isCatalogFrozen
        )
        try await repository.saveFirstOnboardingDraft(updated)
        return updated
    }

    func react(
        _ reaction: CalibrationReaction,
        in draft: RecalibrationDraft
    ) async throws -> RecalibrationDraft {
        let progress = try advancedProgress(
            reaction: reaction,
            position: draft.currentCatalogPosition,
            reactions: draft.reactions,
            optionalExtensionAccepted: draft.optionalExtensionAccepted,
            catalog: draft.catalog
        )
        let updated = RecalibrationDraft(
            catalog: draft.catalog,
            reactions: progress.reactions,
            currentCatalogPosition: progress.position,
            optionalExtensionAccepted: draft.optionalExtensionAccepted
        )
        try await repository.saveRecalibrationDraft(updated)
        return updated
    }

    func goBack(in draft: FirstOnboardingDraft) async throws -> FirstOnboardingDraft {
        let updated: FirstOnboardingDraft = if draft.currentCatalogPosition == 0 {
            firstDraft(draft, step: .services)
        } else {
            FirstOnboardingDraft(
                catalog: draft.catalog,
                step: .calibration,
                selectedServices: draft.selectedServices,
                reactions: draft.reactions,
                currentCatalogPosition: draft.currentCatalogPosition - 1,
                optionalExtensionAccepted: draft.optionalExtensionAccepted,
                isCatalogFrozen: draft.isCatalogFrozen
            )
        }
        try await repository.saveFirstOnboardingDraft(updated)
        return updated
    }

    func goBack(in draft: RecalibrationDraft) async throws -> RecalibrationDraft {
        guard draft.currentCatalogPosition > 0 else { return draft }
        let updated = RecalibrationDraft(
            catalog: draft.catalog,
            reactions: draft.reactions,
            currentCatalogPosition: draft.currentCatalogPosition - 1,
            optionalExtensionAccepted: draft.optionalExtensionAccepted
        )
        try await repository.saveRecalibrationDraft(updated)
        return updated
    }

    func acceptOptionalExtension(in draft: FirstOnboardingDraft) async throws -> FirstOnboardingDraft {
        let updated = FirstOnboardingDraft(
            catalog: draft.catalog,
            step: .calibration,
            selectedServices: draft.selectedServices,
            reactions: draft.reactions,
            currentCatalogPosition: draft.currentCatalogPosition,
            optionalExtensionAccepted: true,
            isCatalogFrozen: draft.isCatalogFrozen
        )
        try await repository.saveFirstOnboardingDraft(updated)
        return updated
    }

    func acceptOptionalExtension(in draft: RecalibrationDraft) async throws -> RecalibrationDraft {
        let updated = RecalibrationDraft(
            catalog: draft.catalog,
            reactions: draft.reactions,
            currentCatalogPosition: draft.currentCatalogPosition,
            optionalExtensionAccepted: true
        )
        try await repository.saveRecalibrationDraft(updated)
        return updated
    }

    func continueWithLowSignals(in draft: FirstOnboardingDraft) async throws -> FirstOnboardingDraft {
        let updated = firstDraft(draft, step: .completion)
        try await repository.saveFirstOnboardingDraft(updated)
        return updated
    }

    func completeFirstOnboarding() async throws -> ViewerProfile {
        try await repository.completeFirstOnboarding()
    }

    func beginRecalibration(
        snapshot: CalibrationCatalogSnapshot
    ) async throws -> RecalibrationDraft {
        try await repository.beginRecalibration(snapshot: snapshot)
    }

    func completeRecalibration() async throws -> ViewerProfile {
        try await repository.completeRecalibration()
    }

    func updateServices(_ services: [PilotStreamingService]) async throws -> ViewerProfile {
        try await repository.updateServices(validatedServices(services))
    }

    func resetDraft() async throws {
        try await repository.resetDraft()
    }

    func resetProfileAndDraft() async throws {
        try await repository.resetProfileAndDraft()
    }

    private func advancedProgress(
        reaction: CalibrationReaction,
        position: Int,
        reactions: [Int: CalibrationReaction],
        optionalExtensionAccepted: Bool,
        catalog: CalibrationCatalog
    ) throws -> (
        position: Int,
        reactions: [Int: CalibrationReaction],
        destination: CalibrationDestination
    ) {
        guard catalog.movies.indices.contains(position) else {
            throw ViewerProfileRepositoryError.validation(.invalidCatalogPosition)
        }
        var updatedReactions = reactions
        updatedReactions[catalog.movies[position].id] = reaction
        let updatedPosition = position + 1
        return (
            updatedPosition,
            updatedReactions,
            CalibrationFlow.destination(
                position: updatedPosition,
                reactions: updatedReactions,
                optionalExtensionAccepted: optionalExtensionAccepted,
                catalog: catalog
            )
        )
    }

    private func firstStep(for destination: CalibrationDestination) -> FirstOnboardingStep {
        switch destination {
            case .movie: .calibration
            case .lowSignalDecision: .lowSignalDecision
            case .completion: .completion
        }
    }

    private func firstDraft(
        _ draft: FirstOnboardingDraft,
        step: FirstOnboardingStep
    ) -> FirstOnboardingDraft {
        FirstOnboardingDraft(
            catalog: draft.catalog,
            step: step,
            selectedServices: draft.selectedServices,
            reactions: draft.reactions,
            currentCatalogPosition: draft.currentCatalogPosition,
            optionalExtensionAccepted: draft.optionalExtensionAccepted,
            isCatalogFrozen: draft.isCatalogFrozen
        )
    }

    private func validatedServices(
        _ services: [PilotStreamingService]
    ) throws -> [PilotStreamingService] {
        let selectedIDs = Set(services.map(\.providerID))
        let normalized = PilotStreamingService.allowlist.filter {
            selectedIDs.contains($0.providerID)
        }
        guard normalized.count == services.count else {
            throw ViewerProfileRepositoryError.validation(.unsupportedService)
        }
        return normalized
    }
}

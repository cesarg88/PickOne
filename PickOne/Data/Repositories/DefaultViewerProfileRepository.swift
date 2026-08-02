import Foundation

actor DefaultViewerProfileRepository: ViewerProfileRepository {
    private struct Envelope: Sendable {
        let profile: ViewerProfile?
        let draft: ViewerProfileDraft?
    }

    private let store: ViewerProfileDataStore
    private let coder: ViewerProfileEnvelopeCoding
    private let catalogs: [CalibrationCatalogID: CalibrationCatalog]

    init(
        store: ViewerProfileDataStore,
        catalogs: [CalibrationCatalog] = [.spainHouseholdV1],
        coder: ViewerProfileEnvelopeCoding = JSONViewerProfileEnvelopeCoder()
    ) {
        self.store = store
        self.coder = coder
        self.catalogs = Dictionary(uniqueKeysWithValues: catalogs.map { ($0.id, $0) })
    }

    func loadState() -> ViewerProfileLoadState {
        do {
            guard let envelope = try loadEnvelope() else {
                return .absent
            }
            switch (envelope.profile, envelope.draft) {
                case (nil, nil):
                    return .absent
                case (nil, let .firstOnboarding(draft)):
                    return .firstOnboarding(draft)
                case let (profile?, nil):
                    return .completed(profile: profile, recalibrationDraft: nil)
                case let (profile?, .recalibration(draft)):
                    return .completed(profile: profile, recalibrationDraft: draft)
                case (nil, .recalibration), (_, .firstOnboarding):
                    return .recovery(.corruptData)
            }
        } catch ViewerProfileCodingError.unsupportedVersion {
            return .recovery(.unsupportedVersion)
        } catch ViewerProfileValidationError.unsupportedCatalog,
            ViewerProfileValidationError.unsupportedProfileVersion
        {
            return .recovery(.unsupportedVersion)
        } catch is ViewerProfileCodingError {
            return .recovery(.corruptData)
        } catch is ViewerProfileValidationError {
            return .recovery(.corruptData)
        } catch {
            return .recovery(.loadFailed)
        }
    }

    func beginFirstOnboarding(catalog: CalibrationCatalog) throws -> FirstOnboardingDraft {
        let envelope = try loadEnvelopeForMutation() ?? Envelope(profile: nil, draft: nil)
        guard envelope.profile == nil, envelope.draft == nil else {
            throw ViewerProfileRepositoryError.invalidTransition
        }
        let draft = FirstOnboardingDraft.empty(catalog: catalog)
        try persist(Envelope(profile: nil, draft: .firstOnboarding(draft)))
        return draft
    }

    func saveFirstOnboardingDraft(_ draft: FirstOnboardingDraft) throws {
        try validate(draft)
        let envelope = try loadEnvelopeForMutation()
        guard envelope?.profile == nil else {
            throw ViewerProfileRepositoryError.invalidTransition
        }
        try persist(Envelope(profile: nil, draft: .firstOnboarding(draft)))
    }

    func completeFirstOnboarding() throws -> ViewerProfile {
        guard
            let envelope = try loadEnvelopeForMutation(),
            envelope.profile == nil,
            case let .firstOnboarding(draft) = envelope.draft,
            draft.step == .completion
        else {
            throw ViewerProfileRepositoryError.invalidTransition
        }
        let profile = ViewerProfile(
            profileSchemaVersion: ViewerProfile.currentSchemaVersion,
            catalogID: draft.catalogID,
            region: .spain,
            selectedServices: draft.selectedServices,
            reactions: draft.reactions
        )
        try validate(profile)
        try persist(Envelope(profile: profile, draft: nil))
        return profile
    }

    func beginRecalibration(catalog: CalibrationCatalog) throws -> RecalibrationDraft {
        guard
            let envelope = try loadEnvelopeForMutation(),
            envelope.profile != nil,
            envelope.draft == nil
        else {
            throw ViewerProfileRepositoryError.invalidTransition
        }
        let draft = RecalibrationDraft.empty(catalog: catalog)
        try persist(Envelope(profile: envelope.profile, draft: .recalibration(draft)))
        return draft
    }

    func saveRecalibrationDraft(_ draft: RecalibrationDraft) throws {
        try validate(draft)
        guard
            let envelope = try loadEnvelopeForMutation(),
            envelope.profile != nil,
            case .recalibration = envelope.draft
        else {
            throw ViewerProfileRepositoryError.invalidTransition
        }
        try persist(Envelope(profile: envelope.profile, draft: .recalibration(draft)))
    }

    func completeRecalibration() throws -> ViewerProfile {
        guard
            let envelope = try loadEnvelopeForMutation(),
            let activeProfile = envelope.profile,
            case let .recalibration(draft) = envelope.draft
        else {
            throw ViewerProfileRepositoryError.invalidTransition
        }
        let destination = try CalibrationFlow.destination(
            position: draft.currentCatalogPosition,
            reactions: draft.reactions,
            optionalExtensionAccepted: draft.optionalExtensionAccepted,
            catalog: catalog(for: draft.catalogID)
        )
        guard destination == .completion || destination == .lowSignalDecision else {
            throw ViewerProfileRepositoryError.invalidTransition
        }
        let replacement = ViewerProfile(
            profileSchemaVersion: ViewerProfile.currentSchemaVersion,
            catalogID: draft.catalogID,
            region: activeProfile.region,
            selectedServices: activeProfile.selectedServices,
            reactions: draft.reactions
        )
        try validate(replacement)
        try persist(Envelope(profile: replacement, draft: nil))
        return replacement
    }

    func updateServices(_ services: [PilotStreamingService]) throws -> ViewerProfile {
        guard
            let envelope = try loadEnvelopeForMutation(),
            let activeProfile = envelope.profile
        else {
            throw ViewerProfileRepositoryError.invalidTransition
        }
        guard !services.isEmpty else {
            throw ViewerProfileRepositoryError.validation(.emptyServiceSelection)
        }
        let updated = ViewerProfile(
            profileSchemaVersion: activeProfile.profileSchemaVersion,
            catalogID: activeProfile.catalogID,
            region: activeProfile.region,
            selectedServices: services,
            reactions: activeProfile.reactions
        )
        try validate(updated)
        try persist(Envelope(profile: updated, draft: envelope.draft))
        return updated
    }

    func resetDraft() throws {
        guard let envelope = try loadEnvelopeForMutation() else { return }
        try persist(Envelope(profile: envelope.profile, draft: nil))
    }

    func resetProfileAndDraft() throws {
        do {
            try store.remove()
        } catch {
            throw ViewerProfileRepositoryError.storageFailed
        }
    }

    private func loadEnvelopeForMutation() throws -> Envelope? {
        let data: Data
        do {
            guard let storedData = try store.read() else { return nil }
            data = storedData
        } catch {
            throw ViewerProfileRepositoryError.storageFailed
        }
        do {
            return try map(coder.decodeEnvelope(from: data))
        } catch {
            throw ViewerProfileRepositoryError.invalidStoredState
        }
    }

    private func loadEnvelope() throws -> Envelope? {
        guard let data = try store.read() else { return nil }
        return try map(coder.decodeEnvelope(from: data))
    }

    private func persist(_ envelope: Envelope) throws {
        let data: Data
        do {
            data = try coder.encodeEnvelope(map(envelope))
        } catch {
            throw ViewerProfileRepositoryError.encodingFailed
        }
        do {
            try store.replace(with: data)
        } catch {
            throw ViewerProfileRepositoryError.storageFailed
        }
    }

    private func validate(_ profile: ViewerProfile) throws {
        do {
            try ViewerProfileValidator.validate(
                profile: profile,
                catalog: catalog(for: profile.catalogID)
            )
        } catch let error as ViewerProfileValidationError {
            throw ViewerProfileRepositoryError.validation(error)
        }
    }

    private func validate(_ draft: FirstOnboardingDraft) throws {
        do {
            try ViewerProfileValidator.validate(
                draft: draft,
                catalog: catalog(for: draft.catalogID)
            )
        } catch let error as ViewerProfileValidationError {
            throw ViewerProfileRepositoryError.validation(error)
        }
    }

    private func validate(_ draft: RecalibrationDraft) throws {
        do {
            try ViewerProfileValidator.validate(
                draft: draft,
                catalog: catalog(for: draft.catalogID)
            )
        } catch let error as ViewerProfileValidationError {
            throw ViewerProfileRepositoryError.validation(error)
        }
    }

    private func catalog(for id: CalibrationCatalogID) throws -> CalibrationCatalog {
        guard let catalog = catalogs[id] else {
            throw ViewerProfileValidationError.unsupportedCatalog
        }
        return catalog
    }

    private func map(_ dto: ViewerStateEnvelopeV1DTO) throws -> Envelope {
        let profile = try dto.completedProfile.map(map)
        let draft = try dto.profileDraft.map(map)
        let envelope = Envelope(profile: profile, draft: draft)
        switch (profile, draft) {
            case (nil, nil), (nil, .firstOnboarding), (_?, nil), (_?, .recalibration):
                return envelope
            case (nil, .recalibration), (_?, .firstOnboarding):
                throw ViewerProfileValidationError.inconsistentProgress
        }
    }

    private func map(_ dto: ViewerProfileV1DTO) throws -> ViewerProfile {
        let catalogID = CalibrationCatalogID(rawValue: dto.calibrationCatalogVersion)
        let profile = try ViewerProfile(
            profileSchemaVersion: dto.profileSchemaVersion,
            catalogID: catalogID,
            region: ViewingRegion(code: dto.regionCode),
            selectedServices: services(from: dto.selectedProviderIDs),
            reactions: reactions(from: dto.reactionsByMovieID)
        )
        try ViewerProfileValidator.validate(profile: profile, catalog: catalog(for: catalogID))
        return profile
    }

    private func map(_ dto: ViewerProfileDraftV1DTO) throws -> ViewerProfileDraft {
        switch dto.kind {
            case .firstOnboarding:
                guard dto.recalibration == nil, let payload = dto.firstOnboarding else {
                    throw ViewerProfileValidationError.inconsistentProgress
                }
                return try .firstOnboarding(map(payload))
            case .recalibration:
                guard dto.firstOnboarding == nil, let payload = dto.recalibration else {
                    throw ViewerProfileValidationError.inconsistentProgress
                }
                return try .recalibration(map(payload))
        }
    }

    private func map(_ dto: FirstOnboardingDraftV1DTO) throws -> FirstOnboardingDraft {
        guard let step = FirstOnboardingStep(rawValue: dto.currentStep) else {
            throw ViewerProfileValidationError.inconsistentProgress
        }
        let catalogID = CalibrationCatalogID(rawValue: dto.calibrationCatalogVersion)
        let draft = try FirstOnboardingDraft(
            catalogID: catalogID,
            step: step,
            selectedServices: services(from: dto.selectedProviderIDs),
            reactions: reactions(from: dto.reactionsByMovieID),
            currentCatalogPosition: dto.currentCatalogPosition,
            optionalExtensionAccepted: dto.optionalExtensionAccepted
        )
        try ViewerProfileValidator.validate(draft: draft, catalog: catalog(for: catalogID))
        return draft
    }

    private func map(_ dto: RecalibrationDraftV1DTO) throws -> RecalibrationDraft {
        let catalogID = CalibrationCatalogID(rawValue: dto.calibrationCatalogVersion)
        let draft = try RecalibrationDraft(
            catalogID: catalogID,
            reactions: reactions(from: dto.reactionsByMovieID),
            currentCatalogPosition: dto.currentCatalogPosition,
            optionalExtensionAccepted: dto.optionalExtensionAccepted
        )
        try ViewerProfileValidator.validate(draft: draft, catalog: catalog(for: catalogID))
        return draft
    }

    private func services(from ids: [Int]) throws -> [PilotStreamingService] {
        let allowlist = Dictionary(
            uniqueKeysWithValues: PilotStreamingService.allowlist.map { ($0.providerID, $0) }
        )
        let services = try ids.map { id in
            guard let service = allowlist[id] else {
                throw ViewerProfileValidationError.unsupportedService
            }
            return service
        }
        try ViewerProfileValidator.validateServices(services)
        return services
    }

    private func reactions(from values: [Int: String]) throws -> [Int: CalibrationReaction] {
        try values.mapValues { value in
            guard let reaction = CalibrationReaction(rawValue: value) else {
                throw ViewerProfileValidationError.inconsistentProgress
            }
            return reaction
        }
    }

    private func map(_ envelope: Envelope) -> ViewerStateEnvelopeV1DTO {
        ViewerStateEnvelopeV1DTO(
            envelopeSchemaVersion: ViewerStateEnvelopeV1DTO.schemaVersion,
            completedProfile: envelope.profile.map(map),
            profileDraft: envelope.draft.map(map)
        )
    }

    private func map(_ profile: ViewerProfile) -> ViewerProfileV1DTO {
        ViewerProfileV1DTO(
            profileSchemaVersion: profile.profileSchemaVersion,
            calibrationCatalogVersion: profile.catalogID.rawValue,
            regionCode: profile.region.code,
            selectedProviderIDs: profile.selectedServices.map(\.providerID),
            reactionsByMovieID: profile.reactions.mapValues(\.rawValue)
        )
    }

    private func map(_ draft: ViewerProfileDraft) -> ViewerProfileDraftV1DTO {
        switch draft {
            case let .firstOnboarding(payload):
                ViewerProfileDraftV1DTO(
                    kind: .firstOnboarding,
                    firstOnboarding: map(payload),
                    recalibration: nil
                )
            case let .recalibration(payload):
                ViewerProfileDraftV1DTO(
                    kind: .recalibration,
                    firstOnboarding: nil,
                    recalibration: map(payload)
                )
        }
    }

    private func map(_ draft: FirstOnboardingDraft) -> FirstOnboardingDraftV1DTO {
        FirstOnboardingDraftV1DTO(
            calibrationCatalogVersion: draft.catalogID.rawValue,
            currentStep: draft.step.rawValue,
            selectedProviderIDs: draft.selectedServices.map(\.providerID),
            reactionsByMovieID: draft.reactions.mapValues(\.rawValue),
            currentCatalogPosition: draft.currentCatalogPosition,
            optionalExtensionAccepted: draft.optionalExtensionAccepted
        )
    }

    private func map(_ draft: RecalibrationDraft) -> RecalibrationDraftV1DTO {
        RecalibrationDraftV1DTO(
            calibrationCatalogVersion: draft.catalogID.rawValue,
            reactionsByMovieID: draft.reactions.mapValues(\.rawValue),
            currentCatalogPosition: draft.currentCatalogPosition,
            optionalExtensionAccepted: draft.optionalExtensionAccepted
        )
    }
}

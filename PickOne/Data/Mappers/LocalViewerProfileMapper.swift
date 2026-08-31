import Foundation

enum LocalViewerProfileMappingError: Error, Equatable, Sendable {
    case invalidState
    case unsupportedCatalog
}

struct LocalViewerProfileMapper: Sendable {
    private static let bundledUpdatedAt = Date(timeIntervalSince1970: 1_787_097_600)

    func loadState(
        from envelope: LocalViewerStateEnvelopeV2DTO,
        snapshot: ViewerMovieStateSnapshot
    ) throws -> ViewerProfileLoadState {
        let profile = try envelope.viewerProfileState.completedProfile.map {
            try map($0, snapshot: snapshot)
        }
        let draft = try envelope.viewerProfileState.profileDraft.map(map)

        return switch (profile, draft) {
            case (nil, nil): .absent
            case (nil, let .firstOnboarding(draft)): .firstOnboarding(draft)
            case let (profile?, nil): .completed(profile: profile, recalibrationDraft: nil)
            case let (profile?, .recalibration(draft)):
                .completed(profile: profile, recalibrationDraft: draft)
            case (nil, .recalibration), (_?, .firstOnboarding):
                throw LocalViewerProfileMappingError.invalidState
        }
    }

    func firstOnboardingDraft(
        catalog: CalibrationCatalog
    ) throws -> ViewerProfileDraftV2DTO {
        try map(.firstOnboarding(.empty(catalog: catalog)), frozenCatalog: frozen(catalog))
    }

    func recalibrationDraft(
        catalog: CalibrationCatalog
    ) throws -> ViewerProfileDraftV2DTO {
        try map(.recalibration(.empty(catalog: catalog)), frozenCatalog: frozen(catalog))
    }

    func beginningCalibration(
        from draft: FirstOnboardingDraft,
        snapshot: CalibrationCatalogSnapshot
    ) throws -> ViewerProfileDraftV2DTO {
        let updated = FirstOnboardingDraft(
            catalog: snapshot.catalog,
            step: .calibration,
            selectedServices: draft.selectedServices,
            reactions: [:],
            currentCatalogPosition: 0,
            optionalExtensionAccepted: false,
            isCatalogFrozen: true
        )
        return try map(
            .firstOnboarding(updated),
            frozenCatalog: frozen(snapshot)
        )
    }

    func recalibrationDraft(
        snapshot: CalibrationCatalogSnapshot
    ) throws -> ViewerProfileDraftV2DTO {
        try map(
            .recalibration(.empty(snapshot: snapshot)),
            frozenCatalog: frozen(snapshot)
        )
    }

    func replacing(
        _ dto: ViewerProfileDraftV2DTO,
        with draft: ViewerProfileDraft
    ) throws -> ViewerProfileDraftV2DTO {
        try map(draft, frozenCatalog: dto.frozenCatalog)
    }

    func completedProfile(
        selectedServices: [PilotStreamingService],
        catalogReference: CalibrationCatalogReferenceV2DTO
    ) -> CompletedViewerProfileV2DTO {
        CompletedViewerProfileV2DTO(
            profileSchemaVersion: CompletedViewerProfileV2DTO.schemaVersion,
            lastCompletedCatalogReference: catalogReference,
            regionCode: ViewingRegion.spain.code,
            selectedProviderIDs: selectedServices.map(\.providerID)
        )
    }

    func map(
        _ dto: ViewerProfileDraftV2DTO
    ) throws -> ViewerProfileDraft {
        let catalog = try catalog(from: dto.frozenCatalog)
        let reactions = try reactions(from: dto.reactionsByMovieID)
        switch dto.kind {
            case .firstOnboarding:
                guard let rawStep = dto.currentStep,
                      let step = FirstOnboardingStep(rawValue: rawStep),
                      let providerIDs = dto.selectedProviderIDs
                else {
                    throw LocalViewerProfileMappingError.invalidState
                }
                let draft = try FirstOnboardingDraft(
                    catalog: catalog,
                    step: step,
                    selectedServices: services(from: providerIDs),
                    reactions: reactions,
                    currentCatalogPosition: dto.currentCatalogPosition,
                    optionalExtensionAccepted: dto.optionalExtensionAccepted,
                    isCatalogFrozen: dto.catalogIsFrozen ?? (step != .services)
                )
                try ViewerProfileValidator.validate(draft: draft, catalog: catalog)
                return .firstOnboarding(draft)
            case .recalibration:
                guard dto.currentStep == nil, dto.selectedProviderIDs == nil else {
                    throw LocalViewerProfileMappingError.invalidState
                }
                let draft = RecalibrationDraft(
                    catalog: catalog,
                    reactions: reactions,
                    currentCatalogPosition: dto.currentCatalogPosition,
                    optionalExtensionAccepted: dto.optionalExtensionAccepted
                )
                try ViewerProfileValidator.validate(draft: draft, catalog: catalog)
                return .recalibration(draft)
        }
    }

    func catalog(from dto: FrozenCalibrationCatalogV2DTO) throws -> CalibrationCatalog {
        let id = try catalogID(from: dto.reference)
        let movies = dto.movies.sorted { $0.order < $1.order }.compactMap { movie -> CalibrationMovie? in
            guard let block = CalibrationCatalogBlock(rawValue: movie.block) else { return nil }
            return CalibrationMovie(
                id: movie.movieID,
                titleKnownInSpain: movie.titleKnownInSpain,
                originalOrEnglishTitle: movie.originalOrEnglishTitle,
                year: movie.year,
                originalLanguage: movie.originalLanguage,
                block: block
            )
        }
        guard movies.count == dto.movies.count else {
            throw LocalViewerProfileMappingError.invalidState
        }
        return CalibrationCatalog(id: id, movies: movies)
    }

    private func map(
        _ dto: CompletedViewerProfileV2DTO,
        snapshot: ViewerMovieStateSnapshot
    ) throws -> ViewerProfile {
        try ViewerProfile(
            profileSchemaVersion: ViewerProfile.currentSchemaVersion,
            catalogID: catalogID(from: dto.lastCompletedCatalogReference),
            region: ViewingRegion(code: dto.regionCode),
            selectedServices: services(from: dto.selectedProviderIDs),
            reactions: ViewerMovieStateProjections.reactions(from: snapshot)
                .mapValues(CalibrationReaction.init)
        )
    }

    private func map(
        _ draft: ViewerProfileDraft,
        frozenCatalog: FrozenCalibrationCatalogV2DTO
    ) throws -> ViewerProfileDraftV2DTO {
        let catalog = try catalog(from: frozenCatalog)
        switch draft {
            case let .firstOnboarding(draft):
                try ViewerProfileValidator.validate(draft: draft, catalog: catalog)
                return ViewerProfileDraftV2DTO(
                    kind: .firstOnboarding,
                    frozenCatalog: frozenCatalog,
                    currentStep: draft.step.rawValue,
                    selectedProviderIDs: draft.selectedServices.map(\.providerID),
                    reactionsByMovieID: draft.reactions.mapValues(\.rawValue),
                    currentCatalogPosition: draft.currentCatalogPosition,
                    optionalExtensionAccepted: draft.optionalExtensionAccepted,
                    catalogIsFrozen: draft.isCatalogFrozen
                )
            case let .recalibration(draft):
                try ViewerProfileValidator.validate(draft: draft, catalog: catalog)
                return ViewerProfileDraftV2DTO(
                    kind: .recalibration,
                    frozenCatalog: frozenCatalog,
                    currentStep: nil,
                    selectedProviderIDs: nil,
                    reactionsByMovieID: draft.reactions.mapValues(\.rawValue),
                    currentCatalogPosition: draft.currentCatalogPosition,
                    optionalExtensionAccepted: draft.optionalExtensionAccepted,
                    catalogIsFrozen: true
                )
        }
    }

    private func frozen(
        _ catalog: CalibrationCatalog
    ) throws -> FrozenCalibrationCatalogV2DTO {
        guard catalog.id == .spainHouseholdV1 else {
            throw LocalViewerProfileMappingError.unsupportedCatalog
        }
        return FrozenCalibrationCatalogV2DTO(
            reference: CalibrationCatalogReferenceV2DTO(
                schemaVersion: 1,
                catalogID: "es-household-calibration",
                version: 1,
                regionCode: "ES",
                localeIdentifier: "es-ES"
            ),
            updatedAt: Self.bundledUpdatedAt,
            movies: catalog.movies.enumerated().map { order, movie in
                FrozenCalibrationMovieV2DTO(
                    order: order,
                    movieID: movie.id,
                    titleKnownInSpain: movie.titleKnownInSpain,
                    originalOrEnglishTitle: movie.originalOrEnglishTitle,
                    year: movie.year,
                    originalLanguage: movie.originalLanguage,
                    block: movie.block.rawValue
                )
            }
        )
    }

    func frozen(
        _ snapshot: CalibrationCatalogSnapshot
    ) throws -> FrozenCalibrationCatalogV2DTO {
        do {
            try CalibrationCatalogValidator.validate(
                snapshot,
                expectedRegion: snapshot.reference.region,
                expectedLocale: snapshot.reference.locale
            )
        } catch {
            throw LocalViewerProfileMappingError.invalidState
        }
        return FrozenCalibrationCatalogV2DTO(
            reference: CalibrationCatalogReferenceV2DTO(
                schemaVersion: snapshot.reference.schemaVersion,
                catalogID: snapshot.reference.catalogID,
                version: snapshot.reference.version,
                regionCode: snapshot.reference.region,
                localeIdentifier: snapshot.reference.locale
            ),
            updatedAt: snapshot.updatedAt,
            movies: snapshot.movies.enumerated().map { order, movie in
                FrozenCalibrationMovieV2DTO(
                    order: order,
                    movieID: movie.id,
                    titleKnownInSpain: movie.titleKnownInSpain,
                    originalOrEnglishTitle: movie.originalOrEnglishTitle,
                    year: movie.year,
                    originalLanguage: movie.originalLanguage,
                    block: movie.block.rawValue
                )
            }
        )
    }

    private func catalogID(
        from reference: CalibrationCatalogReferenceV2DTO
    ) throws -> CalibrationCatalogID {
        guard reference.schemaVersion == 1,
              !reference.catalogID.isEmpty,
              reference.version > 0,
              reference.regionCode.uppercased() == "ES",
              reference.localeIdentifier == "es-ES"
        else {
            throw LocalViewerProfileMappingError.unsupportedCatalog
        }
        return CalibrationCatalogReference(
            schemaVersion: reference.schemaVersion,
            catalogID: reference.catalogID,
            version: reference.version,
            region: reference.regionCode.uppercased(),
            locale: reference.localeIdentifier
        ).viewerProfileCatalogID
    }

    private func services(from providerIDs: [Int]) throws -> [PilotStreamingService] {
        let allowlist = Dictionary(
            uniqueKeysWithValues: PilotStreamingService.allowlist.map { ($0.providerID, $0) }
        )
        let services = try providerIDs.map { id in
            guard let service = allowlist[id] else {
                throw LocalViewerProfileMappingError.invalidState
            }
            return service
        }
        try ViewerProfileValidator.validateServices(services)
        return services
    }

    private func reactions(from values: [Int: String]) throws -> [Int: CalibrationReaction] {
        try values.mapValues { value in
            guard let reaction = CalibrationReaction(rawValue: value) else {
                throw LocalViewerProfileMappingError.invalidState
            }
            return reaction
        }
    }
}

private extension CalibrationReaction {
    init(_ reaction: MovieReaction) {
        switch reaction {
            case .loveIt: self = .loveIt
            case .likeIt: self = .likeIt
            case .itWasOkay: self = .itWasOkay
            case .didNotLikeIt: self = .didNotLikeIt
        }
    }
}

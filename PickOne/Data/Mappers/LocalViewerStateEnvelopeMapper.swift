import Foundation

enum LocalViewerStateEnvelopeMappingError: Error, Equatable, Sendable {
    case invalidEnvelope
    case unsupportedProfileSchema
    case unsupportedCatalog
}

struct LocalViewerStateEnvelopeMapper: Sendable {
    func snapshot(from envelope: LocalViewerStateEnvelopeV2DTO) throws -> ViewerMovieStateSnapshot {
        guard envelope.envelopeSchemaVersion == LocalViewerStateEnvelopeV2DTO.schemaVersion else {
            throw LocalViewerStateEnvelopeMappingError.invalidEnvelope
        }
        try validateProfileState(envelope.viewerProfileState)
        let states = try envelope.viewerMovieStates.map(map)
        return try ViewerMovieStateSnapshot(
            id: ViewerStateSnapshotID(rawValue: envelope.committedStateSnapshotID),
            states: states
        )
    }

    func replacingStates(
        in envelope: LocalViewerStateEnvelopeV2DTO,
        snapshotID: UUID,
        states: [ViewerMovieState]
    ) -> LocalViewerStateEnvelopeV2DTO {
        LocalViewerStateEnvelopeV2DTO(
            envelopeSchemaVersion: LocalViewerStateEnvelopeV2DTO.schemaVersion,
            committedStateSnapshotID: snapshotID,
            viewerProfileState: envelope.viewerProfileState,
            viewerMovieStates: states.sorted { $0.movieID < $1.movieID }.map(map),
            migrationRecord: envelope.migrationRecord
        )
    }

    func map(_ state: ViewerMovieState) -> ViewerMovieStateV2DTO {
        ViewerMovieStateV2DTO(
            movieID: state.movieID,
            title: state.displayMetadata.title,
            releaseYear: state.displayMetadata.releaseYear,
            posterPath: state.displayMetadata.posterPath,
            watchState: state.watchState == .watched ? "watched" : "unwatched",
            preference: state.preference.map(map),
            watchlistAddedAt: state.watchlistIntent?.addedAt,
            stateChangedAt: state.stateChangedAt
        )
    }

    private func map(_ dto: ViewerMovieStateV2DTO) throws -> ViewerMovieState {
        let watchState: MovieWatchState = switch dto.watchState {
            case "watched": .watched
            case "unwatched": .unwatched
            default: throw LocalViewerStateEnvelopeMappingError.invalidEnvelope
        }
        return try ViewerMovieState(
            movieID: dto.movieID,
            displayMetadata: MovieFeedbackMetadata(
                title: dto.title,
                releaseYear: dto.releaseYear,
                posterPath: dto.posterPath
            ),
            watchState: watchState,
            preference: dto.preference.map(map),
            watchlistIntent: dto.watchlistAddedAt.map(WatchlistIntent.init),
            stateChangedAt: dto.stateChangedAt
        )
    }

    private func map(_ preference: MoviePreference) -> ViewerMoviePreferenceV2DTO {
        switch preference {
            case let .reaction(reaction):
                ViewerMoviePreferenceV2DTO(
                    kind: "reaction",
                    reaction: reaction.rawValue
                )
            case .notInterested:
                ViewerMoviePreferenceV2DTO(kind: "notInterested", reaction: nil)
        }
    }

    private func map(_ dto: ViewerMoviePreferenceV2DTO) throws -> MoviePreference {
        switch (dto.kind, dto.reaction) {
            case let ("reaction", rawReaction?):
                guard let reaction = MovieReaction(rawValue: rawReaction) else {
                    throw LocalViewerStateEnvelopeMappingError.invalidEnvelope
                }
                return .reaction(reaction)
            case ("notInterested", nil):
                return .notInterested
            default:
                throw LocalViewerStateEnvelopeMappingError.invalidEnvelope
        }
    }

    private func validateProfileState(_ state: LocalViewerProfileStateV2DTO) throws {
        switch (state.completedProfile, state.profileDraft?.kind) {
            case (nil, nil), (nil, .firstOnboarding), (_?, nil), (_?, .recalibration):
                break
            case (nil, .recalibration), (_?, .firstOnboarding):
                throw LocalViewerStateEnvelopeMappingError.invalidEnvelope
        }

        if let profile = state.completedProfile {
            try validate(profile)
        }
        if let draft = state.profileDraft {
            try validate(draft)
        }
    }

    private func validate(_ profile: CompletedViewerProfileV2DTO) throws {
        guard profile.profileSchemaVersion == CompletedViewerProfileV2DTO.schemaVersion else {
            throw LocalViewerStateEnvelopeMappingError.unsupportedProfileSchema
        }
        guard profile.regionCode.uppercased() == ViewingRegion.spain.code,
              !profile.selectedProviderIDs.isEmpty
        else {
            throw LocalViewerStateEnvelopeMappingError.invalidEnvelope
        }
        try validate(profile.lastCompletedCatalogReference)
        _ = try services(from: profile.selectedProviderIDs)
    }

    private func validate(_ draft: ViewerProfileDraftV2DTO) throws {
        let catalog = try map(draft.frozenCatalog)
        let reactions = try draft.reactionsByMovieID.mapValues { rawValue in
            guard let reaction = CalibrationReaction(rawValue: rawValue) else {
                throw LocalViewerStateEnvelopeMappingError.invalidEnvelope
            }
            return reaction
        }

        do {
            switch draft.kind {
                case .firstOnboarding:
                    guard let rawStep = draft.currentStep,
                          let step = FirstOnboardingStep(rawValue: rawStep),
                          let selectedProviderIDs = draft.selectedProviderIDs
                    else {
                        throw LocalViewerStateEnvelopeMappingError.invalidEnvelope
                    }
                    try ViewerProfileValidator.validate(
                        draft: FirstOnboardingDraft(
                            catalogID: catalog.id,
                            step: step,
                            selectedServices: services(from: selectedProviderIDs),
                            reactions: reactions,
                            currentCatalogPosition: draft.currentCatalogPosition,
                            optionalExtensionAccepted: draft.optionalExtensionAccepted
                        ),
                        catalog: catalog
                    )
                case .recalibration:
                    guard draft.currentStep == nil, draft.selectedProviderIDs == nil else {
                        throw LocalViewerStateEnvelopeMappingError.invalidEnvelope
                    }
                    try ViewerProfileValidator.validate(
                        draft: RecalibrationDraft(
                            catalogID: catalog.id,
                            reactions: reactions,
                            currentCatalogPosition: draft.currentCatalogPosition,
                            optionalExtensionAccepted: draft.optionalExtensionAccepted
                        ),
                        catalog: catalog
                    )
            }
        } catch is ViewerProfileValidationError {
            throw LocalViewerStateEnvelopeMappingError.invalidEnvelope
        }
    }

    private func map(_ dto: FrozenCalibrationCatalogV2DTO) throws -> CalibrationCatalog {
        try validate(dto.reference)
        let movies = try dto.movies.sorted { $0.order < $1.order }.map { movie in
            guard movie.movieID > 0,
                  !movie.titleKnownInSpain.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                  !movie.originalOrEnglishTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                  (1000 ... 9999).contains(movie.year),
                  !movie.originalLanguage.isEmpty,
                  let block = CalibrationCatalogBlock(rawValue: movie.block)
            else {
                throw LocalViewerStateEnvelopeMappingError.invalidEnvelope
            }
            return CalibrationMovie(
                id: movie.movieID,
                titleKnownInSpain: movie.titleKnownInSpain,
                originalOrEnglishTitle: movie.originalOrEnglishTitle,
                year: movie.year,
                originalLanguage: movie.originalLanguage,
                block: block
            )
        }
        let orders = dto.movies.map(\.order)
        guard dto.movies.count == 21,
              Set(orders).count == orders.count,
              orders.sorted() == Array(0 ..< dto.movies.count),
              Set(movies.map(\.id)).count == movies.count,
              movies.count(where: { $0.block == .primary }) == 12,
              movies.count(where: { $0.block == .reserve }) == 3,
              movies.count(where: { $0.block == .optionalExtension }) == 6,
              movies.prefix(8).contains(where: { $0.originalLanguage != "en" })
        else {
            throw LocalViewerStateEnvelopeMappingError.invalidEnvelope
        }
        return CalibrationCatalog(
            id: CalibrationCatalogID(rawValue: dto.reference.catalogID),
            movies: movies
        )
    }

    private func validate(_ reference: CalibrationCatalogReferenceV2DTO) throws {
        guard reference.schemaVersion == 1,
              !reference.catalogID.isEmpty,
              reference.version > 0,
              reference.regionCode.uppercased() == ViewingRegion.spain.code,
              reference.localeIdentifier == "es-ES"
        else {
            throw LocalViewerStateEnvelopeMappingError.invalidEnvelope
        }
    }

    private func services(from ids: [Int]) throws -> [PilotStreamingService] {
        let allowlist = Dictionary(
            uniqueKeysWithValues: PilotStreamingService.allowlist.map { ($0.providerID, $0) }
        )
        let services = try ids.map { id in
            guard let service = allowlist[id] else {
                throw LocalViewerStateEnvelopeMappingError.invalidEnvelope
            }
            return service
        }
        do {
            try ViewerProfileValidator.validateServices(services)
        } catch {
            throw LocalViewerStateEnvelopeMappingError.invalidEnvelope
        }
        return services
    }
}

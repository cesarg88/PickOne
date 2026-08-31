import Foundation

enum LegacyViewerStateMigrationError: Error, Equatable, Sendable {
    case corruptData
    case unsupportedData
}

struct LegacyViewerStateMigrator: Sendable {
    private struct ProfileState: Sendable {
        let completedProfile: ViewerProfile?
        let draft: ViewerProfileDraft?
    }

    private let profileCoder: any ViewerProfileEnvelopeCoding
    private let catalogs: [CalibrationCatalogID: CalibrationCatalog]

    init(
        profileCoder: any ViewerProfileEnvelopeCoding = JSONViewerProfileEnvelopeCoder(),
        catalogs: [CalibrationCatalog] = [.spainHouseholdV1]
    ) {
        self.profileCoder = profileCoder
        self.catalogs = Dictionary(uniqueKeysWithValues: catalogs.map { ($0.id, $0) })
    }

    func migrate(
        profileData: Data?,
        watchlistData: Data?,
        snapshotID: UUID,
        at date: Date,
        source: LocalViewerStateMigrationRecordV2DTO.Source
    ) throws -> LocalViewerStateEnvelopeV2DTO {
        let profileState = try profileData.map(decodeProfile) ?? ProfileState(
            completedProfile: nil,
            draft: nil
        )
        let watchlist = try watchlistData.map(decodeWatchlist) ?? []
        let movieStates = try migrateMovieStates(
            profile: profileState.completedProfile,
            watchlist: watchlist,
            at: date
        )
        let completedProfileDTO: CompletedViewerProfileV2DTO? = if let completedProfile = profileState
            .completedProfile
        {
            try map(completedProfile)
        } else {
            nil
        }
        let envelope = try LocalViewerStateEnvelopeV2DTO(
            envelopeSchemaVersion: LocalViewerStateEnvelopeV2DTO.schemaVersion,
            committedStateSnapshotID: snapshotID,
            viewerProfileState: LocalViewerProfileStateV2DTO(
                completedProfile: completedProfileDTO,
                profileDraft: profileState.draft.map(map)
            ),
            viewerMovieStates: movieStates.map(LocalViewerStateEnvelopeMapper().map),
            migrationRecord: LocalViewerStateMigrationRecordV2DTO(
                source: source,
                resolvedAt: date
            )
        )
        _ = try LocalViewerStateEnvelopeMapper().snapshot(from: envelope)
        return envelope
    }

    private func decodeProfile(_ data: Data) throws -> ProfileState {
        let dto: ViewerStateEnvelopeV1DTO
        do {
            dto = try profileCoder.decodeEnvelope(from: data)
        } catch ViewerProfileCodingError.unsupportedVersion {
            throw LegacyViewerStateMigrationError.unsupportedData
        } catch {
            throw LegacyViewerStateMigrationError.corruptData
        }

        let completedProfile = try dto.completedProfile.map(map)
        let draft = try dto.profileDraft.map(map)
        switch (completedProfile, draft) {
            case (nil, nil), (nil, .firstOnboarding), (_?, nil), (_?, .recalibration):
                return ProfileState(completedProfile: completedProfile, draft: draft)
            case (nil, .recalibration), (_?, .firstOnboarding):
                throw LegacyViewerStateMigrationError.corruptData
        }
    }

    private func decodeWatchlist(_ data: Data) throws -> [PersistedWatchlistItem] {
        let items: [PersistedWatchlistItem]
        do {
            items = try JSONDecoder().decode([PersistedWatchlistItem].self, from: data)
        } catch {
            throw LegacyViewerStateMigrationError.corruptData
        }
        var movieIDs = Set<Int>()
        for item in items {
            guard item.movieId > 0,
                  movieIDs.insert(item.movieId).inserted,
                  !item.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            else {
                throw LegacyViewerStateMigrationError.corruptData
            }
        }
        return items
    }

    private func migrateMovieStates(
        profile: ViewerProfile?,
        watchlist: [PersistedWatchlistItem],
        at date: Date
    ) throws -> [ViewerMovieState] {
        let catalog: CalibrationCatalog? = if let profile {
            try self.catalog(for: profile.catalogID)
        } else {
            nil
        }
        let watchlistByID = Dictionary(uniqueKeysWithValues: watchlist.map { ($0.movieId, $0) })
        let reactionsByID = profile?.reactions.compactMapValues(MovieReaction.init) ?? [:]
        let movieIDs = Set(watchlistByID.keys).union(reactionsByID.keys)

        return try movieIDs.sorted().map { movieID in
            let reaction = reactionsByID[movieID]
            let watchlistItem = watchlistByID[movieID]
            let watched = reaction != nil || watchlistItem?.isWatched == true
            let metadata = try metadata(
                movieID: movieID,
                watchlistItem: watchlistItem,
                catalog: catalog
            )
            return try ViewerMovieState(
                movieID: movieID,
                displayMetadata: metadata,
                watchState: watched ? .watched : .unwatched,
                preference: reaction.map(MoviePreference.reaction),
                watchlistIntent: watched ? nil : watchlistItem.map { WatchlistIntent(addedAt: $0.addedAt) },
                stateChangedAt: reaction == nil ? watchlistDate(watchlistItem) : date
            )
        }
    }

    private func metadata(
        movieID: Int,
        watchlistItem: PersistedWatchlistItem?,
        catalog: CalibrationCatalog?
    ) throws -> MovieFeedbackMetadata {
        if let watchlistItem {
            return try MovieFeedbackMetadata(
                title: watchlistItem.title,
                releaseYear: watchlistItem.releaseYear,
                posterPath: watchlistItem.posterPath
            )
        }
        guard let movie = catalog?.movies.first(where: { $0.id == movieID }) else {
            throw LegacyViewerStateMigrationError.corruptData
        }
        return try MovieFeedbackMetadata(
            title: movie.titleKnownInSpain,
            releaseYear: movie.year,
            posterPath: nil
        )
    }

    private func watchlistDate(_ item: PersistedWatchlistItem?) throws -> Date {
        guard let item else {
            throw LegacyViewerStateMigrationError.corruptData
        }
        return item.addedAt
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
        do {
            try ViewerProfileValidator.validate(profile: profile, catalog: catalog(for: catalogID))
        } catch ViewerProfileValidationError.unsupportedCatalog {
            throw LegacyViewerStateMigrationError.unsupportedData
        } catch {
            throw LegacyViewerStateMigrationError.corruptData
        }
        return profile
    }

    private func map(_ dto: ViewerProfileDraftV1DTO) throws -> ViewerProfileDraft {
        switch dto.kind {
            case .firstOnboarding:
                guard dto.recalibration == nil, let payload = dto.firstOnboarding else {
                    throw LegacyViewerStateMigrationError.corruptData
                }
                return try .firstOnboarding(map(payload))
            case .recalibration:
                guard dto.firstOnboarding == nil, let payload = dto.recalibration else {
                    throw LegacyViewerStateMigrationError.corruptData
                }
                return try .recalibration(map(payload))
        }
    }

    private func map(_ dto: FirstOnboardingDraftV1DTO) throws -> FirstOnboardingDraft {
        let catalogID = CalibrationCatalogID(rawValue: dto.calibrationCatalogVersion)
        guard let step = FirstOnboardingStep(rawValue: dto.currentStep) else {
            throw LegacyViewerStateMigrationError.corruptData
        }
        let draft = try FirstOnboardingDraft(
            catalogID: catalogID,
            step: step,
            selectedServices: services(from: dto.selectedProviderIDs),
            reactions: reactions(from: dto.reactionsByMovieID),
            currentCatalogPosition: dto.currentCatalogPosition,
            optionalExtensionAccepted: dto.optionalExtensionAccepted
        )
        do {
            try ViewerProfileValidator.validate(draft: draft, catalog: catalog(for: catalogID))
        } catch ViewerProfileValidationError.unsupportedCatalog {
            throw LegacyViewerStateMigrationError.unsupportedData
        } catch {
            throw LegacyViewerStateMigrationError.corruptData
        }
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
        do {
            try ViewerProfileValidator.validate(draft: draft, catalog: catalog(for: catalogID))
        } catch ViewerProfileValidationError.unsupportedCatalog {
            throw LegacyViewerStateMigrationError.unsupportedData
        } catch {
            throw LegacyViewerStateMigrationError.corruptData
        }
        return draft
    }

    private func map(_ profile: ViewerProfile) throws -> CompletedViewerProfileV2DTO {
        let reference = try catalogReference(for: profile.catalogID)
        return CompletedViewerProfileV2DTO(
            profileSchemaVersion: CompletedViewerProfileV2DTO.schemaVersion,
            lastCompletedCatalogReference: reference,
            regionCode: profile.region.code,
            selectedProviderIDs: profile.selectedServices.map(\.providerID)
        )
    }

    private func map(_ draft: ViewerProfileDraft) throws -> ViewerProfileDraftV2DTO {
        switch draft {
            case let .firstOnboarding(draft):
                try ViewerProfileDraftV2DTO(
                    kind: .firstOnboarding,
                    frozenCatalog: frozenCatalog(for: draft.catalogID),
                    currentStep: draft.step.rawValue,
                    selectedProviderIDs: draft.selectedServices.map(\.providerID),
                    reactionsByMovieID: draft.reactions.mapValues(\.rawValue),
                    currentCatalogPosition: draft.currentCatalogPosition,
                    optionalExtensionAccepted: draft.optionalExtensionAccepted,
                    catalogIsFrozen: draft.step != .services
                )
            case let .recalibration(draft):
                try ViewerProfileDraftV2DTO(
                    kind: .recalibration,
                    frozenCatalog: frozenCatalog(for: draft.catalogID),
                    currentStep: nil,
                    selectedProviderIDs: nil,
                    reactionsByMovieID: draft.reactions.mapValues(\.rawValue),
                    currentCatalogPosition: draft.currentCatalogPosition,
                    optionalExtensionAccepted: draft.optionalExtensionAccepted,
                    catalogIsFrozen: true
                )
        }
    }

    private func frozenCatalog(for id: CalibrationCatalogID) throws -> FrozenCalibrationCatalogV2DTO {
        let catalog = try catalog(for: id)
        return try FrozenCalibrationCatalogV2DTO(
            reference: catalogReference(for: id),
            updatedAt: Date(timeIntervalSince1970: 1_787_097_600),
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

    private func catalogReference(
        for id: CalibrationCatalogID
    ) throws -> CalibrationCatalogReferenceV2DTO {
        guard id == .spainHouseholdV1 else {
            throw LegacyViewerStateMigrationError.unsupportedData
        }
        return CalibrationCatalogReferenceV2DTO(
            schemaVersion: 1,
            catalogID: "es-household-calibration",
            version: 1,
            regionCode: "ES",
            localeIdentifier: "es-ES"
        )
    }

    private func catalog(for id: CalibrationCatalogID) throws -> CalibrationCatalog {
        guard let catalog = catalogs[id] else {
            throw LegacyViewerStateMigrationError.unsupportedData
        }
        return catalog
    }

    private func services(from ids: [Int]) throws -> [PilotStreamingService] {
        let allowlist = Dictionary(
            uniqueKeysWithValues: PilotStreamingService.allowlist.map { ($0.providerID, $0) }
        )
        let services = try ids.map { id in
            guard let service = allowlist[id] else {
                throw LegacyViewerStateMigrationError.corruptData
            }
            return service
        }
        do {
            try ViewerProfileValidator.validateServices(services)
        } catch {
            throw LegacyViewerStateMigrationError.corruptData
        }
        return services
    }

    private func reactions(from values: [Int: String]) throws -> [Int: CalibrationReaction] {
        try values.mapValues { value in
            guard let reaction = CalibrationReaction(rawValue: value) else {
                throw LegacyViewerStateMigrationError.corruptData
            }
            return reaction
        }
    }
}

private extension MovieReaction {
    init?(_ reaction: CalibrationReaction) {
        switch reaction {
            case .loveIt: self = .loveIt
            case .likeIt: self = .likeIt
            case .itWasOkay: self = .itWasOkay
            case .didNotLikeIt: self = .didNotLikeIt
            case .haveNotSeenIt, .doNotKnowIt: return nil
        }
    }
}

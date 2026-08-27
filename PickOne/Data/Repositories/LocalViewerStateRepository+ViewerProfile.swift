import Foundation

extension LocalViewerStateRepository {
    func loadProfileState() -> ViewerProfileLoadState {
        do {
            let current = try resolve()
            let loadState = try profileMapper.loadState(
                from: current.envelope,
                snapshot: current.snapshot
            )
            destructiveResetAvailability = .unavailable
            return loadState
        } catch let failure as ExhaustedSourcesFailure {
            destructiveResetAvailability = .available
            return .recovery(profileRecoveryReason(for: failure.repositoryError))
        } catch let failure as ResolutionFailure {
            destructiveResetAvailability = .unavailable
            return .recovery(profileRecoveryReason(for: failure.repositoryError))
        } catch let error as LocalViewerProfileMappingError {
            destructiveResetAvailability = .unavailable
            return .recovery(error == .unsupportedCatalog ? .unsupportedVersion : .corruptData)
        } catch {
            destructiveResetAvailability = .unavailable
            return .recovery(.corruptData)
        }
    }

    func successfulRecoveryNotice() -> ViewerStateRecoveryNotice? {
        guard let state = try? resolve() else { return nil }
        return switch state.envelope.migrationRecord.source {
            case .previousRecovery, .legacyRecovery: .olderSnapshot
            case .freshInstall, .legacyMigration: nil
        }
    }

    func resetUnrecoverableViewerState() throws {
        guard legacyResetter != nil else {
            throw ViewerStateDestructiveRecoveryError.resetUnavailable
        }
        guard destructiveResetAvailability == .available else {
            throw ViewerStateDestructiveRecoveryError.stateIsRecoverable
        }

        resolvedState = nil
        do {
            try fileStore.removeAllViewerState()
            try legacyResetter?.removeLegacyViewerState()
            let envelope = try migrator.migrate(
                profileData: nil,
                watchlistData: nil,
                snapshotID: makeSnapshotID(),
                at: now(),
                source: .freshInstall
            )
            resolvedState = try publishInitial(envelope)
            destructiveResetAvailability = .unavailable
        } catch let error as ViewerStateDestructiveRecoveryError {
            throw error
        } catch {
            throw ViewerStateDestructiveRecoveryError.resetFailed
        }
    }

    func destructiveRecoveryAvailability() -> DestructiveRecoveryAvailability {
        guard legacyResetter != nil else { return .unavailable }
        return destructiveResetAvailability
    }

    func beginFirstOnboardingProfile(
        catalog: CalibrationCatalog
    ) throws -> FirstOnboardingDraft {
        let current = try resolveForProfileMutation()
        guard current.envelope.viewerProfileState.completedProfile == nil,
              current.envelope.viewerProfileState.profileDraft == nil
        else {
            throw ViewerProfileRepositoryError.invalidTransition
        }
        let dto: ViewerProfileDraftV2DTO
        do {
            dto = try profileMapper.firstOnboardingDraft(catalog: catalog)
        } catch {
            throw profileError(error)
        }
        let persisted = try persistProfileState(
            LocalViewerProfileStateV2DTO(completedProfile: nil, profileDraft: dto),
            states: current.snapshot.states,
            current: current,
            recommendationInputsChanged: false
        )
        guard case let .firstOnboarding(draft) = try mappedProfileState(persisted) else {
            throw ViewerProfileRepositoryError.invalidStoredState
        }
        return draft
    }

    func saveFirstOnboardingProfileDraft(
        _ draft: FirstOnboardingDraft
    ) throws {
        let current = try resolveForProfileMutation()
        guard current.envelope.viewerProfileState.completedProfile == nil,
              let storedDraft = current.envelope.viewerProfileState.profileDraft,
              storedDraft.kind == .firstOnboarding
        else {
            throw ViewerProfileRepositoryError.invalidTransition
        }
        let replacement: ViewerProfileDraftV2DTO
        do {
            replacement = try profileMapper.replacing(
                storedDraft,
                with: .firstOnboarding(draft)
            )
        } catch {
            throw profileError(error)
        }
        _ = try persistProfileState(
            LocalViewerProfileStateV2DTO(
                completedProfile: nil,
                profileDraft: replacement
            ),
            states: current.snapshot.states,
            current: current,
            recommendationInputsChanged: false
        )
    }

    func completeFirstOnboardingProfile() throws -> ViewerProfile {
        let current = try resolveForProfileMutation()
        guard current.envelope.viewerProfileState.completedProfile == nil,
              let storedDraft = current.envelope.viewerProfileState.profileDraft,
              storedDraft.kind == .firstOnboarding,
              case let .firstOnboarding(draft) = try mappedDraft(storedDraft),
              draft.step == .completion
        else {
            throw ViewerProfileRepositoryError.invalidTransition
        }
        let states = try applyingInformativeResponses(
            from: storedDraft,
            to: current.snapshot
        )
        let completed = profileMapper.completedProfile(
            selectedServices: draft.selectedServices,
            catalogReference: storedDraft.frozenCatalog.reference
        )
        let persisted = try persistProfileState(
            LocalViewerProfileStateV2DTO(
                completedProfile: completed,
                profileDraft: nil
            ),
            states: states,
            current: current,
            recommendationInputsChanged: true
        )
        return try completedProfile(from: persisted)
    }

    func beginRecalibrationProfile(
        catalog: CalibrationCatalog
    ) throws -> RecalibrationDraft {
        let current = try resolveForProfileMutation()
        guard let profile = current.envelope.viewerProfileState.completedProfile,
              current.envelope.viewerProfileState.profileDraft == nil
        else {
            throw ViewerProfileRepositoryError.invalidTransition
        }
        let dto: ViewerProfileDraftV2DTO
        do {
            dto = try profileMapper.recalibrationDraft(catalog: catalog)
        } catch {
            throw profileError(error)
        }
        let persisted = try persistProfileState(
            LocalViewerProfileStateV2DTO(
                completedProfile: profile,
                profileDraft: dto
            ),
            states: current.snapshot.states,
            current: current,
            recommendationInputsChanged: false
        )
        guard case let .completed(_, draft?) = try mappedProfileState(persisted) else {
            throw ViewerProfileRepositoryError.invalidStoredState
        }
        return draft
    }

    func saveRecalibrationProfileDraft(
        _ draft: RecalibrationDraft
    ) throws {
        let current = try resolveForProfileMutation()
        guard let profile = current.envelope.viewerProfileState.completedProfile,
              let storedDraft = current.envelope.viewerProfileState.profileDraft,
              storedDraft.kind == .recalibration
        else {
            throw ViewerProfileRepositoryError.invalidTransition
        }
        let replacement: ViewerProfileDraftV2DTO
        do {
            replacement = try profileMapper.replacing(
                storedDraft,
                with: .recalibration(draft)
            )
        } catch {
            throw profileError(error)
        }
        _ = try persistProfileState(
            LocalViewerProfileStateV2DTO(
                completedProfile: profile,
                profileDraft: replacement
            ),
            states: current.snapshot.states,
            current: current,
            recommendationInputsChanged: false
        )
    }

    func completeRecalibrationProfile() throws -> ViewerProfile {
        let current = try resolveForProfileMutation()
        guard let activeProfile = current.envelope.viewerProfileState.completedProfile,
              let storedDraft = current.envelope.viewerProfileState.profileDraft,
              storedDraft.kind == .recalibration,
              case let .recalibration(draft) = try mappedDraft(storedDraft)
        else {
            throw ViewerProfileRepositoryError.invalidTransition
        }
        let catalog: CalibrationCatalog
        do {
            catalog = try profileMapper.catalog(from: storedDraft.frozenCatalog)
        } catch {
            throw profileError(error)
        }
        let destination = CalibrationFlow.destination(
            position: draft.currentCatalogPosition,
            reactions: draft.reactions,
            optionalExtensionAccepted: draft.optionalExtensionAccepted,
            catalog: catalog
        )
        guard destination == .completion || destination == .lowSignalDecision else {
            throw ViewerProfileRepositoryError.invalidTransition
        }
        let states = try applyingInformativeResponses(
            from: storedDraft,
            to: current.snapshot
        )
        let completed = CompletedViewerProfileV2DTO(
            profileSchemaVersion: CompletedViewerProfileV2DTO.schemaVersion,
            lastCompletedCatalogReference: storedDraft.frozenCatalog.reference,
            regionCode: activeProfile.regionCode,
            selectedProviderIDs: activeProfile.selectedProviderIDs
        )
        let inputsChanged = completed != activeProfile || states != current.snapshot.states
        let persisted = try persistProfileState(
            LocalViewerProfileStateV2DTO(
                completedProfile: completed,
                profileDraft: nil
            ),
            states: states,
            current: current,
            recommendationInputsChanged: inputsChanged
        )
        return try completedProfile(from: persisted)
    }

    func updateProfileServices(
        _ services: [PilotStreamingService]
    ) throws -> ViewerProfile {
        do {
            try ViewerProfileValidator.validateServices(services)
        } catch let error as ViewerProfileValidationError {
            throw ViewerProfileRepositoryError.validation(error)
        }
        guard !services.isEmpty else {
            throw ViewerProfileRepositoryError.validation(.emptyServiceSelection)
        }
        let current = try resolveForProfileMutation()
        guard let activeProfile = current.envelope.viewerProfileState.completedProfile else {
            throw ViewerProfileRepositoryError.invalidTransition
        }
        let completed = CompletedViewerProfileV2DTO(
            profileSchemaVersion: activeProfile.profileSchemaVersion,
            lastCompletedCatalogReference: activeProfile.lastCompletedCatalogReference,
            regionCode: activeProfile.regionCode,
            selectedProviderIDs: services.map(\.providerID)
        )
        let persisted = try persistProfileState(
            LocalViewerProfileStateV2DTO(
                completedProfile: completed,
                profileDraft: current.envelope.viewerProfileState.profileDraft
            ),
            states: current.snapshot.states,
            current: current,
            recommendationInputsChanged: completed != activeProfile
        )
        return try completedProfile(from: persisted)
    }

    func resetProfileDraft() throws {
        let current = try resolveForProfileMutation()
        let profileState = LocalViewerProfileStateV2DTO(
            completedProfile: current.envelope.viewerProfileState.completedProfile,
            profileDraft: nil
        )
        _ = try persistProfileState(
            profileState,
            states: current.snapshot.states,
            current: current,
            recommendationInputsChanged: false
        )
    }

    func resetProfilePreferences() throws {
        let current = try resolveForProfileMutation()
        let states = try current.snapshot.states.compactMap { state in
            switch state.preference {
                case .reaction:
                    try ViewerMovieState(
                        movieID: state.movieID,
                        displayMetadata: state.displayMetadata,
                        watchState: .watched,
                        preference: nil,
                        watchlistIntent: nil,
                        stateChangedAt: state.stateChangedAt
                    )
                case .notInterested:
                    nil
                case nil:
                    state
            }
        }
        let profileState = LocalViewerProfileStateV2DTO(
            completedProfile: nil,
            profileDraft: nil
        )
        let inputsChanged = profileState != current.envelope.viewerProfileState ||
            states != current.snapshot.states
        _ = try persistProfileState(
            profileState,
            states: states,
            current: current,
            recommendationInputsChanged: inputsChanged
        )
    }

    private func persistProfileState(
        _ profileState: LocalViewerProfileStateV2DTO,
        states: [ViewerMovieState],
        current: ResolvedState,
        recommendationInputsChanged: Bool
    ) throws -> ResolvedState {
        let unchanged = profileState == current.envelope.viewerProfileState &&
            states == current.snapshot.states
        if unchanged {
            return current
        }
        let snapshotID = recommendationInputsChanged
            ? freshSnapshotID(excluding: current.snapshot.id.rawValue)
            : current.snapshot.id.rawValue
        let envelope = LocalViewerStateEnvelopeV2DTO(
            envelopeSchemaVersion: LocalViewerStateEnvelopeV2DTO.schemaVersion,
            committedStateSnapshotID: snapshotID,
            viewerProfileState: profileState,
            viewerMovieStates: states.sorted { $0.movieID < $1.movieID }.map(mapper.map),
            migrationRecord: current.envelope.migrationRecord
        )
        do {
            let persisted = try persistMutation(envelope, replacing: current)
            resolvedState = persisted
            return persisted
        } catch ViewerMovieStateRepositoryError.encodingFailure {
            throw ViewerProfileRepositoryError.encodingFailed
        } catch {
            throw ViewerProfileRepositoryError.storageFailed
        }
    }

    private func applyingInformativeResponses(
        from draft: ViewerProfileDraftV2DTO,
        to snapshot: ViewerMovieStateSnapshot
    ) throws -> [ViewerMovieState] {
        var states = Dictionary(
            uniqueKeysWithValues: snapshot.states.map { ($0.movieID, $0) }
        )
        let movies = Dictionary(
            uniqueKeysWithValues: draft.frozenCatalog.movies.map { ($0.movieID, $0) }
        )
        for movieID in draft.reactionsByMovieID.keys.sorted() {
            guard let rawReaction = draft.reactionsByMovieID[movieID],
                  let calibrationReaction = CalibrationReaction(rawValue: rawReaction)
            else {
                throw ViewerProfileRepositoryError.invalidStoredState
            }
            guard let reaction = movieReaction(from: calibrationReaction) else { continue }
            guard let movie = movies[movieID] else {
                throw ViewerProfileRepositoryError.invalidStoredState
            }
            let metadata: MovieFeedbackMetadata
            do {
                metadata = try MovieFeedbackMetadata(
                    title: movie.titleKnownInSpain,
                    releaseYear: movie.year,
                    posterPath: states[movieID]?.displayMetadata.posterPath
                )
            } catch {
                throw ViewerProfileRepositoryError.invalidStoredState
            }
            do {
                let reduction = try ViewerMovieStateReducer.reduce(
                    current: states[movieID],
                    transition: ViewerMovieStateTransition(
                        movieID: movieID,
                        action: .assignReaction(reaction)
                    ),
                    metadata: metadata,
                    at: now()
                )
                states[movieID] = reduction.state
            } catch {
                throw ViewerProfileRepositoryError.invalidStoredState
            }
        }
        return states.values.sorted { $0.movieID < $1.movieID }
    }

    private func mappedDraft(
        _ dto: ViewerProfileDraftV2DTO
    ) throws -> ViewerProfileDraft {
        do {
            return try profileMapper.map(dto)
        } catch {
            throw profileError(error)
        }
    }

    private func mappedProfileState(
        _ state: ResolvedState
    ) throws -> ViewerProfileLoadState {
        do {
            return try profileMapper.loadState(
                from: state.envelope,
                snapshot: state.snapshot
            )
        } catch {
            throw profileError(error)
        }
    }

    private func completedProfile(from state: ResolvedState) throws -> ViewerProfile {
        guard case let .completed(profile, _) = try mappedProfileState(state) else {
            throw ViewerProfileRepositoryError.invalidStoredState
        }
        return profile
    }

    private func resolveForProfileMutation() throws -> ResolvedState {
        do {
            return try resolve()
        } catch {
            throw ViewerProfileRepositoryError.invalidStoredState
        }
    }

    private func profileError(_ error: Error) -> ViewerProfileRepositoryError {
        if let validation = error as? ViewerProfileValidationError {
            return .validation(validation)
        }
        if error as? LocalViewerProfileMappingError == .unsupportedCatalog {
            return .validation(.unsupportedCatalog)
        }
        return .invalidStoredState
    }

    private func profileRecoveryReason(
        for error: ViewerMovieStateRepositoryError
    ) -> ViewerProfileRecoveryReason {
        switch error {
            case .unsupportedSchema: .unsupportedVersion
            case .corruptData, .migrationFailure: .corruptData
            case .invalidMovieID, .invalidTransition, .quarantineFailure,
                 .encodingFailure, .previousCopyFailure, .replacementFailure,
                 .loadFailure:
                .loadFailed
        }
    }

    private func movieReaction(
        from reaction: CalibrationReaction
    ) -> MovieReaction? {
        switch reaction {
            case .loveIt: .loveIt
            case .likeIt: .likeIt
            case .itWasOkay: .itWasOkay
            case .didNotLikeIt: .didNotLikeIt
            case .haveNotSeenIt, .doNotKnowIt: nil
        }
    }
}

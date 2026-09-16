import Foundation

extension LocalViewerStateRepository {
    func recoverAfterCurrentFailure(
        reason: ViewerMovieStateRepositoryError?,
        recoveryReason: ViewerMovieStateRecoveryReason?
    ) throws -> ResolvedState {
        let previousData: Data?
        do {
            previousData = try fileStore.readPrevious()
        } catch {
            throw failure(.loadFailure, .loadFailure)
        }
        if let previousData {
            do {
                let recovered = try recoverPreviousData(previousData)
                resolvedState = recovered
                return recovered
            } catch let codingError as LocalViewerStateCodingError {
                try quarantine(previousData, source: .previous)
                return try migrateOrCreate(
                    currentFailure: reason ?? repositoryError(for: codingError),
                    recoveryReason: recoveryReason ?? self.recoveryReason(for: codingError),
                    recoveringCurrentState: true,
                    invalidPreviousWasQuarantined: true
                )
            } catch let mappingError as LocalViewerStateEnvelopeMappingError {
                try quarantine(previousData, source: .previous)
                return try migrateOrCreate(
                    currentFailure: reason ?? repositoryError(for: mappingError),
                    recoveryReason: recoveryReason ?? self.recoveryReason(for: mappingError),
                    recoveringCurrentState: true,
                    invalidPreviousWasQuarantined: true
                )
            } catch let failure as ResolutionFailure {
                throw failure
            } catch {
                try quarantine(previousData, source: .previous)
                return try migrateOrCreate(
                    currentFailure: reason ?? .corruptData,
                    recoveryReason: recoveryReason ?? .corruptData,
                    recoveringCurrentState: true,
                    invalidPreviousWasQuarantined: true
                )
            }
        }

        return try migrateOrCreate(
            currentFailure: reason,
            recoveryReason: recoveryReason,
            recoveringCurrentState: reason != nil,
            invalidPreviousWasQuarantined: false
        )
    }

    private func migrateOrCreate(
        currentFailure: ViewerMovieStateRepositoryError?,
        recoveryReason: ViewerMovieStateRecoveryReason?,
        recoveringCurrentState: Bool,
        invalidPreviousWasQuarantined: Bool
    ) throws -> ResolvedState {
        let profileData: Data?
        let watchlistData: Data?
        do {
            profileData = try legacySource.readProfile()
            watchlistData = try legacySource.readWatchlist()
        } catch {
            throw failure(.migrationFailure, .migrationFailure)
        }

        let hasLegacyData = profileData != nil || watchlistData != nil
        guard hasLegacyData || currentFailure == nil else {
            throw exhaustedSourcesFailure(
                currentFailure ?? .migrationFailure,
                recoveryReason ?? .migrationFailure
            )
        }

        let source: LocalViewerStateMigrationRecordV2DTO.Source = if hasLegacyData {
            recoveringCurrentState ? .legacyRecovery : .legacyMigration
        } else {
            .freshInstall
        }
        let envelope: LocalViewerStateEnvelopeV4DTO
        do {
            envelope = try migrator.migrate(
                profileData: profileData,
                watchlistData: watchlistData,
                snapshotID: makeSnapshotID(),
                suppressionEpochID: makeSuppressionEpochID(),
                at: now(),
                source: source
            )
        } catch {
            if hasLegacyData {
                throw exhaustedSourcesFailure(.migrationFailure, .migrationFailure)
            }
            throw failure(.migrationFailure, .migrationFailure)
        }
        let persisted = try publishInitial(
            envelope,
            clearPrevious: invalidPreviousWasQuarantined
        )
        resolvedState = persisted
        return persisted
    }

    private func decodeCurrent(_ data: Data) throws -> ResolvedState {
        guard case let .currentV4(envelope) = try coder.decode(data) else {
            throw LocalViewerStateCodingError.unsupportedSchema
        }
        let snapshot = try mapper.snapshot(from: envelope)
        return ResolvedState(envelope: envelope, snapshot: snapshot, activeBytes: data)
    }

    func resolveActiveData(_ data: Data) throws -> ResolvedState {
        switch try coder.decode(data) {
            case let .currentV4(envelope):
                let snapshot = try mapper.snapshot(from: envelope)
                return ResolvedState(envelope: envelope, snapshot: snapshot, activeBytes: data)
            case let .legacyV3(envelope):
                return try migrateActiveV3(envelope, original: data)
            case let .legacyV2(envelope):
                _ = try mapper.snapshot(from: envelope)
                let replacement = migrateV2(envelope)
                let encoded: Data
                do {
                    encoded = try encodeValidated(replacement)
                } catch let error as ViewerMovieStateRepositoryError {
                    throw failure(error, .replacementFailure)
                }
                do {
                    try fileStore.replacePrevious(with: data)
                } catch {
                    throw failure(.previousCopyFailure, .replacementFailure)
                }
                do {
                    try fileStore.replaceActive(with: encoded)
                } catch {
                    throw failure(.replacementFailure, .replacementFailure)
                }
                return try decodeCurrent(encoded)
        }
    }

    private func recoverPreviousData(_ data: Data) throws -> ResolvedState {
        switch try coder.decode(data) {
            case let .currentV4(envelope):
                return try republish(envelope, source: .previousRecovery)
            case let .legacyV3(envelope):
                return try republish(migrateV3(envelope), source: .previousRecovery)
            case let .legacyV2(envelope):
                _ = try mapper.snapshot(from: envelope)
                let replacement = LocalViewerStateEnvelopeV4DTO(
                    envelopeSchemaVersion: LocalViewerStateEnvelopeV4DTO.schemaVersion,
                    committedStateSnapshotID: freshSnapshotID(
                        excluding: envelope.committedStateSnapshotID
                    ),
                    recommendationSuppressionEpochID: makeSuppressionEpochID(),
                    viewerProfileState: envelope.viewerProfileState,
                    viewerMovieStates: envelope.viewerMovieStates,
                    migrationRecord: LocalViewerStateMigrationRecordV2DTO(
                        source: .previousRecovery,
                        resolvedAt: now()
                    )
                )
                return try publishInitial(replacement)
        }
    }

    private func migrateV3(_ envelope: LocalViewerStateEnvelopeV3DTO) throws -> LocalViewerStateEnvelopeV4DTO {
        var states = envelope.viewerMovieStates
        for index in states.indices {
            states[index].pickOneProvenance = nil
        }
        let replacement = LocalViewerStateEnvelopeV4DTO(
            envelopeSchemaVersion: 4, committedStateSnapshotID: envelope.committedStateSnapshotID,
            recommendationSuppressionEpochID: envelope.recommendationSuppressionEpochID,
            viewerProfileState: envelope.viewerProfileState, viewerMovieStates: states,
            migrationRecord: envelope.migrationRecord
        )
        _ = try mapper.snapshot(from: replacement)
        return replacement
    }

    private func migrateActiveV3(_ envelope: LocalViewerStateEnvelopeV3DTO, original: Data) throws -> ResolvedState {
        let replacement = try migrateV3(envelope)
        let encoded: Data
        do { encoded = try encodeValidated(replacement) } catch { throw failure(.encodingFailure, .replacementFailure) }
        do { try fileStore.replacePrevious(with: original) } catch { throw failure(
            .previousCopyFailure,
            .replacementFailure
        ) }
        do { try fileStore.replaceActive(with: encoded) } catch {
            throw failure(.replacementFailure, .replacementFailure)
        }
        return try decodeCurrent(encoded)
    }

    private func migrateV2(
        _ envelope: LocalViewerStateEnvelopeV2DTO
    ) -> LocalViewerStateEnvelopeV4DTO {
        LocalViewerStateEnvelopeV4DTO(
            envelopeSchemaVersion: LocalViewerStateEnvelopeV4DTO.schemaVersion,
            committedStateSnapshotID: envelope.committedStateSnapshotID,
            recommendationSuppressionEpochID: makeSuppressionEpochID(),
            viewerProfileState: envelope.viewerProfileState,
            viewerMovieStates: envelope.viewerMovieStates,
            migrationRecord: envelope.migrationRecord
        )
    }

    private func republish(
        _ envelope: LocalViewerStateEnvelopeV4DTO,
        source: LocalViewerStateMigrationRecordV2DTO.Source
    ) throws -> ResolvedState {
        let replacement = LocalViewerStateEnvelopeV4DTO(
            appliedConfirmationOperations: envelope.appliedConfirmationOperations,
            envelopeSchemaVersion: LocalViewerStateEnvelopeV4DTO.schemaVersion,
            committedStateSnapshotID: freshSnapshotID(
                excluding: envelope.committedStateSnapshotID
            ),
            recommendationSuppressionEpochID: envelope.recommendationSuppressionEpochID,
            viewerProfileState: envelope.viewerProfileState,
            viewerMovieStates: envelope.viewerMovieStates,
            migrationRecord: LocalViewerStateMigrationRecordV2DTO(
                source: source,
                resolvedAt: now()
            )
        )
        return try publishInitial(replacement)
    }

    func publishInitial(
        _ envelope: LocalViewerStateEnvelopeV4DTO,
        clearPrevious: Bool = false
    ) throws -> ResolvedState {
        let data: Data
        do {
            data = try encodeValidated(envelope)
        } catch let error as ViewerMovieStateRepositoryError {
            throw failure(error, .replacementFailure)
        }
        if clearPrevious {
            do {
                try fileStore.removePrevious()
            } catch {
                throw failure(.previousCopyFailure, .replacementFailure)
            }
        }
        do {
            try fileStore.replaceActive(with: data)
        } catch {
            throw failure(.replacementFailure, .replacementFailure)
        }
        return try decodeCurrent(data)
    }

    func persistMutation(
        _ envelope: LocalViewerStateEnvelopeV4DTO,
        replacing current: ResolvedState
    ) throws -> ResolvedState {
        let data = try encodeValidated(envelope)
        do {
            try fileStore.replacePrevious(with: current.activeBytes)
        } catch {
            throw ViewerMovieStateRepositoryError.previousCopyFailure
        }
        do {
            try fileStore.replaceActive(with: data)
        } catch {
            throw ViewerMovieStateRepositoryError.replacementFailure
        }
        return try decodeCurrent(data)
    }

    private func encodeValidated(_ envelope: LocalViewerStateEnvelopeV4DTO) throws -> Data {
        do {
            _ = try mapper.snapshot(from: envelope)
        } catch {
            throw ViewerMovieStateRepositoryError.corruptData
        }

        let data: Data
        do {
            data = try coder.encode(envelope)
        } catch {
            throw ViewerMovieStateRepositoryError.encodingFailure
        }
        do {
            _ = try decodeCurrent(data)
        } catch {
            throw ViewerMovieStateRepositoryError.encodingFailure
        }
        return data
    }

    func quarantine(
        _ data: Data,
        source: LocalViewerStateQuarantineSource
    ) throws {
        do {
            try fileStore.quarantine(data, source: source)
        } catch {
            throw failure(.quarantineFailure, .quarantineFailure)
        }
    }

    func repositoryError(
        for codingError: LocalViewerStateCodingError
    ) -> ViewerMovieStateRepositoryError {
        switch codingError {
            case .corruptData: .corruptData
            case .unsupportedSchema: .unsupportedSchema
        }
    }

    func recoveryReason(
        for codingError: LocalViewerStateCodingError
    ) -> ViewerMovieStateRecoveryReason {
        switch codingError {
            case .corruptData: .corruptData
            case .unsupportedSchema: .unsupportedSchema
        }
    }

    func repositoryError(
        for mappingError: LocalViewerStateEnvelopeMappingError
    ) -> ViewerMovieStateRepositoryError {
        switch mappingError {
            case .invalidEnvelope: .corruptData
            case .unsupportedProfileSchema, .unsupportedCatalog: .unsupportedSchema
        }
    }

    func recoveryReason(
        for mappingError: LocalViewerStateEnvelopeMappingError
    ) -> ViewerMovieStateRecoveryReason {
        switch mappingError {
            case .invalidEnvelope: .corruptData
            case .unsupportedProfileSchema, .unsupportedCatalog: .unsupportedSchema
        }
    }

    func failure(
        _ repositoryError: ViewerMovieStateRepositoryError,
        _ recoveryReason: ViewerMovieStateRecoveryReason
    ) -> ResolutionFailure {
        ResolutionFailure(
            repositoryError: repositoryError,
            recoveryReason: recoveryReason
        )
    }

    private func exhaustedSourcesFailure(
        _ repositoryError: ViewerMovieStateRepositoryError,
        _ recoveryReason: ViewerMovieStateRecoveryReason
    ) -> ExhaustedSourcesFailure {
        ExhaustedSourcesFailure(
            repositoryError: repositoryError,
            recoveryReason: recoveryReason
        )
    }

    func freshSnapshotID(excluding previousID: UUID) -> UUID {
        var candidate = makeSnapshotID()
        while candidate == previousID {
            candidate = makeSnapshotID()
        }
        return candidate
    }
}

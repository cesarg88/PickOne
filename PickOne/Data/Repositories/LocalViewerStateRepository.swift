import Foundation

actor LocalViewerStateRepository: ViewerMovieStateRepository {
    struct ResolvedState: Sendable {
        let envelope: LocalViewerStateEnvelopeV3DTO
        let snapshot: ViewerMovieStateSnapshot
        let activeBytes: Data
    }

    struct ResolutionFailure: Error, Sendable {
        let repositoryError: ViewerMovieStateRepositoryError
        let recoveryReason: ViewerMovieStateRecoveryReason
    }

    struct ExhaustedSourcesFailure: Error, Sendable {
        let repositoryError: ViewerMovieStateRepositoryError
        let recoveryReason: ViewerMovieStateRecoveryReason
    }

    let fileStore: any LocalViewerStateFileStore
    private let legacySource: any LegacyViewerStateSource
    let legacyResetter: (any LegacyViewerStateResetter)?
    private let coder: any LocalViewerStateEnvelopeCoding
    let mapper: LocalViewerStateEnvelopeMapper
    let profileMapper: LocalViewerProfileMapper
    let migrator: LegacyViewerStateMigrator
    let makeSnapshotID: @Sendable () -> UUID
    let makeSuppressionEpochID: @Sendable () -> UUID
    let now: @Sendable () -> Date
    var resolvedState: ResolvedState?
    var destructiveResetAvailability: DestructiveRecoveryAvailability = .unavailable

    init(
        fileStore: any LocalViewerStateFileStore,
        legacySource: any LegacyViewerStateSource,
        legacyResetter: (any LegacyViewerStateResetter)? = nil,
        coder: any LocalViewerStateEnvelopeCoding = JSONLocalViewerStateEnvelopeCoder(),
        mapper: LocalViewerStateEnvelopeMapper = LocalViewerStateEnvelopeMapper(),
        profileMapper: LocalViewerProfileMapper = LocalViewerProfileMapper(),
        migrator: LegacyViewerStateMigrator = LegacyViewerStateMigrator(),
        snapshotID: @escaping @Sendable () -> UUID = UUID.init,
        suppressionEpochID: @escaping @Sendable () -> UUID = UUID.init,
        now: @escaping @Sendable () -> Date = Date.init
    ) {
        self.fileStore = fileStore
        self.legacySource = legacySource
        self.legacyResetter = legacyResetter
        self.coder = coder
        self.mapper = mapper
        self.profileMapper = profileMapper
        self.migrator = migrator
        makeSnapshotID = snapshotID
        makeSuppressionEpochID = suppressionEpochID
        self.now = now
    }

    func apply(
        _ transition: ViewerMovieStateTransition,
        metadata: MovieFeedbackMetadata
    ) throws -> ViewerMovieStateChange {
        let current = try resolve()
        let reduction: ViewerMovieStateReduction
        do {
            reduction = try ViewerMovieStateReducer.reduce(
                current: current.snapshot.state(for: transition.movieID),
                transition: transition,
                metadata: metadata,
                at: now()
            )
        } catch let error as ViewerMovieStateTransitionError {
            throw ViewerMovieStateRepositoryError.invalidTransition(error)
        } catch {
            throw ViewerMovieStateRepositoryError.corruptData
        }

        if reduction.impact == .none, !reduction.metadataChanged {
            return ViewerMovieStateChange(
                state: reduction.state,
                impact: .none,
                snapshotID: current.snapshot.id
            )
        }

        var states = Dictionary(
            uniqueKeysWithValues: current.snapshot.states.map { ($0.movieID, $0) }
        )
        states[transition.movieID] = reduction.state
        let nextID = reduction.impact == .none
            ? current.snapshot.id.rawValue
            : freshSnapshotID(excluding: current.snapshot.id.rawValue)
        let envelope = mapper.replacingStates(
            in: current.envelope,
            snapshotID: nextID,
            states: Array(states.values)
        )
        let persisted = try persistMutation(envelope, replacing: current)
        resolvedState = persisted
        return ViewerMovieStateChange(
            state: reduction.state,
            impact: reduction.impact,
            snapshotID: persisted.snapshot.id
        )
    }

    func resolve() throws -> ResolvedState {
        if let resolvedState {
            return resolvedState
        }

        let activeData: Data?
        do {
            activeData = try fileStore.readActive()
        } catch {
            throw failure(.loadFailure, .loadFailure)
        }
        if let activeData {
            do {
                let resolved = try resolveActiveData(activeData)
                resolvedState = resolved
                return resolved
            } catch let codingError as LocalViewerStateCodingError {
                try quarantine(activeData, source: .active)
                return try recoverAfterCurrentFailure(
                    reason: repositoryError(for: codingError),
                    recoveryReason: recoveryReason(for: codingError)
                )
            } catch let mappingError as LocalViewerStateEnvelopeMappingError {
                try quarantine(activeData, source: .active)
                return try recoverAfterCurrentFailure(
                    reason: repositoryError(for: mappingError),
                    recoveryReason: recoveryReason(for: mappingError)
                )
            } catch let failure as ResolutionFailure {
                throw failure
            } catch {
                try quarantine(activeData, source: .active)
                return try recoverAfterCurrentFailure(
                    reason: .corruptData,
                    recoveryReason: .corruptData
                )
            }
        }

        return try recoverAfterCurrentFailure(reason: nil, recoveryReason: nil)
    }
}

extension LocalViewerStateRepository {
    private func recoverAfterCurrentFailure(
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
        let envelope: LocalViewerStateEnvelopeV3DTO
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
        guard case let .currentV3(envelope) = try coder.decode(data) else {
            throw LocalViewerStateCodingError.unsupportedSchema
        }
        let snapshot = try mapper.snapshot(from: envelope)
        return ResolvedState(envelope: envelope, snapshot: snapshot, activeBytes: data)
    }

    private func resolveActiveData(_ data: Data) throws -> ResolvedState {
        switch try coder.decode(data) {
            case let .currentV3(envelope):
                let snapshot = try mapper.snapshot(from: envelope)
                return ResolvedState(envelope: envelope, snapshot: snapshot, activeBytes: data)
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
            case let .currentV3(envelope):
                return try republish(envelope, source: .previousRecovery)
            case let .legacyV2(envelope):
                _ = try mapper.snapshot(from: envelope)
                let replacement = LocalViewerStateEnvelopeV3DTO(
                    envelopeSchemaVersion: LocalViewerStateEnvelopeV3DTO.schemaVersion,
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

    private func migrateV2(
        _ envelope: LocalViewerStateEnvelopeV2DTO
    ) -> LocalViewerStateEnvelopeV3DTO {
        LocalViewerStateEnvelopeV3DTO(
            envelopeSchemaVersion: LocalViewerStateEnvelopeV3DTO.schemaVersion,
            committedStateSnapshotID: envelope.committedStateSnapshotID,
            recommendationSuppressionEpochID: makeSuppressionEpochID(),
            viewerProfileState: envelope.viewerProfileState,
            viewerMovieStates: envelope.viewerMovieStates,
            migrationRecord: envelope.migrationRecord
        )
    }

    private func republish(
        _ envelope: LocalViewerStateEnvelopeV3DTO,
        source: LocalViewerStateMigrationRecordV2DTO.Source
    ) throws -> ResolvedState {
        let replacement = LocalViewerStateEnvelopeV3DTO(
            envelopeSchemaVersion: LocalViewerStateEnvelopeV3DTO.schemaVersion,
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
        _ envelope: LocalViewerStateEnvelopeV3DTO,
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
        _ envelope: LocalViewerStateEnvelopeV3DTO,
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

    private func encodeValidated(_ envelope: LocalViewerStateEnvelopeV3DTO) throws -> Data {
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

    private func quarantine(
        _ data: Data,
        source: LocalViewerStateQuarantineSource
    ) throws {
        do {
            try fileStore.quarantine(data, source: source)
        } catch {
            throw failure(.quarantineFailure, .quarantineFailure)
        }
    }

    private func repositoryError(
        for codingError: LocalViewerStateCodingError
    ) -> ViewerMovieStateRepositoryError {
        switch codingError {
            case .corruptData: .corruptData
            case .unsupportedSchema: .unsupportedSchema
        }
    }

    private func recoveryReason(
        for codingError: LocalViewerStateCodingError
    ) -> ViewerMovieStateRecoveryReason {
        switch codingError {
            case .corruptData: .corruptData
            case .unsupportedSchema: .unsupportedSchema
        }
    }

    private func repositoryError(
        for mappingError: LocalViewerStateEnvelopeMappingError
    ) -> ViewerMovieStateRepositoryError {
        switch mappingError {
            case .invalidEnvelope: .corruptData
            case .unsupportedProfileSchema, .unsupportedCatalog: .unsupportedSchema
        }
    }

    private func recoveryReason(
        for mappingError: LocalViewerStateEnvelopeMappingError
    ) -> ViewerMovieStateRecoveryReason {
        switch mappingError {
            case .invalidEnvelope: .corruptData
            case .unsupportedProfileSchema, .unsupportedCatalog: .unsupportedSchema
        }
    }

    private func failure(
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

import Foundation

actor LocalViewerStateRepository: ViewerMovieStateRepository {
    struct ResolvedState: Sendable {
        let envelope: LocalViewerStateEnvelopeV2DTO
        let snapshot: ViewerMovieStateSnapshot
        let activeBytes: Data
    }

    struct ResolutionFailure: Error, Sendable {
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
    let now: @Sendable () -> Date
    var resolvedState: ResolvedState?
    var destructiveResetAuthorized = false

    init(
        fileStore: any LocalViewerStateFileStore,
        legacySource: any LegacyViewerStateSource,
        legacyResetter: (any LegacyViewerStateResetter)? = nil,
        coder: any LocalViewerStateEnvelopeCoding = JSONLocalViewerStateEnvelopeCoder(),
        mapper: LocalViewerStateEnvelopeMapper = LocalViewerStateEnvelopeMapper(),
        profileMapper: LocalViewerProfileMapper = LocalViewerProfileMapper(),
        migrator: LegacyViewerStateMigrator = LegacyViewerStateMigrator(),
        snapshotID: @escaping @Sendable () -> UUID = UUID.init,
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
        self.now = now
    }

    func loadState() -> ViewerMovieStateLoadState {
        do {
            let snapshot = try resolve().snapshot
            destructiveResetAuthorized = false
            return .loaded(snapshot)
        } catch let failure as ResolutionFailure {
            destructiveResetAuthorized = true
            return .recovery(failure.recoveryReason)
        } catch {
            return .recovery(.loadFailure)
        }
    }

    func snapshot() throws -> ViewerMovieStateSnapshot {
        do {
            let snapshot = try resolve().snapshot
            destructiveResetAuthorized = false
            return snapshot
        } catch let failure as ResolutionFailure {
            throw failure.repositoryError
        } catch {
            throw ViewerMovieStateRepositoryError.loadFailure
        }
    }

    func state(movieID: Int) throws -> ViewerMovieState? {
        guard movieID > 0 else {
            throw ViewerMovieStateRepositoryError.invalidMovieID
        }
        return try snapshot().state(for: movieID)
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
                let resolved = try decode(activeData)
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
                let previous = try decode(previousData)
                let recovered = try republish(
                    previous.envelope,
                    source: .previousRecovery
                )
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
            throw failure(
                currentFailure ?? .migrationFailure,
                recoveryReason ?? .migrationFailure
            )
        }

        let source: LocalViewerStateMigrationRecordV2DTO.Source = if hasLegacyData {
            recoveringCurrentState ? .legacyRecovery : .legacyMigration
        } else {
            .freshInstall
        }
        let envelope: LocalViewerStateEnvelopeV2DTO
        do {
            envelope = try migrator.migrate(
                profileData: profileData,
                watchlistData: watchlistData,
                snapshotID: makeSnapshotID(),
                at: now(),
                source: source
            )
        } catch {
            throw failure(.migrationFailure, .migrationFailure)
        }
        let persisted = try publishInitial(
            envelope,
            clearPrevious: invalidPreviousWasQuarantined
        )
        resolvedState = persisted
        return persisted
    }

    private func decode(_ data: Data) throws -> ResolvedState {
        let envelope = try coder.decode(data)
        let snapshot = try mapper.snapshot(from: envelope)
        return ResolvedState(envelope: envelope, snapshot: snapshot, activeBytes: data)
    }

    private func republish(
        _ envelope: LocalViewerStateEnvelopeV2DTO,
        source: LocalViewerStateMigrationRecordV2DTO.Source
    ) throws -> ResolvedState {
        let replacement = LocalViewerStateEnvelopeV2DTO(
            envelopeSchemaVersion: LocalViewerStateEnvelopeV2DTO.schemaVersion,
            committedStateSnapshotID: freshSnapshotID(
                excluding: envelope.committedStateSnapshotID
            ),
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
        _ envelope: LocalViewerStateEnvelopeV2DTO,
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
        return try decode(data)
    }

    func persistMutation(
        _ envelope: LocalViewerStateEnvelopeV2DTO,
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
        return try decode(data)
    }

    private func encodeValidated(_ envelope: LocalViewerStateEnvelopeV2DTO) throws -> Data {
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
            _ = try decode(data)
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

    func freshSnapshotID(excluding previousID: UUID) -> UUID {
        var candidate = makeSnapshotID()
        while candidate == previousID {
            candidate = makeSnapshotID()
        }
        return candidate
    }
}

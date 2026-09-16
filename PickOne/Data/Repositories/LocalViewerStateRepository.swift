import Foundation

actor LocalViewerStateRepository: ViewingConfirmationMovieStateRepository {
    struct ResolvedState: Sendable {
        let envelope: LocalViewerStateEnvelopeV4DTO
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
    let legacySource: any LegacyViewerStateSource
    let legacyResetter: (any LegacyViewerStateResetter)?
    let coder: any LocalViewerStateEnvelopeCoding
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

    func hasAppliedConfirmationOperation(_ id: UUID) throws -> Bool {
        try resolve().envelope.appliedConfirmationOperations.contains(id)
    }

    func apply(
        _ transition: ViewerMovieStateTransition,
        metadata: MovieFeedbackMetadata
    ) throws -> ViewerMovieStateChange {
        let current = try resolve()
        let operationID: UUID? = switch transition.action {
            case let .confirmPick(provenance): provenance.confirmationOperationID
            case let .confirmationReaction(_, id): id
            default: nil
        }
        if let operationID, current.envelope.appliedConfirmationOperations.contains(operationID) {
            return ViewerMovieStateChange(
                state: current.snapshot.state(for: transition.movieID),
                impact: .none,
                snapshotID: current.snapshot.id
            )
        }
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

        if reduction.state == current.snapshot.state(for: transition.movieID), operationID == nil {
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
        var envelope = mapper.replacingStates(
            in: current.envelope,
            snapshotID: nextID,
            states: Array(states.values)
        )
        if let operationID { envelope.appliedConfirmationOperations.append(operationID) }
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

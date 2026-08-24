import Foundation

actor ThreeForTonightCoordinator: ThreeForTonightUseCase {
    private let viewerProfileRepository: any ViewerProfileRepository
    private let watchlistRepository: any WatchlistRepository
    private let decisionSetRepository: any DecisionSetRepository
    private let inputAssembler: AssembleDecisionEngineInput
    private let envelopeComposer: DecisionSetEnvelopeComposer
    private let memberRehydrator: DecisionMemberRehydrator
    private let signer: any DecisionCycleSigning
    private let selector: any DecisionSelecting
    private let repairComposer: P1DecisionRepairComposer
    private let makeUUID: @Sendable () -> UUID

    private var activeTask: Task<ThreeForTonightResult, Error>?
    private var activeOperationID: UUID?

    init(
        viewerProfileRepository: any ViewerProfileRepository,
        watchlistRepository: any WatchlistRepository,
        decisionSetRepository: any DecisionSetRepository,
        inputAssembler: AssembleDecisionEngineInput,
        movieRepository: any MovieRepository,
        availabilityRepository: any AvailabilityRepository,
        availabilityEvaluator: DecisionAvailabilityEvaluator = DecisionAvailabilityEvaluator(),
        signer: any DecisionCycleSigning,
        selector: any DecisionSelecting = P1DecisionEngine(),
        repairComposer: P1DecisionRepairComposer = P1DecisionRepairComposer(),
        clock: any DecisionSetClock = SystemDecisionSetClock(),
        makeUUID: @escaping @Sendable () -> UUID = { UUID() }
    ) {
        self.viewerProfileRepository = viewerProfileRepository
        self.watchlistRepository = watchlistRepository
        self.decisionSetRepository = decisionSetRepository
        self.inputAssembler = inputAssembler
        envelopeComposer = DecisionSetEnvelopeComposer(
            movieRepository: movieRepository,
            clock: clock,
            makeUUID: makeUUID
        )
        memberRehydrator = DecisionMemberRehydrator(
            movieRepository: movieRepository,
            availabilityRepository: availabilityRepository,
            availabilityEvaluator: availabilityEvaluator
        )
        self.signer = signer
        self.selector = selector
        self.repairComposer = repairComposer
        self.makeUUID = makeUUID
    }

    func load() async throws -> ThreeForTonightResult {
        try await start(.load)
    }

    func refresh() async throws -> ThreeForTonightResult {
        try await start(.refresh)
    }

    func repairAfterEligibilityChange(
        _ change: DecisionEligibilityChange
    ) async throws -> ThreeForTonightResult {
        try await start(.repair(change))
    }

    private func start(_ request: Request) async throws -> ThreeForTonightResult {
        activeTask?.cancel()
        let operationID = makeUUID()
        activeOperationID = operationID
        let task = Task {
            try await perform(request, operationID: operationID)
        }
        activeTask = task
        defer {
            if activeOperationID == operationID {
                activeTask = nil
                activeOperationID = nil
            }
        }
        return try await withTaskCancellationHandler {
            let result = try await task.value
            try Task.checkCancellation()
            return result
        } onCancel: {
            task.cancel()
        }
    }

    private func perform(
        _ request: Request,
        operationID: UUID
    ) async throws -> ThreeForTonightResult {
        try ensureCurrent(operationID)
        switch request {
            case .load:
                return try await performLoad(operationID: operationID)
            case .refresh:
                return try await performRefresh(operationID: operationID)
            case let .repair(change):
                return try await performRepairRequest(
                    change,
                    operationID: operationID
                )
        }
    }

    private func performLoad(
        operationID: UUID
    ) async throws -> ThreeForTonightResult {
        let trusted: TrustedLocalState
        do {
            trusted = try await loadTrustedLocalState()
        } catch let error as CoordinatorError {
            return .retryableFailure(reason: error.failureReason(recovery: false), retained: nil)
        }
        let signature: DecisionCycleSignature
        do {
            signature = try cycleSignature(for: trusted.profile)
        } catch {
            return .retryableFailure(reason: .profileUnavailable, retained: nil)
        }

        switch await decisionSetRepository.load() {
            case .absent:
                return try await generate(
                    cycle: newCycle(signature: signature),
                    retained: nil,
                    recovery: false,
                    operationID: operationID
                )
            case let .recovery(reason):
                guard reason == .corruptData || reason == .unsupportedVersion else {
                    return .retryableFailure(reason: .recoveryFailed, retained: nil)
                }
                return try await generate(
                    cycle: newCycle(signature: signature),
                    retained: nil,
                    recovery: true,
                    operationID: operationID
                )
            case let .available(envelope):
                guard envelope.cycle.identitySignature == signature else {
                    return try await generate(
                        cycle: newCycle(signature: signature),
                        retained: nil,
                        recovery: false,
                        operationID: operationID
                    )
                }
                let repairIDs = ThreeForTonightSnapshotFactory.localRepairMovieIDs(
                    envelope: envelope,
                    watchlistItems: trusted.watchlistItems,
                    profile: trusted.profile
                )
                guard repairIDs.isEmpty else {
                    return try await repair(
                        envelope: envelope,
                        reevaluatedMovieIDs: repairIDs,
                        operationID: operationID
                    )
                }
                return .usable(ThreeForTonightSnapshotFactory.snapshot(
                    envelope,
                    watchlistItems: trusted.watchlistItems
                ))
        }
    }

    private func performRefresh(
        operationID: UUID
    ) async throws -> ThreeForTonightResult {
        let trusted: TrustedLocalState
        do {
            trusted = try await loadTrustedLocalState()
        } catch let error as CoordinatorError {
            return .retryableFailure(reason: error.failureReason(recovery: false), retained: nil)
        }
        guard let signature = try? cycleSignature(for: trusted.profile) else {
            return .retryableFailure(reason: .profileUnavailable, retained: nil)
        }

        switch await decisionSetRepository.load() {
            case let .available(envelope)
            where envelope.cycle.identitySignature == signature:
                let retained = ThreeForTonightSnapshotFactory.safeRetainedSnapshot(
                    envelope,
                    watchlistItems: trusted.watchlistItems,
                    profile: trusted.profile
                )
                return try await generate(
                    cycle: envelope.cycle,
                    retained: retained,
                    recovery: false,
                    operationID: operationID
                )
            case let .recovery(reason):
                guard reason == .corruptData || reason == .unsupportedVersion else {
                    return .retryableFailure(reason: .recoveryFailed, retained: nil)
                }
                return try await generate(
                    cycle: newCycle(signature: signature),
                    retained: nil,
                    recovery: true,
                    operationID: operationID
                )
            case .absent, .available:
                return try await generate(
                    cycle: newCycle(signature: signature),
                    retained: nil,
                    recovery: false,
                    operationID: operationID
                )
        }
    }

    private func performRepairRequest(
        _ change: DecisionEligibilityChange,
        operationID: UUID
    ) async throws -> ThreeForTonightResult {
        let trusted: TrustedLocalState
        do {
            trusted = try await loadTrustedLocalState()
        } catch let error as CoordinatorError {
            return .retryableFailure(reason: error.failureReason(recovery: false), retained: nil)
        }
        guard let signature = try? cycleSignature(for: trusted.profile) else {
            return .retryableFailure(reason: .profileUnavailable, retained: nil)
        }
        guard case let .available(envelope) = await decisionSetRepository.load(),
              envelope.cycle.identitySignature == signature
        else {
            return try await generate(
                cycle: newCycle(signature: signature),
                retained: nil,
                recovery: false,
                operationID: operationID
            )
        }
        return try await repair(
            envelope: envelope,
            reevaluatedMovieIDs: [change.movieID],
            forceAvailabilityReloadMovieID: change.availabilityMovieID,
            operationID: operationID
        )
    }
}

private extension ThreeForTonightCoordinator {
    private func generate(
        cycle: DecisionCycle,
        retained: ThreeForTonightSnapshot?,
        recovery: Bool,
        operationID: UUID
    ) async throws -> ThreeForTonightResult {
        do {
            let inputSnapshot = try await inputAssembler.execute(
                currentCycleShownMovieIDs: cycle.shownMovieIDs
            )
            try ensureCurrent(operationID)
            let signature = try cycleSignature(for: inputSnapshot.profile)
            guard signature == cycle.identitySignature else {
                return .retryableFailure(
                    reason: .trustedInputsChanged,
                    retained: retained
                )
            }
            let selection = selector.select(from: inputSnapshot.input)
            let envelope = try await envelopeComposer.makeEnvelope(
                selection: selection,
                candidates: inputSnapshot.candidates,
                profile: inputSnapshot.profile,
                cycle: cycle
            )
            return try await validatePersistAndPublish(
                envelope,
                expectedProfile: inputSnapshot.profile,
                expectedWatchlist: inputSnapshot.watchlistItems,
                retained: retained,
                recovery: recovery,
                operationID: operationID
            )
        } catch is CancellationError {
            throw CancellationError()
        } catch let error as CoordinatorError {
            return .retryableFailure(
                reason: error.failureReason(recovery: recovery),
                retained: retained
            )
        } catch let error as DecisionEngineInputAssemblyError {
            return .retryableFailure(
                reason: error.failureReason(recovery: recovery),
                retained: retained
            )
        } catch {
            return .retryableFailure(
                reason: recovery ? .recoveryFailed : .generationUnavailable,
                retained: retained
            )
        }
    }

    private func repair(
        envelope: PersistedDecisionSet,
        reevaluatedMovieIDs: Set<Int>,
        forceAvailabilityReloadMovieID: Int? = nil,
        operationID: UUID
    ) async throws -> ThreeForTonightResult {
        let trustedBefore: TrustedLocalState
        do {
            trustedBefore = try await loadTrustedLocalState()
        } catch let error as CoordinatorError {
            return .retryableFailure(reason: error.failureReason(recovery: false), retained: nil)
        }
        var retained = safeRetainedSnapshot(
            envelope,
            trusted: trustedBefore,
            additionallyUnsafeMovieIDs: reevaluatedMovieIDs
        )

        do {
            var currentCandidates: [DecisionInputCandidate] = []
            var pendingReevaluatedMovieIDs = reevaluatedMovieIDs
            var rehydratedUnsafeMovieIDs: Set<Int> = []
            for recommendation in envelope.recommendations {
                try ensureCurrent(operationID)
                let candidate = try await memberRehydrator.rehydrate(
                    recommendation,
                    profile: trustedBefore.profile,
                    forceAvailabilityReload: recommendation.display.movieID
                        == forceAvailabilityReloadMovieID
                )
                currentCandidates.append(candidate)
                pendingReevaluatedMovieIDs.remove(candidate.seed.movieID)
                switch candidate.decisionCandidate.availability {
                    case .eligible:
                        break
                    case .ineligible, .unknown:
                        rehydratedUnsafeMovieIDs.insert(candidate.seed.movieID)
                }
                retained = safeRetainedSnapshot(
                    envelope,
                    trusted: trustedBefore,
                    additionallyUnsafeMovieIDs: pendingReevaluatedMovieIDs
                        .union(rehydratedUnsafeMovieIDs)
                )
            }

            let currentMovieIDs = Set(envelope.recommendations.map(\.display.movieID))
            let currentReevaluatedMovieIDs = reevaluatedMovieIDs.intersection(currentMovieIDs)
            let selectionExclusions = envelope.cycle.shownMovieIDs
                .subtracting(currentReevaluatedMovieIDs)
            let assembled = try await inputAssembler.execute(
                currentCycleShownMovieIDs: selectionExclusions
            )
            let currentByID = Dictionary(
                uniqueKeysWithValues: currentCandidates.map {
                    ($0.seed.movieID, $0)
                }
            )
            let allCandidates = currentCandidates + assembled.candidates.filter {
                currentByID[$0.seed.movieID] == nil
            }
            let input = DecisionEngineInput(
                profile: assembled.input.profile,
                candidates: allCandidates.map(\.decisionCandidate),
                watchlistWatchedMovieIDs: assembled.input.watchlistWatchedMovieIDs,
                savedUnwatchedMovieIDs: assembled.input.savedUnwatchedMovieIDs,
                currentCycleShownMovieIDs: selectionExclusions
            )
            let mandatoryIDs = Set(envelope.recommendations.map(\.display.movieID))
                .subtracting(reevaluatedMovieIDs)
                .union(reevaluatedMovieIDs.filter { movieID in
                    input.candidates.contains {
                        $0.movieID == movieID && $0.availability == .eligible
                    } && !input.watchlistWatchedMovieIDs.contains(movieID)
                })
            let selection = repairComposer.compose(
                input: input,
                mandatoryRetainedMovieIDs: mandatoryIDs
            )
            let repairedEnvelope = try await envelopeComposer.makeEnvelope(
                selection: selection,
                candidates: allCandidates,
                profile: assembled.profile,
                cycle: envelope.cycle
            )
            return try await validatePersistAndPublish(
                repairedEnvelope,
                expectedProfile: assembled.profile,
                expectedWatchlist: assembled.watchlistItems,
                retained: retained,
                recovery: false,
                operationID: operationID
            )
        } catch is CancellationError {
            throw CancellationError()
        } catch {
            return .retryableFailure(reason: .repairFailed, retained: retained)
        }
    }

    private func validatePersistAndPublish(
        _ envelope: PersistedDecisionSet,
        expectedProfile: ViewerProfile,
        expectedWatchlist: [WatchlistItem],
        retained: ThreeForTonightSnapshot?,
        recovery: Bool,
        operationID: UUID
    ) async throws -> ThreeForTonightResult {
        try ensureCurrent(operationID)
        guard await trustedInputsMatch(
            profile: expectedProfile,
            watchlistItems: expectedWatchlist
        ) else {
            return .retryableFailure(
                reason: .trustedInputsChanged,
                retained: retained
            )
        }
        do {
            try await decisionSetRepository.replace(envelope)
        } catch is CancellationError {
            throw CancellationError()
        } catch {
            return .retryableFailure(
                reason: recovery ? .recoveryFailed : .persistenceFailed,
                retained: retained
            )
        }
        try ensureCurrent(operationID)
        guard await trustedInputsMatch(
            profile: expectedProfile,
            watchlistItems: expectedWatchlist
        ) else {
            return .retryableFailure(
                reason: .trustedInputsChanged,
                retained: retained
            )
        }
        return .usable(ThreeForTonightSnapshotFactory.snapshot(
            envelope,
            watchlistItems: expectedWatchlist
        ))
    }

    private func loadTrustedLocalState() async throws -> TrustedLocalState {
        guard case let .completed(profile, _) = await viewerProfileRepository.loadState() else {
            throw CoordinatorError.profileUnavailable
        }
        let watchlistItems: [WatchlistItem]
        do {
            watchlistItems = try watchlistRepository.loadAllItems()
        } catch {
            throw CoordinatorError.watchlistUnavailable
        }
        return TrustedLocalState(profile: profile, watchlistItems: watchlistItems)
    }

    private func safeRetainedSnapshot(
        _ envelope: PersistedDecisionSet,
        trusted: TrustedLocalState,
        additionallyUnsafeMovieIDs: Set<Int>
    ) -> ThreeForTonightSnapshot? {
        ThreeForTonightSnapshotFactory.safeRetainedSnapshot(
            envelope,
            watchlistItems: trusted.watchlistItems,
            profile: trusted.profile,
            additionallyUnsafeMovieIDs: additionallyUnsafeMovieIDs
        )
    }

    private func trustedInputsMatch(
        profile: ViewerProfile,
        watchlistItems: [WatchlistItem]
    ) async -> Bool {
        guard case let .completed(currentProfile, _) = await viewerProfileRepository.loadState(),
              currentProfile == profile,
              let currentWatchlist = try? watchlistRepository.loadAllItems()
        else {
            return false
        }
        return currentWatchlist == watchlistItems
    }

    private func cycleSignature(
        for profile: ViewerProfile
    ) throws -> DecisionCycleSignature {
        try signer.signature(for: DecisionCycleIdentity(
            engineModelVersion: .p1Model,
            profile: profile
        ))
    }

    private func newCycle(
        signature: DecisionCycleSignature
    ) throws -> DecisionCycle {
        try DecisionCycle(id: makeUUID(), identitySignature: signature)
    }

    private func ensureCurrent(_ operationID: UUID) throws {
        try Task.checkCancellation()
        guard activeOperationID == operationID else {
            throw CancellationError()
        }
    }
}

private extension DecisionEligibilityChange {
    var availabilityMovieID: Int? {
        cause == .availability ? movieID : nil
    }
}

private enum Request: Sendable {
    case load
    case refresh
    case repair(DecisionEligibilityChange)
}

private struct TrustedLocalState: Sendable {
    let profile: ViewerProfile
    let watchlistItems: [WatchlistItem]
}

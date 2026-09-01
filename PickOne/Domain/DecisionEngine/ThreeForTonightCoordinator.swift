import Foundation

actor ThreeForTonightCoordinator: ThreeForTonightUseCase {
    let trustedStateLoader: any TrustedDecisionStateLoading
    let decisionSetRepository: any DecisionSetRepository
    let inputAssembler: AssembleDecisionEngineInput
    let envelopeComposer: DecisionSetEnvelopeComposer
    let memberRehydrator: DecisionMemberRehydrator
    private let signer: any DecisionCycleSigning
    let selector: any DecisionSelecting
    let repairComposer: P1DecisionRepairComposer
    let migrationPlanner: DecisionSetMigrationPlanner
    private let reconciliationPlanner: DecisionStateReconciliationPlanner
    let makeUUID: @Sendable () -> UUID

    private var activeTask: Task<ThreeForTonightResult, Error>?
    private var activeOperationID: UUID?

    init(
        viewerProfileRepository: any ViewerProfileRepository,
        viewerMovieStateRepository: any ViewerMovieStateRepository,
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
        self.init(
            trustedStateLoader: LoadTrustedDecisionState(
                viewerProfileRepository: viewerProfileRepository,
                viewerMovieStateRepository: viewerMovieStateRepository
            ),
            decisionSetRepository: decisionSetRepository,
            inputAssembler: inputAssembler,
            movieRepository: movieRepository,
            availabilityRepository: availabilityRepository,
            availabilityEvaluator: availabilityEvaluator,
            signer: signer,
            selector: selector,
            repairComposer: repairComposer,
            clock: clock,
            makeUUID: makeUUID
        )
    }

    init(
        trustedStateLoader: any TrustedDecisionStateLoading,
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
        self.trustedStateLoader = trustedStateLoader
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
        migrationPlanner = DecisionSetMigrationPlanner()
        reconciliationPlanner = DecisionStateReconciliationPlanner()
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

    func reconcileAfterViewerStateChange(
        _ change: DecisionViewerStateChange
    ) async throws -> ThreeForTonightResult {
        try await start(.reconcile(change))
    }

    private func start(
        _ request: ThreeForTonightRequest
    ) async throws -> ThreeForTonightResult {
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
        _ request: ThreeForTonightRequest,
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
            case let .reconcile(change):
                return try await performViewerStateReconciliation(
                    change,
                    operationID: operationID
                )
        }
    }
}

private extension ThreeForTonightCoordinator {
    func performLoad(operationID: UUID) async throws -> ThreeForTonightResult {
        guard let trusted = await loadTrustedState() else {
            return .retryableFailure(reason: .profileUnavailable, retained: nil)
        }
        let signature = try cycleSignature(for: trusted)

        switch await decisionSetRepository.load() {
            case .absent:
                return try await generate(
                    cycle: newCycle(signature: signature, trusted: trusted),
                    trusted: trusted,
                    retained: nil,
                    recovery: false,
                    operationID: operationID
                )
            case let .migrationRequired(source):
                return try await migrateOrRegenerate(
                    source: source,
                    currentSignature: signature,
                    trusted: trusted,
                    operationID: operationID
                )
            case let .recovery(reason):
                guard reason == .corruptData || reason == .unsupportedVersion else {
                    return .retryableFailure(reason: .recoveryFailed, retained: nil)
                }
                return try await generate(
                    cycle: newCycle(signature: signature, trusted: trusted),
                    trusted: trusted,
                    retained: nil,
                    recovery: true,
                    operationID: operationID
                )
            case let .available(envelope):
                let retained = safeRetainedSnapshot(
                    envelope,
                    trusted: trusted,
                    currentSignature: signature
                )
                guard envelope.sourceViewerStateSnapshotID == trusted.snapshotID,
                      envelope.cycle.identitySignature == signature
                else {
                    return try await regenerate(
                        from: envelope.cycle,
                        currentSignature: signature,
                        recovery: false,
                        trusted: trusted,
                        retained: retained,
                        operationID: operationID
                    )
                }
                let repairIDs = ThreeForTonightSnapshotFactory.localRepairMovieIDs(
                    envelope: envelope,
                    trustedState: trusted,
                    currentCycleSignature: signature
                )
                guard repairIDs.isEmpty else {
                    return try await repair(
                        envelope: envelope,
                        trusted: trusted,
                        currentSignature: signature,
                        reevaluatedMovieIDs: repairIDs,
                        operationID: operationID
                    )
                }
                return .usable(ThreeForTonightSnapshotFactory.snapshot(
                    envelope,
                    trustedState: trusted
                ))
        }
    }

    func performRefresh(operationID: UUID) async throws -> ThreeForTonightResult {
        guard let trusted = await loadTrustedState() else {
            return .retryableFailure(reason: .profileUnavailable, retained: nil)
        }
        let signature = try cycleSignature(for: trusted)

        switch await decisionSetRepository.load() {
            case let .available(envelope)
            where envelope.cycle.identitySignature == signature
            && envelope.sourceViewerStateSnapshotID == trusted.snapshotID:
                return try await generate(
                    cycle: envelope.cycle,
                    trusted: trusted,
                    retained: safeRetainedSnapshot(
                        envelope,
                        trusted: trusted,
                        currentSignature: signature
                    ),
                    recovery: false,
                    operationID: operationID
                )
            case let .available(envelope):
                return try await regenerate(
                    from: envelope.cycle,
                    currentSignature: signature,
                    recovery: false,
                    trusted: trusted,
                    retained: safeRetainedSnapshot(
                        envelope,
                        trusted: trusted,
                        currentSignature: signature
                    ),
                    operationID: operationID
                )
            case let .migrationRequired(source):
                return try await regenerate(
                    from: source.cycle,
                    currentSignature: signature,
                    recovery: true,
                    trusted: trusted,
                    retained: nil,
                    operationID: operationID
                )
            case let .recovery(reason):
                guard reason == .corruptData || reason == .unsupportedVersion else {
                    return .retryableFailure(reason: .recoveryFailed, retained: nil)
                }
                return try await generate(
                    cycle: newCycle(signature: signature, trusted: trusted),
                    trusted: trusted,
                    retained: nil,
                    recovery: true,
                    operationID: operationID
                )
            case .absent:
                return try await generate(
                    cycle: newCycle(signature: signature, trusted: trusted),
                    trusted: trusted,
                    retained: nil,
                    recovery: false,
                    operationID: operationID
                )
        }
    }

    func performRepairRequest(
        _ change: DecisionEligibilityChange,
        operationID: UUID
    ) async throws -> ThreeForTonightResult {
        guard let trusted = await loadTrustedState() else {
            return .retryableFailure(reason: .profileUnavailable, retained: nil)
        }
        let signature = try cycleSignature(for: trusted)

        switch await decisionSetRepository.load() {
            case let .available(envelope)
            where envelope.cycle.identitySignature == signature:
                return try await repair(
                    envelope: envelope,
                    trusted: trusted,
                    currentSignature: signature,
                    reevaluatedMovieIDs: [change.movieID],
                    forceAvailabilityReloadMovieID: change.availabilityMovieID,
                    operationID: operationID
                )
            case let .available(envelope):
                return try await regenerate(
                    from: envelope.cycle,
                    currentSignature: signature,
                    recovery: false,
                    trusted: trusted,
                    retained: safeRetainedSnapshot(
                        envelope,
                        trusted: trusted,
                        currentSignature: signature
                    ),
                    operationID: operationID
                )
            case let .migrationRequired(source):
                return try await regenerate(
                    from: source.cycle,
                    currentSignature: signature,
                    recovery: true,
                    trusted: trusted,
                    retained: nil,
                    operationID: operationID
                )
            case .absent, .recovery:
                return try await generate(
                    cycle: newCycle(signature: signature, trusted: trusted),
                    trusted: trusted,
                    retained: nil,
                    recovery: false,
                    operationID: operationID
                )
        }
    }

    func performViewerStateReconciliation(
        _ change: DecisionViewerStateChange,
        operationID: UUID
    ) async throws -> ThreeForTonightResult {
        guard let trusted = await loadTrustedState() else {
            return .retryableFailure(reason: .profileUnavailable, retained: nil)
        }
        guard trusted.snapshotID == change.snapshotID else {
            return .retryableFailure(reason: .trustedInputsChanged, retained: nil)
        }
        let signature = try cycleSignature(for: trusted)

        switch await decisionSetRepository.load() {
            case let .available(envelope):
                let retained = safeRetainedSnapshot(
                    envelope,
                    trusted: trusted,
                    currentSignature: signature
                )
                if isCurrentPublishedEnvelope(
                    envelope,
                    trusted: trusted,
                    signature: signature
                ), let retained {
                    return .usable(retained)
                }
                let plan = try reconciliationPlanner.plan(
                    change: change,
                    sourceCycle: envelope.cycle,
                    currentSignature: signature,
                    makeCycleID: makeUUID
                )
                switch plan {
                    case .none:
                        guard envelope.sourceViewerStateSnapshotID == trusted.snapshotID,
                              envelope.cycle.identitySignature == signature,
                              let retained
                        else {
                            return .retryableFailure(
                                reason: .trustedInputsChanged,
                                retained: retained
                            )
                        }
                        return .usable(retained)
                    case let .successorCycle(cycle):
                        return try await generate(
                            cycle: cycle,
                            trusted: trusted,
                            retained: retained,
                            recovery: false,
                            operationID: operationID
                        )
                    case let .repair(movieID):
                        guard envelope.cycle.identitySignature == signature else {
                            return try await regenerate(
                                from: envelope.cycle,
                                currentSignature: signature,
                                recovery: false,
                                trusted: trusted,
                                retained: retained,
                                operationID: operationID
                            )
                        }
                        return try await repair(
                            envelope: envelope,
                            trusted: trusted,
                            currentSignature: signature,
                            reevaluatedMovieIDs: [movieID],
                            operationID: operationID
                        )
                }
            case let .migrationRequired(source):
                return try await regenerate(
                    from: source.cycle,
                    currentSignature: signature,
                    recovery: true,
                    trusted: trusted,
                    retained: nil,
                    operationID: operationID
                )
            case .absent, .recovery:
                guard change.impact != .none else {
                    return .retryableFailure(reason: .trustedInputsChanged, retained: nil)
                }
                return try await generate(
                    cycle: newCycle(signature: signature, trusted: trusted),
                    trusted: trusted,
                    retained: nil,
                    recovery: false,
                    operationID: operationID
                )
        }
    }

    func isCurrentPublishedEnvelope(
        _ envelope: PersistedDecisionSet,
        trusted: TrustedDecisionState,
        signature: DecisionCycleSignature
    ) -> Bool {
        envelope.sourceViewerStateSnapshotID == trusted.snapshotID
            && envelope.cycle.identitySignature == signature
            && ThreeForTonightSnapshotFactory.localRepairMovieIDs(
                envelope: envelope,
                trustedState: trusted,
                currentCycleSignature: signature
            ).isEmpty
    }
}

extension ThreeForTonightCoordinator {
    func loadTrustedState() async -> TrustedDecisionState? {
        do {
            return try await trustedStateLoader.load()
        } catch {
            return nil
        }
    }

    func safeRetainedSnapshot(
        _ envelope: PersistedDecisionSet,
        trusted: TrustedDecisionState,
        currentSignature: DecisionCycleSignature,
        additionallyUnsafeMovieIDs: Set<Int> = []
    ) -> ThreeForTonightSnapshot? {
        ThreeForTonightSnapshotFactory.safeRetainedSnapshot(
            envelope,
            trustedState: trusted,
            currentCycleSignature: currentSignature,
            additionallyUnsafeMovieIDs: additionallyUnsafeMovieIDs
        )
    }

    func cycleSignature(
        for trusted: TrustedDecisionState
    ) throws -> DecisionCycleSignature {
        try signer.signature(for: DecisionCycleIdentity(
            engineModelVersion: .p1Model,
            profile: trusted.profile,
            reactions: trusted.reactions
        ))
    }

    func newCycle(
        signature: DecisionCycleSignature,
        trusted: TrustedDecisionState
    ) throws -> DecisionCycle {
        try DecisionCycle(
            id: makeUUID(),
            identitySignature: signature,
            history: RecommendationHistory(
                suppressionEpochID: trusted.recommendationSuppressionEpochID
            )
        )
    }

    func ensureCurrent(_ operationID: UUID) throws {
        try Task.checkCancellation()
        guard activeOperationID == operationID else {
            throw CancellationError()
        }
    }
}

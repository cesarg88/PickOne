import Foundation

extension ThreeForTonightCoordinator {
    func regenerate(
        from sourceCycle: DecisionCycle,
        currentSignature: DecisionCycleSignature,
        recovery: Bool,
        trusted: TrustedDecisionState,
        retained: ThreeForTonightSnapshot?,
        operationID: UUID
    ) async throws -> ThreeForTonightResult {
        let cycle = try migrationPlanner.reconciledCycle(
            sourceCycle: sourceCycle,
            currentSignature: currentSignature,
            makeCycleID: makeUUID
        )
        return try await generate(
            cycle: cycle,
            trusted: trusted,
            retained: retained,
            recovery: recovery,
            operationID: operationID
        )
    }

    func generate(
        cycle: DecisionCycle,
        trusted: TrustedDecisionState,
        retained: ThreeForTonightSnapshot?,
        recovery: Bool,
        operationID: UUID,
        staleRetryCount: Int = 0
    ) async throws -> ThreeForTonightResult {
        do {
            let inputSnapshot = try await inputAssembler.execute(
                trustedState: trusted,
                currentCycleShownMovieIDs: cycle.shownMovieIDs
            )
            try ensureCurrent(operationID)
            let signature = try cycleSignature(for: inputSnapshot.trustedState)
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
                profile: trusted.profile,
                cycle: cycle,
                sourceViewerStateSnapshotID: trusted.snapshotID
            )
            return try await validatePersistAndPublish(
                envelope,
                expectedTrustedState: trusted,
                sourceCycle: cycle,
                retained: retained,
                recovery: recovery,
                operationID: operationID,
                staleRetryCount: staleRetryCount
            )
        } catch is CancellationError {
            throw CancellationError()
        } catch let error as DecisionEngineInputAssemblyError {
            return .retryableFailure(
                reason: error.failureReason(recovery: recovery),
                retained: retained
            )
        } catch let error as CoordinatorError {
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

    func repair(
        envelope: PersistedDecisionSet,
        trusted: TrustedDecisionState,
        reevaluatedMovieIDs: Set<Int>,
        forceAvailabilityReloadMovieID: Int? = nil,
        operationID: UUID
    ) async throws -> ThreeForTonightResult {
        var retained = safeRetainedSnapshot(
            envelope,
            trusted: trusted,
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
                    profile: trusted.profile,
                    forceAvailabilityReload: recommendation.display.movieID
                        == forceAvailabilityReloadMovieID
                )
                currentCandidates.append(candidate)
                pendingReevaluatedMovieIDs.remove(candidate.seed.movieID)
                if candidate.decisionCandidate.availability != .eligible {
                    rehydratedUnsafeMovieIDs.insert(candidate.seed.movieID)
                }
                retained = safeRetainedSnapshot(
                    envelope,
                    trusted: trusted,
                    additionallyUnsafeMovieIDs: pendingReevaluatedMovieIDs
                        .union(rehydratedUnsafeMovieIDs)
                )
            }

            let currentMovieIDs = Set(envelope.recommendations.map(\.display.movieID))
            let currentReevaluatedMovieIDs = reevaluatedMovieIDs.intersection(currentMovieIDs)
            let selectionExclusions = envelope.cycle.shownMovieIDs
                .subtracting(currentReevaluatedMovieIDs)
            let assembled = try await inputAssembler.execute(
                trustedState: trusted,
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
                recommendationExcludedMovieIDs: assembled.input.recommendationExcludedMovieIDs,
                savedUnwatchedMovieIDs: assembled.input.savedUnwatchedMovieIDs,
                currentCycleShownMovieIDs: selectionExclusions
            )
            let mandatoryIDs = Set(envelope.recommendations.map(\.display.movieID))
                .subtracting(reevaluatedMovieIDs)
                .union(reevaluatedMovieIDs.filter { movieID in
                    input.candidates.contains {
                        $0.movieID == movieID && $0.availability == .eligible
                    } && !input.recommendationExcludedMovieIDs.contains(movieID)
                })
            let selection = repairComposer.compose(
                input: input,
                mandatoryRetainedMovieIDs: mandatoryIDs
            )
            let repairedEnvelope = try await envelopeComposer.makeEnvelope(
                selection: selection,
                candidates: allCandidates,
                profile: trusted.profile,
                cycle: envelope.cycle,
                sourceViewerStateSnapshotID: trusted.snapshotID
            )
            return try await validatePersistAndPublish(
                repairedEnvelope,
                expectedTrustedState: trusted,
                sourceCycle: envelope.cycle,
                retained: retained,
                recovery: false,
                operationID: operationID,
                staleRetryCount: 0
            )
        } catch is CancellationError {
            throw CancellationError()
        } catch let error as DecisionEngineInputAssemblyError {
            return .retryableFailure(
                reason: error.failureReason(recovery: false),
                retained: retained
            )
        } catch {
            return .retryableFailure(reason: .repairFailed, retained: retained)
        }
    }

    func validatePersistAndPublish(
        _ envelope: PersistedDecisionSet,
        expectedTrustedState: TrustedDecisionState,
        sourceCycle: DecisionCycle,
        retained: ThreeForTonightSnapshot?,
        recovery: Bool,
        operationID: UUID,
        staleRetryCount: Int
    ) async throws -> ThreeForTonightResult {
        try ensureCurrent(operationID)
        guard await trustedStateLoader.matches(
            snapshotID: expectedTrustedState.snapshotID
        ) else {
            return try await regenerateAfterStaleWork(
                sourceCycle: sourceCycle,
                retained: retained,
                recovery: recovery,
                operationID: operationID,
                staleRetryCount: staleRetryCount
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
        guard await trustedStateLoader.matches(
            snapshotID: expectedTrustedState.snapshotID
        ) else {
            return try await regenerateAfterStaleWork(
                sourceCycle: sourceCycle,
                retained: retained,
                recovery: recovery,
                operationID: operationID,
                staleRetryCount: staleRetryCount
            )
        }
        return .usable(ThreeForTonightSnapshotFactory.snapshot(
            envelope,
            trustedState: expectedTrustedState
        ))
    }

    func regenerateAfterStaleWork(
        sourceCycle: DecisionCycle,
        retained: ThreeForTonightSnapshot?,
        recovery: Bool,
        operationID: UUID,
        staleRetryCount: Int
    ) async throws -> ThreeForTonightResult {
        guard staleRetryCount == 0,
              let latest = await loadTrustedState()
        else {
            return .retryableFailure(
                reason: .trustedInputsChanged,
                retained: retained
            )
        }
        let signature = try cycleSignature(for: latest)
        let cycle = try migrationPlanner.reconciledCycle(
            sourceCycle: sourceCycle,
            currentSignature: signature,
            makeCycleID: makeUUID
        )
        return try await generate(
            cycle: cycle,
            trusted: latest,
            retained: retained,
            recovery: recovery,
            operationID: operationID,
            staleRetryCount: staleRetryCount + 1
        )
    }
}

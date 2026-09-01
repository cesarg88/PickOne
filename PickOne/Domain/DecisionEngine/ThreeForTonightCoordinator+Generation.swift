import Foundation

extension ThreeForTonightCoordinator {
    func migrateOrRegenerate(
        source: DecisionSetMigrationSource,
        currentSignature: DecisionCycleSignature,
        trusted: TrustedDecisionState,
        operationID: UUID
    ) async throws -> ThreeForTonightResult {
        if let migrated = try source.migratingV2(
            suppressionEpochID: trusted.recommendationSuppressionEpochID
        ), !migrated.recommendations.isEmpty,
        migrated.sourceViewerStateSnapshotID == trusted.snapshotID,
        migrated.cycle.identitySignature == currentSignature {
            let unsafeMovieIDs = ThreeForTonightSnapshotFactory.localRepairMovieIDs(
                envelope: migrated,
                trustedState: trusted,
                currentCycleSignature: currentSignature
            )
            if unsafeMovieIDs.isEmpty {
                return try await validatePersistAndPublish(
                    migrated,
                    expectedTrustedState: trusted,
                    sourceCycle: migrated.cycle,
                    retained: nil,
                    recovery: true,
                    operationID: operationID,
                    staleRetryCount: 0
                )
            }
        }

        let sourceCycle = try source.migratingV2(
            suppressionEpochID: trusted.recommendationSuppressionEpochID
        )?.cycle ?? source.cycle
        return try await regenerate(
            from: sourceCycle,
            currentSignature: currentSignature,
            recovery: true,
            trusted: trusted,
            retained: nil,
            operationID: operationID
        )
    }

    func regenerate(
        from sourceCycle: DecisionCycle,
        currentSignature: DecisionCycleSignature,
        recovery: Bool,
        trusted: TrustedDecisionState,
        retained: ThreeForTonightSnapshot?,
        operationID: UUID
    ) async throws -> ThreeForTonightResult {
        let epochAlignedCycle = sourceCycle.history.suppressionEpochID
            == trusted.recommendationSuppressionEpochID
            ? sourceCycle
            : try DecisionCycle(
                id: sourceCycle.id,
                identitySignature: sourceCycle.identitySignature,
                history: sourceCycle.history.startingEpoch(
                    trusted.recommendationSuppressionEpochID
                )
            )
        let cycle = try migrationPlanner.reconciledCycle(
            sourceCycle: epochAlignedCycle,
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
        currentSignature: DecisionCycleSignature,
        reevaluatedMovieIDs: Set<Int>,
        forceAvailabilityReloadMovieID: Int? = nil,
        operationID: UUID
    ) async throws -> ThreeForTonightResult {
        var retained = safeRetainedSnapshot(
            envelope,
            trusted: trusted,
            currentSignature: currentSignature,
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
                    currentSignature: currentSignature,
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
            let input = makeRepairInput(
                assembled: assembled,
                candidates: allCandidates,
                selectionExclusions: selectionExclusions
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

    func makeRepairInput(
        assembled: DecisionEngineInputSnapshot,
        candidates: [DecisionInputCandidate],
        selectionExclusions: Set<Int>
    ) -> DecisionEngineInput {
        DecisionEngineInput(
            profile: assembled.input.profile,
            candidates: candidates.map(\.decisionCandidate),
            recommendationExcludedMovieIDs: assembled.input.recommendationExcludedMovieIDs,
            savedUnwatchedMovieIDs: assembled.input.savedUnwatchedMovieIDs,
            currentCycleShownMovieIDs: selectionExclusions
        )
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
        guard let latest = await loadTrustedState() else {
            return .retryableFailure(
                reason: .trustedInputsChanged,
                retained: nil
            )
        }
        let signature = try cycleSignature(for: latest)
        let latestRetained = retained.flatMap {
            safeRetainedSnapshot(
                $0.decisionSet,
                trusted: latest,
                currentSignature: signature
            )
        }
        guard staleRetryCount == 0 else {
            return .retryableFailure(
                reason: .trustedInputsChanged,
                retained: latestRetained
            )
        }
        let cycle = try migrationPlanner.reconciledCycle(
            sourceCycle: sourceCycle,
            currentSignature: signature,
            makeCycleID: makeUUID
        )
        return try await generate(
            cycle: cycle,
            trusted: latest,
            retained: latestRetained,
            recovery: recovery,
            operationID: operationID,
            staleRetryCount: staleRetryCount + 1
        )
    }
}

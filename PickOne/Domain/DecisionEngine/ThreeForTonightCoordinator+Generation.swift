import Foundation

private struct RecommendationGenerationExecution: Sendable {
    let result: ThreeForTonightResult
    let search: ProgressiveRecommendationSearchResult
}

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
        let startedAt = clock.now()
        return try await withOperationDiagnostics(startedAt: startedAt) {
            try await performGenerate(
                cycle: cycle,
                trusted: trusted,
                retained: retained,
                recovery: recovery,
                operationID: operationID,
                staleRetryCount: staleRetryCount
            )
        }
    }

    private func performGenerate(
        cycle: DecisionCycle,
        trusted: TrustedDecisionState,
        retained: ThreeForTonightSnapshot?,
        recovery: Bool,
        operationID: UUID,
        staleRetryCount: Int
    ) async throws -> ThreeForTonightResult {
        var provenRetained: RetainedDecisionSetValidation?
        do {
            if let retained {
                let validation = try await validateRetainedDecisionSet(
                    retained,
                    trusted: trusted,
                    operationID: operationID
                )
                switch validation {
                    case let .success(validated):
                        provenRetained = validated
                    case let .failure(safeSnapshot):
                        return .retryableFailure(
                            reason: recovery ? .recoveryFailed : .generationUnavailable,
                            retained: safeSnapshot
                        )
                }
            }
            let execution = try await performGeneration(
                cycle: cycle,
                trusted: trusted,
                retained: retained,
                provenRetained: provenRetained,
                recovery: recovery,
                operationID: operationID,
                staleRetryCount: staleRetryCount
            )
            return execution.result
        } catch is CancellationError {
            throw CancellationError()
        } catch let error as DecisionEngineInputAssemblyError {
            return ThreeForTonightResult.retryableFailure(
                reason: error.failureReason(recovery: recovery),
                retained: provenRetained?.snapshot
            )
        } catch let error as CoordinatorError {
            return ThreeForTonightResult.retryableFailure(
                reason: error.failureReason(recovery: recovery),
                retained: provenRetained?.snapshot
            )
        } catch {
            return ThreeForTonightResult.retryableFailure(
                reason: recovery ? .recoveryFailed : .generationUnavailable,
                retained: provenRetained?.snapshot
            )
        }
    }

    private func performGeneration(
        cycle: DecisionCycle,
        trusted: TrustedDecisionState,
        retained: ThreeForTonightSnapshot?,
        provenRetained: RetainedDecisionSetValidation?,
        recovery: Bool,
        operationID: UUID,
        staleRetryCount: Int
    ) async throws -> RecommendationGenerationExecution {
        let activeMovieIDs = Set(
            retained?.decisionSet.recommendations.map(\.display.movieID) ?? []
        )
        let search = try await progressiveSearch(
            cycle: cycle,
            trusted: trusted,
            activeMovieIDs: activeMovieIDs
        )
        try ensureCurrent(operationID)
        guard try cycleSignature(for: trusted) == cycle.identitySignature else {
            return RecommendationGenerationExecution(
                result: .retryableFailure(
                    reason: .trustedInputsChanged,
                    retained: provenRetained?.snapshot
                ),
                search: search
            )
        }
        let searchCycle = try DecisionCycle(
            id: cycle.id,
            identitySignature: cycle.identitySignature,
            history: search.history
        )
        let exhaustedAt = search.exhausted ? clock.now() : nil
        let envelope = try await generationEnvelope(
            search: search,
            searchCycle: searchCycle,
            exhaustedAt: exhaustedAt,
            provenRetained: provenRetained,
            trusted: trusted
        )
        let result = try await validatePersistAndPublish(
            envelope,
            expectedTrustedState: trusted,
            sourceCycle: cycle,
            retained: provenRetained?.snapshot,
            staleRetained: retained,
            recovery: recovery,
            operationID: operationID,
            staleRetryCount: staleRetryCount
        )
        return RecommendationGenerationExecution(result: result, search: search)
    }

    private func generationEnvelope(
        search: ProgressiveRecommendationSearchResult,
        searchCycle: DecisionCycle,
        exhaustedAt: Date?,
        provenRetained: RetainedDecisionSetValidation?,
        trusted: TrustedDecisionState
    ) async throws -> PersistedDecisionSet {
        if search.exhausted,
           search.selection.recommendations.isEmpty,
           let provenRetained
        {
            return try await envelopeComposer.makeEnvelope(
                selection: provenRetained.selection,
                candidates: provenRetained.candidates,
                profile: trusted.profile,
                cycle: searchCycle,
                sourceViewerStateSnapshotID: trusted.snapshotID,
                outcome: .exhausted(exhaustedAt: required(exhaustedAt))
            )
        }
        return try await envelopeComposer.makeEnvelope(
            selection: search.selection,
            candidates: search.candidates,
            profile: trusted.profile,
            cycle: searchCycle,
            sourceViewerStateSnapshotID: trusted.snapshotID,
            outcome: exhaustedAt.map {
                .exhausted(exhaustedAt: $0)
            } ?? .recommendations
        )
    }

    private func required(_ date: Date?) throws -> Date {
        guard let date else { throw CoordinatorError.invariantViolation }
        return date
    }

    func repair(
        envelope: PersistedDecisionSet,
        trusted: TrustedDecisionState,
        currentSignature: DecisionCycleSignature,
        reevaluatedMovieIDs: Set<Int>,
        forceAvailabilityReloadMovieID: Int? = nil,
        targetCycle: DecisionCycle? = nil,
        operationID: UUID
    ) async throws -> ThreeForTonightResult {
        let startedAt = clock.now()
        return try await withOperationDiagnostics(startedAt: startedAt) {
            try await performRepair(
                envelope: envelope,
                trusted: trusted,
                currentSignature: currentSignature,
                reevaluatedMovieIDs: reevaluatedMovieIDs,
                forceAvailabilityReloadMovieID: forceAvailabilityReloadMovieID,
                targetCycle: targetCycle,
                operationID: operationID
            )
        }
    }

    private func performRepair(
        envelope: PersistedDecisionSet,
        trusted: TrustedDecisionState,
        currentSignature: DecisionCycleSignature,
        reevaluatedMovieIDs: Set<Int>,
        forceAvailabilityReloadMovieID: Int?,
        targetCycle: DecisionCycle?,
        operationID: UUID
    ) async throws -> ThreeForTonightResult {
        var safeRetained: ThreeForTonightSnapshot?
        do {
            let rehydrationResult = try await rehydrateForRepair(
                envelope: envelope,
                trusted: trusted,
                currentSignature: currentSignature,
                reevaluatedMovieIDs: reevaluatedMovieIDs,
                forceAvailabilityReloadMovieID: forceAvailabilityReloadMovieID,
                operationID: operationID
            )
            guard case let .success(rehydration) = rehydrationResult else {
                guard case let .failure(retained) = rehydrationResult else {
                    throw CoordinatorError.invariantViolation
                }
                return ThreeForTonightResult.retryableFailure(
                    reason: .repairFailed,
                    retained: retained
                )
            }
            safeRetained = rehydration.retained
            let currentMovieIDs = Set(envelope.recommendations.map(\.display.movieID))
            let cycle = targetCycle ?? envelope.cycle
            let search = try await progressiveSearch(
                cycle: cycle,
                trusted: trusted,
                activeMovieIDs: currentMovieIDs,
                retainedCandidates: rehydration.candidates,
                mandatoryRetainedMovieIDs: currentMovieIDs,
                additionallyExcludedMovieIDs: reevaluatedMovieIDs
                    .subtracting(currentMovieIDs)
            )
            let searchCycle = try DecisionCycle(
                id: cycle.id,
                identitySignature: cycle.identitySignature,
                history: search.history
            )
            let exhaustedAt = search.exhausted ? clock.now() : nil
            let repairedEnvelope = try await envelopeComposer.makeEnvelope(
                selection: search.selection,
                candidates: search.candidates,
                profile: trusted.profile,
                cycle: searchCycle,
                sourceViewerStateSnapshotID: trusted.snapshotID,
                outcome: exhaustedAt.map {
                    .exhausted(exhaustedAt: $0)
                } ?? .recommendations
            )
            return try await validatePersistAndPublish(
                repairedEnvelope,
                expectedTrustedState: trusted,
                sourceCycle: cycle,
                retained: rehydration.retained,
                recovery: false,
                operationID: operationID,
                staleRetryCount: 0
            )
        } catch is CancellationError {
            throw CancellationError()
        } catch let error as DecisionEngineInputAssemblyError {
            return ThreeForTonightResult.retryableFailure(
                reason: error.failureReason(recovery: false),
                retained: safeRetained
            )
        } catch let error as CoordinatorError {
            return .retryableFailure(
                reason: error.failureReason(recovery: false),
                retained: safeRetained
            )
        } catch {
            return ThreeForTonightResult.retryableFailure(
                reason: .repairFailed,
                retained: safeRetained
            )
        }
    }

    func validatePersistAndPublish(
        _ envelope: PersistedDecisionSet,
        expectedTrustedState: TrustedDecisionState,
        sourceCycle: DecisionCycle,
        retained: ThreeForTonightSnapshot?,
        staleRetained: ThreeForTonightSnapshot? = nil,
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
                retained: staleRetained ?? retained,
                recovery: recovery,
                operationID: operationID,
                staleRetryCount: staleRetryCount
            )
        }
        let checkpoint: DecisionSetPersistenceCheckpoint
        do {
            checkpoint = try await decisionSetRepository.makePersistenceCheckpoint()
        } catch {
            return .retryableFailure(
                reason: recovery ? .recoveryFailed : .persistenceFailed,
                retained: retained
            )
        }
        do {
            try await decisionSetRepository.replace(envelope, using: checkpoint)
        } catch is CancellationError {
            try await rollback(checkpoint)
            throw CancellationError()
        } catch {
            do {
                try await rollback(checkpoint)
            } catch {
                return .retryableFailure(
                    reason: recovery ? .recoveryFailed : .persistenceFailed,
                    retained: retained
                )
            }
            return .retryableFailure(
                reason: recovery ? .recoveryFailed : .persistenceFailed,
                retained: retained
            )
        }
        do {
            try ensureCurrent(operationID)
        } catch {
            try await rollback(checkpoint)
            throw error
        }
        guard await trustedStateLoader.matches(
            snapshotID: expectedTrustedState.snapshotID
        ) else {
            do {
                try await rollback(checkpoint)
            } catch {
                return .retryableFailure(
                    reason: recovery ? .recoveryFailed : .persistenceFailed,
                    retained: retained
                )
            }
            return try await regenerateAfterStaleWork(
                sourceCycle: sourceCycle,
                retained: staleRetained ?? retained,
                recovery: recovery,
                operationID: operationID,
                staleRetryCount: staleRetryCount
            )
        }
        do {
            try ensureCurrent(operationID)
        } catch {
            try await rollback(checkpoint)
            throw error
        }
        return result(for: envelope, trusted: expectedTrustedState)
    }

    private func rollback(
        _ checkpoint: DecisionSetPersistenceCheckpoint
    ) async throws {
        do {
            try await decisionSetRepository.restorePersistenceCheckpoint(checkpoint)
        } catch {
            throw CoordinatorError.persistenceRollbackFailed
        }
    }

    func result(
        for envelope: PersistedDecisionSet,
        trusted: TrustedDecisionState
    ) -> ThreeForTonightResult {
        let snapshot = ThreeForTonightSnapshotFactory.snapshot(
            envelope,
            trustedState: trusted
        )
        guard case let .exhausted(exhaustedAt) = envelope.outcome else {
            return .usable(snapshot)
        }
        let expiresAt = exhaustionPolicy.expiresAt(exhaustedAt: exhaustedAt)
        return .exhausted(ThreeForTonightExhaustion(
            snapshot: snapshot,
            expiresAt: expiresAt,
            canRefresh: !exhaustionPolicy.isFresh(
                exhaustedAt: exhaustedAt,
                now: clock.now()
            )
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
                retained: latestRetained.flatMap { snapshot in
                    snapshot.decisionSet.recommendations.isEmpty ? snapshot : nil
                }
            )
        }
        let epochAlignedCycle = sourceCycle.history.suppressionEpochID
            == latest.recommendationSuppressionEpochID
            ? sourceCycle
            : try DecisionCycle(
                id: sourceCycle.id,
                identitySignature: sourceCycle.identitySignature,
                history: sourceCycle.history.startingEpoch(
                    latest.recommendationSuppressionEpochID
                )
            )
        let cycle = try migrationPlanner.reconciledCycle(
            sourceCycle: epochAlignedCycle,
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

import Foundation

private struct RetainedDecisionSetValidation: Sendable {
    let snapshot: ThreeForTonightSnapshot
    let selection: DecisionSelection
    let candidates: [DecisionInputCandidate]
}

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
        let diagnosticsStartedAt = clock.now()
        var provenRetained: RetainedDecisionSetValidation?
        do {
            if let retained {
                provenRetained = try await validateRetainedDecisionSet(
                    retained,
                    trusted: trusted,
                    operationID: operationID
                )
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
            recordDiagnostics(makeDiagnostics(
                search: execution.search,
                result: execution.result,
                trusted: trusted,
                startedAt: diagnosticsStartedAt
            ))
            return execution.result
        } catch is CancellationError {
            throw CancellationError()
        } catch let error as DecisionEngineInputAssemblyError {
            let result = ThreeForTonightResult.retryableFailure(
                reason: error.failureReason(recovery: recovery),
                retained: provenRetained?.snapshot
            )
            recordDiagnostics(failedDiagnostics(
                startedAt: diagnosticsStartedAt,
                trusted: trusted
            ))
            return result
        } catch let error as CoordinatorError {
            let result = ThreeForTonightResult.retryableFailure(
                reason: error.failureReason(recovery: recovery),
                retained: provenRetained?.snapshot
            )
            recordDiagnostics(failedDiagnostics(
                startedAt: diagnosticsStartedAt,
                trusted: trusted
            ))
            return result
        } catch {
            let result = ThreeForTonightResult.retryableFailure(
                reason: recovery ? .recoveryFailed : .generationUnavailable,
                retained: provenRetained?.snapshot
            )
            recordDiagnostics(failedDiagnostics(
                startedAt: diagnosticsStartedAt,
                trusted: trusted
            ))
            return result
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

    private func validateRetainedDecisionSet(
        _ retained: ThreeForTonightSnapshot,
        trusted: TrustedDecisionState,
        operationID: UUID
    ) async throws -> RetainedDecisionSetValidation? {
        if retained.decisionSet.recommendations.isEmpty {
            return RetainedDecisionSetValidation(
                snapshot: retained,
                selection: DecisionSelection(recommendations: []),
                candidates: []
            )
        }
        var candidates: [DecisionInputCandidate] = []
        for recommendation in retained.decisionSet.recommendations {
            try ensureCurrent(operationID)
            do {
                let candidate = try await memberRehydrator.rehydrate(
                    recommendation,
                    profile: trusted.profile,
                    forceAvailabilityReload: false
                )
                if candidate.decisionCandidate.availability == .eligible {
                    candidates.append(candidate)
                }
            } catch is CancellationError {
                throw CancellationError()
            } catch {
                continue
            }
        }
        guard !candidates.isEmpty else { return nil }
        let prepared = try await inputAssembler.prepare(trustedState: trusted)
        let retainedIDs = Set(candidates.map(\.seed.movieID))
        let input = inputAssembler.snapshot(
            prepared: prepared,
            candidates: candidates,
            currentCycleShownMovieIDs: []
        ).input
        let selection = repairComposer.compose(
            input: input,
            mandatoryRetainedMovieIDs: retainedIDs
        )
        guard !selection.recommendations.isEmpty else { return nil }
        let envelope = try await envelopeComposer.makeEnvelope(
            selection: selection,
            candidates: candidates,
            profile: trusted.profile,
            cycle: retained.decisionSet.cycle,
            sourceViewerStateSnapshotID: trusted.snapshotID
        )
        return RetainedDecisionSetValidation(
            snapshot: ThreeForTonightSnapshotFactory.snapshot(
                envelope,
                trustedState: trusted
            ),
            selection: selection,
            candidates: candidates
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
        let diagnosticsStartedAt = clock.now()
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
                let result = ThreeForTonightResult.retryableFailure(
                    reason: .repairFailed,
                    retained: retained
                )
                recordDiagnostics(failedDiagnostics(
                    startedAt: diagnosticsStartedAt,
                    trusted: trusted
                ))
                return result
            }
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
            let result = try await validatePersistAndPublish(
                repairedEnvelope,
                expectedTrustedState: trusted,
                sourceCycle: cycle,
                retained: rehydration.retained,
                recovery: false,
                operationID: operationID,
                staleRetryCount: 0
            )
            recordDiagnostics(makeDiagnostics(
                search: search,
                result: result,
                trusted: trusted,
                startedAt: diagnosticsStartedAt
            ))
            return result
        } catch is CancellationError {
            throw CancellationError()
        } catch let error as DecisionEngineInputAssemblyError {
            let result = ThreeForTonightResult.retryableFailure(
                reason: error.failureReason(recovery: false),
                retained: nil
            )
            recordDiagnostics(failedDiagnostics(
                startedAt: diagnosticsStartedAt,
                trusted: trusted
            ))
            return result
        } catch {
            let result = ThreeForTonightResult.retryableFailure(
                reason: .repairFailed,
                retained: nil
            )
            recordDiagnostics(failedDiagnostics(
                startedAt: diagnosticsStartedAt,
                trusted: trusted
            ))
            return result
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
            try await decisionSetRepository.replace(envelope)
        } catch is CancellationError {
            try? await decisionSetRepository.restorePersistenceCheckpoint(checkpoint)
            throw CancellationError()
        } catch {
            try? await decisionSetRepository.restorePersistenceCheckpoint(checkpoint)
            return .retryableFailure(
                reason: recovery ? .recoveryFailed : .persistenceFailed,
                retained: retained
            )
        }
        do {
            try ensureCurrent(operationID)
        } catch {
            try? await decisionSetRepository.restorePersistenceCheckpoint(checkpoint)
            throw error
        }
        guard await trustedStateLoader.matches(
            snapshotID: expectedTrustedState.snapshotID
        ) else {
            do {
                try await decisionSetRepository.restorePersistenceCheckpoint(checkpoint)
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
            try? await decisionSetRepository.restorePersistenceCheckpoint(checkpoint)
            throw error
        }
        return result(for: envelope, trusted: expectedTrustedState)
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

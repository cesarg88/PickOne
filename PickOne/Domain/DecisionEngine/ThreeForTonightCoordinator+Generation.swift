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
        let diagnosticsStartedAt = clock.now()
        do {
            let activeMovieIDs = Set(
                retained?.decisionSet.recommendations.map(\.display.movieID) ?? []
            )
            let search = try await progressiveSearch(
                cycle: cycle,
                trusted: trusted,
                activeMovieIDs: activeMovieIDs
            )
            try ensureCurrent(operationID)
            let signature = try cycleSignature(for: trusted)
            guard signature == cycle.identitySignature else {
                return .retryableFailure(
                    reason: .trustedInputsChanged,
                    retained: retained
                )
            }
            let searchCycle = try DecisionCycle(
                id: cycle.id,
                identitySignature: cycle.identitySignature,
                history: search.history
            )
            let exhaustedAt = search.exhausted ? clock.now() : nil
            let envelope: PersistedDecisionSet = if search.exhausted,
                                                    let retained,
                                                    !retained.decisionSet.recommendations.isEmpty
            {
                try PersistedDecisionSet(
                    id: makeUUID(),
                    generatedAt: clock.now(),
                    engineModelVersion: .p1Model,
                    cycle: searchCycle,
                    sourceViewerStateSnapshotID: trusted.snapshotID,
                    searchPolicyVersion: searchPolicy.version,
                    outcome: .exhausted(exhaustedAt: required(exhaustedAt)),
                    region: trusted.profile.region,
                    selectedProviderIDs: trusted.profile.selectedServices.map(\.providerID),
                    recommendations: retained.decisionSet.recommendations
                )
            } else {
                try await envelopeComposer.makeEnvelope(
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
            let result = try await validatePersistAndPublish(
                envelope,
                expectedTrustedState: trusted,
                sourceCycle: cycle,
                retained: retained,
                recovery: recovery,
                operationID: operationID,
                staleRetryCount: staleRetryCount
            )
            await diagnosticsSink.record(makeDiagnostics(
                search: search,
                result: result,
                trusted: trusted,
                startedAt: diagnosticsStartedAt
            ))
            return result
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

    private func makeDiagnostics(
        search: ProgressiveRecommendationSearchResult,
        result: ThreeForTonightResult,
        trusted: TrustedDecisionState,
        startedAt: Date
    ) -> RecommendationGenerationDiagnostics {
        let outcome: RecommendationDiagnosticOutcome = switch result {
            case .usable: .usable
            case .exhausted: .exhausted
            case .retryableFailure: .retryableFailure
        }
        return RecommendationGenerationDiagnostics(
            outcome: outcome,
            highestRecallStage: search.highestStage,
            totalDuration: max(0, clock.now().timeIntervalSince(startedAt)),
            timeToFirstUsableSet: search.timeToFirstUsableSet,
            recallStageDurations: search.recallStageDurations,
            discoverPageRequestCount: search.discoverRequestCount,
            uniqueRecalledCandidateCount: search.uniqueRecalledCandidateCount,
            candidateAvailabilityCheckCount: search.availabilityCheckCount,
            availabilityNetworkRequestCount: search.availabilityNetworkRequestCount,
            availabilityCacheHitCount: search.availabilityCacheHitCount,
            reactionMetadataHydrationRequestCount: trusted.reactions.count,
            maximumSimultaneousDiscoverRequests:
            search.discoverRequestCount == 0 ? 0 : 1,
            maximumSimultaneousAvailabilityRequests:
            search.maximumSimultaneousAvailabilityRequests,
            maximumTasteHydrationConcurrency: min(
                4,
                trusted.reactions.count
            )
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
            let cycle = targetCycle ?? envelope.cycle
            let search = try await progressiveSearch(
                cycle: cycle,
                trusted: trusted,
                activeMovieIDs: currentMovieIDs,
                retainedCandidates: currentCandidates,
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
                retained: retained,
                recovery: false,
                operationID: operationID,
                staleRetryCount: 0
            )
            await diagnosticsSink.record(makeDiagnostics(
                search: search,
                result: result,
                trusted: trusted,
                startedAt: diagnosticsStartedAt
            ))
            return result
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
                retained: latestRetained
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

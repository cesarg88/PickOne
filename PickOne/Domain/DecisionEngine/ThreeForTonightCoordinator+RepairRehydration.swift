import Foundation

struct RetainedDecisionSetValidation: Sendable {
    let snapshot: ThreeForTonightSnapshot
    let selection: DecisionSelection
    let candidates: [DecisionInputCandidate]
}

enum RetainedDecisionSetValidationResult: Sendable {
    case success(RetainedDecisionSetValidation?)
    case failure(ThreeForTonightSnapshot?)
}

struct RepairRehydration: Sendable {
    let candidates: [DecisionInputCandidate]
    let retained: ThreeForTonightSnapshot?
}

enum RepairRehydrationResult: Sendable {
    case success(RepairRehydration)
    case failure(ThreeForTonightSnapshot?)
}

extension ThreeForTonightCoordinator {
    func validateRetainedDecisionSet(
        _ retained: ThreeForTonightSnapshot,
        trusted: TrustedDecisionState,
        operationID: UUID
    ) async throws -> RetainedDecisionSetValidationResult {
        if retained.decisionSet.recommendations.isEmpty {
            return .success(RetainedDecisionSetValidation(
                snapshot: retained,
                selection: DecisionSelection(recommendations: []),
                candidates: []
            ))
        }
        let prepared = try await inputAssembler.prepare(trustedState: trusted)
        var candidates: [DecisionInputCandidate] = []
        var proven: RetainedDecisionSetValidation?
        for recommendation in retained.decisionSet.recommendations {
            try ensureCurrent(operationID)
            let candidate: DecisionInputCandidate
            do {
                candidate = try await memberRehydrator.rehydrate(
                    recommendation,
                    profile: trusted.profile,
                    forceAvailabilityReload: false
                )
            } catch is CancellationError {
                throw CancellationError()
            } catch {
                return .failure(proven?.snapshot)
            }
            guard candidate.decisionCandidate.availability == .eligible else {
                continue
            }
            candidates.append(candidate)
            do {
                proven = try await retainedValidation(
                    retained: retained,
                    candidates: candidates,
                    prepared: prepared,
                    trusted: trusted
                )
            } catch is CancellationError {
                throw CancellationError()
            } catch {
                return .failure(proven?.snapshot)
            }
        }
        return .success(proven)
    }

    private func retainedValidation(
        retained: ThreeForTonightSnapshot,
        candidates: [DecisionInputCandidate],
        prepared: PreparedDecisionEngineInput,
        trusted: TrustedDecisionState
    ) async throws -> RetainedDecisionSetValidation? {
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

    func rehydrateForRepair(
        envelope: PersistedDecisionSet,
        trusted: TrustedDecisionState,
        currentSignature: DecisionCycleSignature,
        reevaluatedMovieIDs: Set<Int>,
        forceAvailabilityReloadMovieID: Int?,
        operationID: UUID
    ) async throws -> RepairRehydrationResult {
        var candidates: [DecisionInputCandidate] = []
        var pendingMovieIDs = Set(
            envelope.recommendations.map(\.display.movieID)
        ).union(reevaluatedMovieIDs)
        var unsafeMovieIDs: Set<Int> = []
        var retained = safeRetainedSnapshot(
            envelope,
            trusted: trusted,
            currentSignature: currentSignature,
            additionallyUnsafeMovieIDs: pendingMovieIDs
        )
        for recommendation in envelope.recommendations {
            try ensureCurrent(operationID)
            let candidate: DecisionInputCandidate
            do {
                candidate = try await memberRehydrator.rehydrate(
                    recommendation,
                    profile: trusted.profile,
                    forceAvailabilityReload: recommendation.display.movieID
                        == forceAvailabilityReloadMovieID
                )
            } catch is CancellationError {
                throw CancellationError()
            } catch {
                return .failure(retained)
            }
            candidates.append(candidate)
            pendingMovieIDs.remove(candidate.seed.movieID)
            if candidate.decisionCandidate.availability != .eligible {
                unsafeMovieIDs.insert(candidate.seed.movieID)
            }
            retained = safeRetainedSnapshot(
                envelope,
                trusted: trusted,
                currentSignature: currentSignature,
                additionallyUnsafeMovieIDs: pendingMovieIDs.union(unsafeMovieIDs)
            )
        }
        return .success(RepairRehydration(
            candidates: candidates,
            retained: retained
        ))
    }
}

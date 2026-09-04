import Foundation

struct RepairRehydration: Sendable {
    let candidates: [DecisionInputCandidate]
    let retained: ThreeForTonightSnapshot?
}

enum RepairRehydrationResult: Sendable {
    case success(RepairRehydration)
    case failure(ThreeForTonightSnapshot?)
}

extension ThreeForTonightCoordinator {
    func rehydrateForRepair(
        envelope: PersistedDecisionSet,
        trusted: TrustedDecisionState,
        currentSignature: DecisionCycleSignature,
        reevaluatedMovieIDs: Set<Int>,
        forceAvailabilityReloadMovieID: Int?,
        operationID: UUID
    ) async throws -> RepairRehydrationResult {
        var candidates: [DecisionInputCandidate] = []
        var pendingMovieIDs = reevaluatedMovieIDs
        var unsafeMovieIDs: Set<Int> = []
        var retained = safeRetainedSnapshot(
            envelope,
            trusted: trusted,
            currentSignature: currentSignature,
            additionallyUnsafeMovieIDs: reevaluatedMovieIDs
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

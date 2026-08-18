import Foundation

struct ThreeForTonightSnapshot: Equatable, Sendable {
    let decisionSet: PersistedDecisionSet
    let savedMovieIDs: Set<Int>

    init(decisionSet: PersistedDecisionSet, savedMovieIDs: Set<Int>) {
        self.decisionSet = decisionSet
        self.savedMovieIDs = savedMovieIDs.intersection(
            decisionSet.recommendations.map(\.display.movieID)
        )
    }
}

enum ThreeForTonightFailureReason: Equatable, Sendable {
    case profileUnavailable
    case watchlistUnavailable
    case generationUnavailable
    case persistenceFailed
    case recoveryFailed
    case repairFailed
    case trustedInputsChanged
    case invariantViolation
}

enum ThreeForTonightResult: Equatable, Sendable {
    case usable(ThreeForTonightSnapshot)
    case retryableFailure(
        reason: ThreeForTonightFailureReason,
        retained: ThreeForTonightSnapshot?
    )
}

enum DecisionEligibilityRepairCause: Equatable, Sendable {
    case watchlist
    case availability
}

struct DecisionEligibilityChange: Equatable, Sendable {
    let movieID: Int
    let cause: DecisionEligibilityRepairCause

    init?(movieID: Int, cause: DecisionEligibilityRepairCause) {
        guard movieID > 0 else {
            return nil
        }
        self.movieID = movieID
        self.cause = cause
    }
}

protocol ThreeForTonightUseCase: Sendable {
    func load() async throws -> ThreeForTonightResult
    func refresh() async throws -> ThreeForTonightResult
    func repairAfterEligibilityChange(
        _ change: DecisionEligibilityChange
    ) async throws -> ThreeForTonightResult
}

protocol DecisionCycleSigning: Sendable {
    func signature(
        for identity: DecisionCycleIdentity
    ) throws -> DecisionCycleSignature
}

protocol DecisionSetClock: Sendable {
    func now() -> Date
}

struct SystemDecisionSetClock: DecisionSetClock {
    func now() -> Date {
        Date()
    }
}

enum ThreeForTonightSnapshotFactory {
    static func snapshot(
        _ envelope: PersistedDecisionSet,
        watchlistItems: [WatchlistItem]
    ) -> ThreeForTonightSnapshot {
        ThreeForTonightSnapshot(
            decisionSet: envelope,
            savedMovieIDs: Set(
                watchlistItems.lazy.filter { !$0.isWatched }.map(\.id)
            )
        )
    }

    static func safeRetainedSnapshot(
        _ envelope: PersistedDecisionSet,
        watchlistItems: [WatchlistItem],
        additionallyUnsafeMovieIDs: Set<Int> = []
    ) -> ThreeForTonightSnapshot? {
        let unsafeMovieIDs = localRepairMovieIDs(
            envelope: envelope,
            watchlistItems: watchlistItems
        ).union(additionallyUnsafeMovieIDs)
        guard !unsafeMovieIDs.isEmpty else {
            return snapshot(envelope, watchlistItems: watchlistItems)
        }

        do {
            let roles: [DecisionRole] = [.safeChoice, .stretchChoice, .discoveryChoice]
            let retained = try envelope.recommendations
                .filter { !unsafeMovieIDs.contains($0.display.movieID) }
                .enumerated()
                .map { index, recommendation in
                    let role = roles[index]
                    return try PersistedDecisionRecommendation(
                        role: role,
                        evidence: RecommendationEvidence(
                            primary: recommendation.evidence.primary,
                            diversity: role == .safeChoice
                                ? nil
                                : recommendation.evidence.diversity
                        ),
                        display: recommendation.display,
                        availability: recommendation.availability
                    )
                }
            let retainedEnvelope = try PersistedDecisionSet(
                id: envelope.id,
                generatedAt: envelope.generatedAt,
                engineModelVersion: envelope.engineModelVersion,
                cycle: envelope.cycle,
                region: envelope.region,
                selectedProviderIDs: envelope.selectedProviderIDs,
                recommendations: retained
            )
            return snapshot(retainedEnvelope, watchlistItems: watchlistItems)
        } catch {
            return nil
        }
    }

    static func localRepairMovieIDs(
        envelope: PersistedDecisionSet,
        watchlistItems: [WatchlistItem]
    ) -> Set<Int> {
        let watchedIDs = Set(watchlistItems.lazy.filter(\.isWatched).map(\.id))
        let savedIDs = Set(watchlistItems.lazy.filter { !$0.isWatched }.map(\.id))
        return Set(envelope.recommendations.compactMap { recommendation in
            let movieID = recommendation.display.movieID
            if watchedIDs.contains(movieID) {
                return movieID
            }
            if case .watchlistIntent = recommendation.evidence.primary,
               !savedIDs.contains(movieID)
            {
                return movieID
            }
            return nil
        })
    }
}

extension DecisionEngineInputAssemblyError {
    func failureReason(recovery: Bool) -> ThreeForTonightFailureReason {
        if recovery {
            return .recoveryFailed
        }
        return switch self {
            case .profileUnavailable: .profileUnavailable
            case .watchlistUnavailable: .watchlistUnavailable
            case .invalidCandidateContext,
                 .candidateRecallFailed,
                 .calibrationHydrationFailed,
                 .availabilitySourceUnavailable: .generationUnavailable
        }
    }
}

enum CoordinatorError: Error {
    case profileUnavailable
    case watchlistUnavailable
    case invariantViolation

    func failureReason(recovery: Bool) -> ThreeForTonightFailureReason {
        if recovery {
            return .recoveryFailed
        }
        return switch self {
            case .profileUnavailable: .profileUnavailable
            case .watchlistUnavailable: .watchlistUnavailable
            case .invariantViolation: .invariantViolation
        }
    }
}

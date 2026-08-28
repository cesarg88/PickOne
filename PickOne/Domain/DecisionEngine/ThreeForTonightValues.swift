import Foundation

enum ThreeForTonightRequest: Sendable {
    case load
    case refresh
    case repair(DecisionEligibilityChange)
    case reconcile(DecisionViewerStateChange)
}

extension DecisionEligibilityChange {
    var availabilityMovieID: Int? {
        cause == .availability ? movieID : nil
    }
}

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
    func reconcileAfterViewerStateChange(
        _ change: DecisionViewerStateChange
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
        trustedState: TrustedDecisionState
    ) -> ThreeForTonightSnapshot {
        ThreeForTonightSnapshot(
            decisionSet: envelope,
            savedMovieIDs: trustedState.savedUnwatchedMovieIDs
        )
    }

    static func safeRetainedSnapshot(
        _ envelope: PersistedDecisionSet,
        trustedState: TrustedDecisionState,
        currentCycleSignature: DecisionCycleSignature,
        additionallyUnsafeMovieIDs: Set<Int> = []
    ) -> ThreeForTonightSnapshot? {
        let unsafeMovieIDs = localRepairMovieIDs(
            envelope: envelope,
            trustedState: trustedState,
            currentCycleSignature: currentCycleSignature
        ).union(additionallyUnsafeMovieIDs)
        guard !unsafeMovieIDs.isEmpty else {
            return snapshot(envelope, trustedState: trustedState)
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
                sourceViewerStateSnapshotID: envelope.sourceViewerStateSnapshotID,
                region: envelope.region,
                selectedProviderIDs: envelope.selectedProviderIDs,
                recommendations: retained
            )
            return snapshot(retainedEnvelope, trustedState: trustedState)
        } catch {
            return nil
        }
    }

    static func localRepairMovieIDs(
        envelope: PersistedDecisionSet,
        trustedState: TrustedDecisionState,
        currentCycleSignature: DecisionCycleSignature
    ) -> Set<Int> {
        let hasStaleTasteEvidence =
            envelope.cycle.identitySignature != currentCycleSignature
        return Set(envelope.recommendations.compactMap { recommendation in
            let movieID = recommendation.display.movieID
            if trustedState.recommendationExcludedMovieIDs.contains(movieID) {
                return movieID
            }
            if recommendation.evidence.requiresAnchorRepair(
                reactions: trustedState.reactions
            ) {
                return movieID
            }
            if recommendation.evidence.requiresReadableGenreRepair {
                return movieID
            }
            if hasStaleTasteEvidence,
               recommendation.evidence.requiresTasteEvidenceRepair(
                   reactions: trustedState.reactions
               )
            {
                return movieID
            }
            if case .watchlistIntent = recommendation.evidence.primary,
               !trustedState.savedUnwatchedMovieIDs.contains(movieID)
            {
                return movieID
            }
            return nil
        })
    }
}

private extension RecommendationEvidence {
    var requiresReadableGenreRepair: Bool {
        let genres: [DecisionGenre] = switch primary {
            case let .watchlistIntent(match):
                switch match {
                    case let .positiveAnchor(anchor): anchor.sharedGenres
                    case let .positiveAffinity(affinity): affinity.genres
                }
            case let .positiveAnchor(anchor):
                anchor.sharedGenres
            case let .positiveGenreAffinity(affinity):
                affinity.genres
            case .sparseQuality:
                []
        }
        return genres.contains { $0.name == nil }
    }

    func requiresAnchorRepair(reactions: [Int: MovieReaction]) -> Bool {
        let anchor: PositiveAnchorEvidence? = switch primary {
            case let .watchlistIntent(match):
                if case let .positiveAnchor(anchor) = match {
                    anchor
                } else {
                    nil
                }
            case let .positiveAnchor(anchor):
                anchor
            case .positiveGenreAffinity, .sparseQuality:
                nil
        }
        guard let anchor else { return false }
        guard anchor.anchorGenres != nil else { return true }

        let currentReaction = reactions[anchor.movieID]
        return switch anchor.reaction {
            case .loved: currentReaction != MovieReaction.loveIt
            case .liked: currentReaction != MovieReaction.likeIt
        }
    }

    func requiresTasteEvidenceRepair(reactions: [Int: MovieReaction]) -> Bool {
        switch primary {
            case let .watchlistIntent(match):
                if case .positiveAffinity = match {
                    return true
                }
                return false
            case .positiveGenreAffinity:
                return true
            case .sparseQuality:
                let directionalCount = reactions.values.count {
                    $0.calibrationReaction.isDirectionalEvidence
                }
                return P1Scoring.profileConfidence(
                    directionalCount: directionalCount
                ) >= 1.0 / 3.0
            case .positiveAnchor:
                return false
        }
    }
}

extension DecisionEngineInputAssemblyError {
    func failureReason(recovery: Bool) -> ThreeForTonightFailureReason {
        if recovery {
            return .recoveryFailed
        }
        return switch self {
            case .invalidCandidateContext,
                 .candidateRecallFailed,
                 .tasteHydrationFailed,
                 .availabilitySourceUnavailable: .generationUnavailable
        }
    }
}

enum CoordinatorError: Error {
    case invariantViolation

    func failureReason(recovery: Bool) -> ThreeForTonightFailureReason {
        if recovery {
            return .recoveryFailed
        }
        return .invariantViolation
    }
}

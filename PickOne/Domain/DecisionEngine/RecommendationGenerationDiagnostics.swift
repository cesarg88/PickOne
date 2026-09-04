import Foundation
import Synchronization

enum RecommendationDiagnosticOutcome: Equatable, Sendable {
    case usable
    case exhausted
    case retryableFailure
}

struct RecommendationRecallStageDuration: Equatable, Sendable {
    let stage: RecommendationRecallStageKind
    let duration: TimeInterval
}

struct RecommendationGenerationDiagnostics: Equatable, Sendable {
    let outcome: RecommendationDiagnosticOutcome
    let highestRecallStage: RecommendationRecallStageKind
    let totalDuration: TimeInterval
    let timeToFirstUsableSet: TimeInterval?
    let recallStageDurations: [RecommendationRecallStageDuration]
    let discoverPageRequestCount: Int
    let uniqueRecalledCandidateCount: Int
    let candidateAvailabilityCheckCount: Int
    let availabilityNetworkRequestCount: Int
    let availabilityCacheHitCount: Int
    let reactionMetadataHydrationRequestCount: Int
    let maximumSimultaneousDiscoverRequests: Int
    let maximumSimultaneousAvailabilityRequests: Int
    let maximumTasteHydrationConcurrency: Int
}

final class RecommendationOperationDiagnostics: Sendable {
    private struct State: Sendable {
        var highestStage = RecommendationRecallStageKind.normal
        var recallStageDurations: [RecommendationRecallStageDuration] = []
        var discoverRequestCount = 0
        var recalledMovieIDs: Set<Int> = []
        var timeToFirstUsableSet: TimeInterval?
        var tasteHydrationRequestCount = 0
        var activeTasteHydrations = 0
        var maximumTasteHydrationConcurrency = 0
    }

    let availability = AvailabilityOperationDiagnostics()
    private let state = Mutex(State())

    func beginRecallStage(_ stage: RecommendationRecallStageKind) {
        state.withLock { $0.highestStage = stage }
    }

    func completeRecallStage(_ stage: RecommendationRecallStageKind, duration: TimeInterval) {
        state.withLock {
            $0.recallStageDurations.append(RecommendationRecallStageDuration(
                stage: stage,
                duration: duration
            ))
        }
    }

    func recordDiscoverRequest() {
        state.withLock { $0.discoverRequestCount += 1 }
    }

    func recordRecalledCandidates(_ movieIDs: some Sequence<Int>) {
        state.withLock { $0.recalledMovieIDs.formUnion(movieIDs) }
    }

    func recordFirstUsableSet(after duration: TimeInterval) {
        state.withLock {
            if $0.timeToFirstUsableSet == nil {
                $0.timeToFirstUsableSet = duration
            }
        }
    }

    func tasteHydrationStarted() {
        state.withLock {
            $0.tasteHydrationRequestCount += 1
            $0.activeTasteHydrations += 1
            $0.maximumTasteHydrationConcurrency = max(
                $0.maximumTasteHydrationConcurrency,
                $0.activeTasteHydrations
            )
        }
    }

    func tasteHydrationFinished() {
        state.withLock { $0.activeTasteHydrations -= 1 }
    }

    func snapshot(
        outcome: RecommendationDiagnosticOutcome,
        totalDuration: TimeInterval
    ) -> RecommendationGenerationDiagnostics {
        let availabilityCounters = availability.counters
        return state.withLock {
            RecommendationGenerationDiagnostics(
                outcome: outcome,
                highestRecallStage: $0.highestStage,
                totalDuration: totalDuration,
                timeToFirstUsableSet: $0.timeToFirstUsableSet,
                recallStageDurations: $0.recallStageDurations,
                discoverPageRequestCount: $0.discoverRequestCount,
                uniqueRecalledCandidateCount: $0.recalledMovieIDs.count,
                candidateAvailabilityCheckCount: availabilityCounters.checks,
                availabilityNetworkRequestCount: availabilityCounters.networkRequests,
                availabilityCacheHitCount: availabilityCounters.cacheHits,
                reactionMetadataHydrationRequestCount: $0.tasteHydrationRequestCount,
                maximumSimultaneousDiscoverRequests:
                $0.discoverRequestCount == 0 ? 0 : 1,
                maximumSimultaneousAvailabilityRequests:
                availabilityCounters.maximumSimultaneousNetworkRequests,
                maximumTasteHydrationConcurrency: $0.maximumTasteHydrationConcurrency
            )
        }
    }
}

enum RecommendationDiagnosticsContext {
    @TaskLocal static var operation: RecommendationOperationDiagnostics?
}

protocol RecommendationGenerationDiagnosticsSink: Sendable {
    func record(_ diagnostics: RecommendationGenerationDiagnostics) async
}

struct NoOpRecommendationDiagnosticsSink:
    RecommendationGenerationDiagnosticsSink
{
    func record(_ diagnostics: RecommendationGenerationDiagnostics) async {}
}

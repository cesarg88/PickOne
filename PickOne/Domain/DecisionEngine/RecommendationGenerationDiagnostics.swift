import Foundation

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

protocol RecommendationGenerationDiagnosticsSink: Sendable {
    func record(_ diagnostics: RecommendationGenerationDiagnostics) async
}

struct NoOpRecommendationDiagnosticsSink:
    RecommendationGenerationDiagnosticsSink
{
    func record(_ diagnostics: RecommendationGenerationDiagnostics) async {}
}

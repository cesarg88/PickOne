import Foundation

extension ThreeForTonightCoordinator {
    func recordDiagnostics(_ diagnostics: RecommendationGenerationDiagnostics) {
        let sink = diagnosticsSink
        Task {
            await sink.record(diagnostics)
        }
    }

    func failedDiagnostics(
        startedAt: Date,
        trusted: TrustedDecisionState
    ) -> RecommendationGenerationDiagnostics {
        RecommendationGenerationDiagnostics(
            outcome: .retryableFailure,
            highestRecallStage: .normal,
            totalDuration: max(0, clock.now().timeIntervalSince(startedAt)),
            timeToFirstUsableSet: nil,
            recallStageDurations: [],
            discoverPageRequestCount: 0,
            uniqueRecalledCandidateCount: 0,
            candidateAvailabilityCheckCount: 0,
            availabilityNetworkRequestCount: 0,
            availabilityCacheHitCount: 0,
            reactionMetadataHydrationRequestCount: trusted.reactions.count,
            maximumSimultaneousDiscoverRequests: 0,
            maximumSimultaneousAvailabilityRequests: 0,
            maximumTasteHydrationConcurrency: min(4, trusted.reactions.count)
        )
    }

    func makeDiagnostics(
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
}

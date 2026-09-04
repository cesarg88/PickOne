import Foundation

struct ProgressiveRecommendationSearchResult: Sendable {
    let selection: DecisionSelection
    let candidates: [DecisionInputCandidate]
    let history: RecommendationHistory
    let exhausted: Bool
    let highestStage: RecommendationRecallStageKind
    let discoverRequestCount: Int
    let uniqueRecalledCandidateCount: Int
    let availabilityCheckCount: Int
    let availabilityNetworkRequestCount: Int
    let availabilityCacheHitCount: Int
    let maximumSimultaneousAvailabilityRequests: Int
    let recallStageDurations: [RecommendationRecallStageDuration]
    let timeToFirstUsableSet: TimeInterval?
}

extension ThreeForTonightCoordinator {
    func progressiveSearch(
        cycle: DecisionCycle,
        trusted: TrustedDecisionState,
        activeMovieIDs: Set<Int>,
        retainedCandidates: [DecisionInputCandidate] = [],
        mandatoryRetainedMovieIDs: Set<Int> = [],
        additionallyExcludedMovieIDs: Set<Int> = []
    ) async throws -> ProgressiveRecommendationSearchResult {
        let diagnostics = AvailabilityOperationDiagnostics()
        return try await AvailabilityDiagnosticsContext.$operation.withValue(
            diagnostics
        ) {
            try await performProgressiveSearch(
                cycle: cycle,
                trusted: trusted,
                activeMovieIDs: activeMovieIDs,
                retainedCandidates: retainedCandidates,
                mandatoryRetainedMovieIDs: mandatoryRetainedMovieIDs,
                additionallyExcludedMovieIDs: additionallyExcludedMovieIDs,
                diagnostics: diagnostics
            )
        }
    }

    private func performProgressiveSearch(
        cycle: DecisionCycle,
        trusted: TrustedDecisionState,
        activeMovieIDs: Set<Int>,
        retainedCandidates: [DecisionInputCandidate],
        mandatoryRetainedMovieIDs: Set<Int>,
        additionallyExcludedMovieIDs: Set<Int>,
        diagnostics: AvailabilityOperationDiagnostics
    ) async throws -> ProgressiveRecommendationSearchResult {
        let searchStartedAt = clock.now()
        let prepared = try await inputAssembler.prepare(trustedState: trusted)
        var candidates = retainedCandidates
        var recalledMovieIDs = Set<Int>()
        let history = cycle.history
        var selection = prioritizedSelection(
            prepared: prepared,
            candidates: candidates,
            history: history,
            activeMovieIDs: activeMovieIDs,
            mandatoryRetainedMovieIDs: mandatoryRetainedMovieIDs
        )
        var highestStage = RecommendationRecallStageKind.normal
        var discoverRequestCount = 0
        var uniqueRecalledCandidateCount = 0
        var maxAvailabilityConcurrency = 0
        var recallStageDurations: [RecommendationRecallStageDuration] = []

        if selection.recommendations.count == 3 {
            return successfulRetainedSearchResult(
                selection: selection,
                candidates: candidates,
                history: history,
                searchStartedAt: searchStartedAt,
                availabilityDiagnostics: diagnostics
            )
        }

        for stage in searchPolicy.stages {
            let stageStartedAt = clock.now()
            let batch = try await inputAssembler.recallAndEnrich(
                pages: stage.pageRange,
                prepared: prepared,
                excludingMovieIDs: trusted.recommendationExcludedMovieIDs
                    .union(activeMovieIDs)
                    .union(additionallyExcludedMovieIDs),
                alreadyRecalledMovieIDs: recalledMovieIDs
            )
            candidates.append(contentsOf: batch.candidates)
            recalledMovieIDs.formUnion(batch.recalledMovieIDs)
            discoverRequestCount += batch.requestedPageCount
            uniqueRecalledCandidateCount = recalledMovieIDs.count
            maxAvailabilityConcurrency = updatedAvailabilityConcurrency(maxAvailabilityConcurrency, batch)
            highestStage = stage.kind
            recallStageDurations.append(RecommendationRecallStageDuration(
                stage: stage.kind,
                duration: max(0, clock.now().timeIntervalSince(stageStartedAt))
            ))
            selection = prioritizedSelection(
                prepared: prepared,
                candidates: candidates,
                history: history,
                activeMovieIDs: activeMovieIDs,
                mandatoryRetainedMovieIDs: mandatoryRetainedMovieIDs
            )
            if selection.recommendations.count == 3 {
                return successfulSearchResult(
                    selection: selection,
                    candidates: candidates,
                    history: history,
                    highestStage: highestStage,
                    discoverRequestCount: discoverRequestCount,
                    uniqueRecalledCandidateCount: uniqueRecalledCandidateCount,
                    maximumSimultaneousAvailabilityRequests:
                    maxAvailabilityConcurrency,
                    recallStageDurations: recallStageDurations,
                    searchStartedAt: searchStartedAt,
                    availabilityDiagnostics: diagnostics
                )
            }
            if batch.reachedEmptyPage {
                break
            }
        }

        return searchResultAfterRollover(
            prepared: prepared,
            selection: selection,
            candidates: candidates,
            history: history,
            highestStage: highestStage,
            discoverRequestCount: discoverRequestCount,
            uniqueRecalledCandidateCount: uniqueRecalledCandidateCount,
            maximumSimultaneousAvailabilityRequests:
            maxAvailabilityConcurrency,
            recallStageDurations: recallStageDurations,
            activeMovieIDs: activeMovieIDs,
            mandatoryRetainedMovieIDs: mandatoryRetainedMovieIDs,
            searchStartedAt: searchStartedAt,
            availabilityDiagnostics: diagnostics
        )
    }

    private func updatedAvailabilityConcurrency(
        _ current: Int,
        _ batch: DecisionInputCandidateBatch
    ) -> Int {
        max(current, batch.maximumSimultaneousAvailabilityChecks)
    }

    private func successfulRetainedSearchResult(
        selection: DecisionSelection,
        candidates: [DecisionInputCandidate],
        history: RecommendationHistory,
        searchStartedAt: Date,
        availabilityDiagnostics: AvailabilityOperationDiagnostics
    ) -> ProgressiveRecommendationSearchResult {
        successfulSearchResult(
            selection: selection,
            candidates: candidates,
            history: history,
            highestStage: .normal,
            discoverRequestCount: 0,
            uniqueRecalledCandidateCount: 0,
            maximumSimultaneousAvailabilityRequests: 0,
            recallStageDurations: [],
            searchStartedAt: searchStartedAt,
            availabilityDiagnostics: availabilityDiagnostics
        )
    }

    private func searchResultAfterRollover(
        prepared: PreparedDecisionEngineInput,
        selection initialSelection: DecisionSelection,
        candidates: [DecisionInputCandidate],
        history initialHistory: RecommendationHistory,
        highestStage initialHighestStage: RecommendationRecallStageKind,
        discoverRequestCount: Int,
        uniqueRecalledCandidateCount: Int,
        maximumSimultaneousAvailabilityRequests: Int,
        recallStageDurations: [RecommendationRecallStageDuration],
        activeMovieIDs: Set<Int>,
        mandatoryRetainedMovieIDs: Set<Int>,
        searchStartedAt: Date,
        availabilityDiagnostics: AvailabilityOperationDiagnostics
    ) -> ProgressiveRecommendationSearchResult {
        var selection = initialSelection
        var history = initialHistory
        var highestStage = initialHighestStage
        while selection.recommendations.count < 3 {
            let released = history.releasingOldestSuppression(
                count: searchPolicy.rolloverStep,
                excluding: activeMovieIDs
            )
            guard released != history else { break }
            history = released
            highestStage = .rollover
            selection = prioritizedSelection(
                prepared: prepared,
                candidates: candidates,
                history: history,
                activeMovieIDs: activeMovieIDs,
                mandatoryRetainedMovieIDs: mandatoryRetainedMovieIDs
            )
        }

        let availabilityCounters = availabilityDiagnostics.counters
        return ProgressiveRecommendationSearchResult(
            selection: selection,
            candidates: candidates,
            history: history,
            exhausted: selection.recommendations.count < 3,
            highestStage: highestStage,
            discoverRequestCount: discoverRequestCount,
            uniqueRecalledCandidateCount: uniqueRecalledCandidateCount,
            availabilityCheckCount: candidates.count,
            availabilityNetworkRequestCount: availabilityCounters.networkRequests,
            availabilityCacheHitCount: availabilityCounters.cacheHits,
            maximumSimultaneousAvailabilityRequests:
            availabilityCounters.maximumSimultaneousNetworkRequests,
            recallStageDurations: recallStageDurations,
            timeToFirstUsableSet: selection.recommendations.count == 3
                ? max(0, clock.now().timeIntervalSince(searchStartedAt))
                : nil
        )
    }

    private func successfulSearchResult(
        selection: DecisionSelection,
        candidates: [DecisionInputCandidate],
        history: RecommendationHistory,
        highestStage: RecommendationRecallStageKind,
        discoverRequestCount: Int,
        uniqueRecalledCandidateCount: Int,
        maximumSimultaneousAvailabilityRequests: Int,
        recallStageDurations: [RecommendationRecallStageDuration],
        searchStartedAt: Date,
        availabilityDiagnostics: AvailabilityOperationDiagnostics
    ) -> ProgressiveRecommendationSearchResult {
        let availabilityCounters = availabilityDiagnostics.counters
        return ProgressiveRecommendationSearchResult(
            selection: selection,
            candidates: candidates,
            history: history,
            exhausted: false,
            highestStage: highestStage,
            discoverRequestCount: discoverRequestCount,
            uniqueRecalledCandidateCount: uniqueRecalledCandidateCount,
            availabilityCheckCount: candidates.count,
            availabilityNetworkRequestCount: availabilityCounters.networkRequests,
            availabilityCacheHitCount: availabilityCounters.cacheHits,
            maximumSimultaneousAvailabilityRequests:
            availabilityCounters.maximumSimultaneousNetworkRequests,
            recallStageDurations: recallStageDurations,
            timeToFirstUsableSet: max(
                0,
                clock.now().timeIntervalSince(searchStartedAt)
            )
        )
    }

    private func prioritizedSelection(
        prepared: PreparedDecisionEngineInput,
        candidates: [DecisionInputCandidate],
        history: RecommendationHistory,
        activeMovieIDs: Set<Int>,
        mandatoryRetainedMovieIDs: Set<Int>
    ) -> DecisionSelection {
        let retainedInput = inputAssembler.snapshot(
            prepared: prepared,
            candidates: candidates.filter {
                mandatoryRetainedMovieIDs.contains($0.seed.movieID)
            },
            currentCycleShownMovieIDs: Set(history.recentlyShownMovieIDs)
                .union(activeMovieIDs)
        ).input
        let validRetained = repairComposer.compose(
            input: retainedInput,
            mandatoryRetainedMovieIDs: mandatoryRetainedMovieIDs
        )
        let validRetainedMovieIDs = Set(
            validRetained.recommendations.map(\.candidate.movieID)
        )
        let neverShownInput = inputAssembler.snapshot(
            prepared: prepared,
            candidates: candidates,
            currentCycleShownMovieIDs: history.allShownMovieIDs.union(activeMovieIDs)
        ).input
        let neverShown = selector.select(from: neverShownInput)
        let vacantCount = max(0, 3 - validRetainedMovieIDs.count)
        let protectedNeverShownMovieIDs = Set(
            neverShown.recommendations
                .prefix(vacantCount)
                .map(\.candidate.movieID)
        )

        let suppression = Set(history.recentlyShownMovieIDs).union(activeMovieIDs)
        let cumulativeInput = inputAssembler.snapshot(
            prepared: prepared,
            candidates: candidates,
            currentCycleShownMovieIDs: suppression
        ).input
        return repairComposer.compose(
            input: cumulativeInput,
            mandatoryRetainedMovieIDs: validRetainedMovieIDs
                .union(protectedNeverShownMovieIDs)
        )
    }
}

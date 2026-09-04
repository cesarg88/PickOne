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
        let searchStartedAt = clock.now()
        let availabilityBaseline = await inputAssembler.availabilityDiagnosticsCounters()
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
            return await successfulRetainedSearchResult(
                selection: selection,
                candidates: candidates,
                history: history,
                searchStartedAt: searchStartedAt,
                initialAvailabilityCounters: availabilityBaseline
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
                return await successfulSearchResult(
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
                    initialAvailabilityCounters: availabilityBaseline
                )
            }
            if batch.reachedEmptyPage {
                break
            }
        }

        return await searchResultAfterRollover(
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
            initialAvailabilityCounters: availabilityBaseline
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
        initialAvailabilityCounters: AvailabilityDiagnosticsCounters?
    ) async -> ProgressiveRecommendationSearchResult {
        await successfulSearchResult(
            selection: selection,
            candidates: candidates,
            history: history,
            highestStage: .normal,
            discoverRequestCount: 0,
            uniqueRecalledCandidateCount: 0,
            maximumSimultaneousAvailabilityRequests: 0,
            recallStageDurations: [],
            searchStartedAt: searchStartedAt,
            initialAvailabilityCounters: initialAvailabilityCounters
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
        initialAvailabilityCounters: AvailabilityDiagnosticsCounters?
    ) async -> ProgressiveRecommendationSearchResult {
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

        let availabilityCounters = await availabilityCounterDelta(
            from: initialAvailabilityCounters
        )
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
            maximumSimultaneousAvailabilityRequests,
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
        initialAvailabilityCounters: AvailabilityDiagnosticsCounters?
    ) async -> ProgressiveRecommendationSearchResult {
        let availabilityCounters = await availabilityCounterDelta(
            from: initialAvailabilityCounters
        )
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
            maximumSimultaneousAvailabilityRequests,
            recallStageDurations: recallStageDurations,
            timeToFirstUsableSet: max(
                0,
                clock.now().timeIntervalSince(searchStartedAt)
            )
        )
    }

    private func availabilityCounterDelta(
        from initial: AvailabilityDiagnosticsCounters?
    ) async -> AvailabilityDiagnosticsCounters {
        guard let current = await inputAssembler.availabilityDiagnosticsCounters() else {
            return AvailabilityDiagnosticsCounters(
                cacheHits: 0,
                networkRequests: 0,
                maximumSimultaneousNetworkRequests: 0
            )
        }
        return AvailabilityDiagnosticsCounters(
            cacheHits: max(0, current.cacheHits - (initial?.cacheHits ?? 0)),
            networkRequests: max(
                0,
                current.networkRequests - (initial?.networkRequests ?? 0)
            ),
            maximumSimultaneousNetworkRequests:
            current.maximumSimultaneousNetworkRequests
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

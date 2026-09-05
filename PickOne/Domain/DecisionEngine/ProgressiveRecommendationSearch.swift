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
        let diagnostics = AvailabilityDiagnosticsContext.operation
            ?? AvailabilityOperationDiagnostics()
        return try await performProgressiveSearch(
            cycle: cycle,
            trusted: trusted,
            activeMovieIDs: activeMovieIDs,
            retainedCandidates: retainedCandidates,
            mandatoryRetainedMovieIDs: mandatoryRetainedMovieIDs,
            additionallyExcludedMovieIDs: additionallyExcludedMovieIDs,
            diagnostics: diagnostics
        )
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
        var hasUnresolvedAvailability = false
        let excludedMovieIDs = trusted.recommendationExcludedMovieIDs
            .union(activeMovieIDs)
            .union(additionallyExcludedMovieIDs)

        if let completed = completedRetainedSearchResult(
            selection: selection,
            candidates: candidates,
            history: history,
            searchStartedAt: searchStartedAt,
            availabilityDiagnostics: diagnostics
        ) {
            return completed
        }

        for stage in searchPolicy.stages {
            let batch = try await recallBatch(
                stage: stage,
                prepared: prepared,
                excludedMovieIDs: excludedMovieIDs,
                recalledMovieIDs: recalledMovieIDs,
                durations: &recallStageDurations
            )
            candidates.append(contentsOf: batch.candidates)
            recalledMovieIDs.formUnion(batch.recalledMovieIDs)
            hasUnresolvedAvailability = hasUnresolvedAvailability
                || batch.hasUnresolvedAvailability
            discoverRequestCount += batch.requestedPageCount
            uniqueRecalledCandidateCount = recalledMovieIDs.count
            maxAvailabilityConcurrency = updatedAvailabilityConcurrency(maxAvailabilityConcurrency, batch)
            highestStage = stage.kind
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

        return try searchResultAfterRollover(
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
            availabilityDiagnostics: diagnostics,
            hasUnresolvedAvailability: hasUnresolvedAvailability
        )
    }

    private func recallBatch(
        stage: RecommendationRecallStage,
        prepared: PreparedDecisionEngineInput,
        excludedMovieIDs: Set<Int>,
        recalledMovieIDs: Set<Int>,
        durations: inout [RecommendationRecallStageDuration]
    ) async throws -> DecisionInputCandidateBatch {
        let stageStartedAt = clock.now()
        RecommendationDiagnosticsContext.operation?.beginRecallStage(stage.kind)
        do {
            let batch = try await inputAssembler.recallAndEnrich(
                pages: stage.pageRange,
                prepared: prepared,
                excludingMovieIDs: excludedMovieIDs,
                alreadyRecalledMovieIDs: recalledMovieIDs
            )
            recordCompletedRecallStage(
                stage.kind,
                startedAt: stageStartedAt,
                durations: &durations
            )
            return batch
        } catch {
            recordCompletedRecallStage(
                stage.kind,
                startedAt: stageStartedAt,
                durations: &durations
            )
            throw error
        }
    }

    private func completedRetainedSearchResult(
        selection: DecisionSelection,
        candidates: [DecisionInputCandidate],
        history: RecommendationHistory,
        searchStartedAt: Date,
        availabilityDiagnostics: AvailabilityOperationDiagnostics
    ) -> ProgressiveRecommendationSearchResult? {
        guard selection.recommendations.count == 3 else { return nil }
        RecommendationDiagnosticsContext.operation?.recordFirstUsableSet(
            after: max(0, clock.now().timeIntervalSince(searchStartedAt))
        )
        return successfulRetainedSearchResult(
            selection: selection,
            candidates: candidates,
            history: history,
            searchStartedAt: searchStartedAt,
            availabilityDiagnostics: availabilityDiagnostics
        )
    }

    private func updatedAvailabilityConcurrency(
        _ current: Int,
        _ batch: DecisionInputCandidateBatch
    ) -> Int {
        max(current, batch.maximumSimultaneousAvailabilityChecks)
    }

    private func recordCompletedRecallStage(
        _ stage: RecommendationRecallStageKind,
        startedAt: Date,
        durations: inout [RecommendationRecallStageDuration]
    ) {
        let duration = max(0, clock.now().timeIntervalSince(startedAt))
        durations.append(RecommendationRecallStageDuration(
            stage: stage,
            duration: duration
        ))
        RecommendationDiagnosticsContext.operation?.completeRecallStage(
            stage,
            duration: duration
        )
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
        availabilityDiagnostics: AvailabilityOperationDiagnostics,
        hasUnresolvedAvailability: Bool
    ) throws -> ProgressiveRecommendationSearchResult {
        var selection = initialSelection
        var history = initialHistory
        var highestStage = initialHighestStage
        var recallStageDurations = recallStageDurations
        var released = history.releasingOldestSuppression(
            count: searchPolicy.rolloverStep,
            excluding: activeMovieIDs
        )
        if selection.recommendations.count < 3, released != history {
            let rolloverStartedAt = clock.now()
            highestStage = .rollover
            RecommendationDiagnosticsContext.operation?.beginRecallStage(.rollover)
            while selection.recommendations.count < 3, released != history {
                history = released
                selection = prioritizedSelection(
                    prepared: prepared,
                    candidates: candidates,
                    history: history,
                    activeMovieIDs: activeMovieIDs,
                    mandatoryRetainedMovieIDs: mandatoryRetainedMovieIDs
                )
                released = history.releasingOldestSuppression(
                    count: searchPolicy.rolloverStep,
                    excluding: activeMovieIDs
                )
            }
            recordCompletedRecallStage(
                .rollover,
                startedAt: rolloverStartedAt,
                durations: &recallStageDurations
            )
        }

        guard selection.recommendations.count == 3 || !hasUnresolvedAvailability else {
            throw DecisionEngineInputAssemblyError.availabilitySourceUnavailable
        }

        if selection.recommendations.count == 3 {
            RecommendationDiagnosticsContext.operation?.recordFirstUsableSet(
                after: max(0, clock.now().timeIntervalSince(searchStartedAt))
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
        RecommendationDiagnosticsContext.operation?.recordFirstUsableSet(
            after: max(0, clock.now().timeIntervalSince(searchStartedAt))
        )
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

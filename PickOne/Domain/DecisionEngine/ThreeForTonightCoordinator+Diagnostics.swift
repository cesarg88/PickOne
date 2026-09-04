import Foundation

extension ThreeForTonightCoordinator {
    func recordDiagnostics(_ diagnostics: RecommendationGenerationDiagnostics) {
        let sink = diagnosticsSink
        Task {
            await sink.record(diagnostics)
        }
    }

    func withOperationDiagnostics(
        startedAt: Date,
        operation: () async throws -> ThreeForTonightResult
    ) async throws -> ThreeForTonightResult {
        if RecommendationDiagnosticsContext.operation != nil {
            return try await operation()
        }
        let diagnostics = RecommendationOperationDiagnostics()
        return try await RecommendationDiagnosticsContext.$operation.withValue(
            diagnostics
        ) {
            try await AvailabilityDiagnosticsContext.$operation.withValue(
                diagnostics.availability
            ) {
                let result = try await operation()
                recordDiagnostics(diagnostics.snapshot(
                    outcome: diagnosticOutcome(for: result),
                    totalDuration: max(0, clock.now().timeIntervalSince(startedAt))
                ))
                return result
            }
        }
    }

    private func diagnosticOutcome(
        for result: ThreeForTonightResult
    ) -> RecommendationDiagnosticOutcome {
        switch result {
            case .usable: .usable
            case .exhausted: .exhausted
            case .retryableFailure: .retryableFailure
        }
    }
}

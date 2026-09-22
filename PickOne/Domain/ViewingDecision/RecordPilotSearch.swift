import Foundation

struct RecordPilotSearch: RecommendationGenerationDiagnosticsSink {
    let repository: any ViewingDecisionRepository

    func record(_ diagnostics: RecommendationGenerationDiagnostics) async {
        let id = UUID()
        let date = Date()
        let evidence = PilotSearchEvidence(
            id: id, recordedAt: date, duration: diagnostics.totalDuration,
            stage: diagnostics.highestRecallStage, outcome: diagnostics.outcome
        )
        // Diagnostic failure must never change the recommendation result.
        _ = try? await repository.apply(ViewingDecisionOperation(
            id: id, action: .search(evidence),
            moment: DecisionMoment(wall: date, monotonicSeconds: 0, runtimeID: id)
        ))
    }
}

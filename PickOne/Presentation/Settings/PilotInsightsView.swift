import SwiftUI
import UniformTypeIdentifiers

@MainActor
struct PilotInsightsView: View {
    @Bindable var model: PilotInsightsViewModel
    @State private var confirmsDeletion = false
    @State private var exportsFile = false

    var body: some View {
        List {
            Section {
                Text(
                    "Local household diagnostics, not a statistical experiment. Completed history is kept for 180 days."
                )
            }
            if model.isUnavailable {
                Section {
                    Text("Pilot insights are unavailable. Your movies and preferences are unaffected.")
                    Button("Try again") { Task { await model.load() } }
                }
            } else if let summary = model.summary {
                metrics(summary)
                Section {
                    Button("Export local measurement") {
                        Task {
                            await model.prepareExport()
                            exportsFile = model.exportData != nil
                        }
                    }
                    Button("Delete measurement", role: .destructive) { confirmsDeletion = true }
                }
                .disabled(model.isBusy)
            }
            if model.isBusy { ProgressView() }
            if model.actionFailed {
                Text("The action could not be completed. Please try again.")
            }
        }
        .navigationTitle("Pilot insights")
        .task { await model.load() }
        .confirmationDialog(
            "Delete completed measurement?",
            isPresented: $confirmsDeletion,
            titleVisibility: .visible
        ) {
            Button("Delete measurement", role: .destructive) { Task { await model.delete() } }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("""
            Completed measurement will be deleted. Active sessions, pending confirmations, \
            PickOne badges, movies and preferences are preserved.
            """)
        }
        .fileExporter(
            isPresented: $exportsFile,
            document: PilotMeasurementDocument(data: model.exportData ?? Data()),
            contentType: .json,
            defaultFilename: "PickOne-pilot-insights"
        ) { result in
            if case .failure = result { model.exportFailed() }
            model.discardExport()
        }
        .onDisappear { model.discardExport() }
    }

    @ViewBuilder
    private func metrics(_ summary: PilotMeasurementSummary) -> some View {
        if summary.sessions == 0, summary.picks == 0, summary.searches == 0 {
            Text("No local measurement yet.")
        }
        Section("Decision funnel") {
            metric("Recommendation sessions", summary.sessions)
            metric("Sessions with a Pick", summary.sessionsWithPick)
            metric("Sessions confirmed watched", summary.sessionsConfirmedWatched)
            metric("Picks", summary.picks)
            metric("Confirmed watched", summary.confirmedWatched)
            value("Pick rate per session", percent(summary.pickRate))
            value("Confirmed watched per Pick", percent(summary.confirmationRate))
            metric("Pending Picks", summary.pending)
            metric("Replaced Picks", summary.superseded)
            metric("Cancelled Picks", summary.cancelled)
            metric("Not watched after all", summary.notWatched)
            metric("Postponements", summary.postponements)
        }
        Section("Viewing satisfaction") {
            metric("Love it", summary.loveIt)
            metric("Like it", summary.likeIt)
            metric("It was okay", summary.itWasOkay)
            metric("Didn't like it", summary.didNotLikeIt)
            metric("No reaction supplied", summary.satisfactionUnavailable)
        }
        Section("Foreground decision time") {
            value("Mean seconds to first Pick", number(summary.firstPickMeanSeconds))
            metric("First Pick timing samples", summary.firstPickSamples)
            value("Mean seconds to final Pick", number(summary.finalPickMeanSeconds))
            metric("Final Pick timing samples", summary.finalPickSamples)
            Text("Unavailable timing is excluded from averages.")
            metric("Observed Decision Sets", summary.observedSets)
            metric("Give me three more actions", summary.refreshes)
        }
        Section("Home recommendations") {
            metric("Sessions with observation evidence", summary.sessionsWithObservationEvidence)
            metric("Distinct movies observed per session", summary.observedMovies)
            metric("Already watched actions", summary.alreadyWatched)
            value("Already watched rate", percent(summary.alreadyWatchedRate))
            Text(
                "Movies count once per session. Earlier sessions without observation evidence are excluded from this rate."
            )
        }
        Section("Recommendation searches") {
            metric("Searches", summary.searches)
            metric("Expanded searches", summary.expandedSearches)
            metric("Usable results", summary.usableSearches)
            metric("Exhausted results", summary.exhaustedSearches)
            metric("Retryable failures", summary.failedSearches)
            value("Mean search seconds", number(summary.searchMeanSeconds))
            Text("Includes the latest 1,000 retained recommendation searches. Search text is never recorded.")
        }
    }

    private func metric(_ title: LocalizedStringKey, _ count: Int) -> some View {
        value(title, count.formatted())
    }

    private func value(_ title: LocalizedStringKey, _ text: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
            Text(text).foregroundStyle(.secondary)
        }
        .accessibilityElement(children: .combine)
    }

    private func number(_ value: Double?) -> String {
        value?.formatted(.number.precision(.fractionLength(1))) ?? String(localized: "Unavailable")
    }

    private func percent(_ value: Double?) -> String {
        value?.formatted(.percent.precision(.fractionLength(1))) ?? String(localized: "Unavailable")
    }
}

private struct PilotMeasurementDocument: FileDocument {
    static let readableContentTypes: [UTType] = [.json]
    let data: Data
    init(data: Data) {
        self.data = data
    }

    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents else { throw ViewingDecisionError.unavailable }
        self.data = data
    }

    func fileWrapper(configuration _: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}

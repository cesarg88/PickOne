import Foundation
import Observation

@MainActor
@Observable
final class PilotInsightsViewModel {
    private let repository: any PilotMeasurementRepository
    private let now: @Sendable () -> Date
    private var deletionID: UUID?
    private(set) var summary: PilotMeasurementSummary?
    private(set) var isBusy = false
    private(set) var isUnavailable = false
    private(set) var actionFailed = false
    private(set) var exportData: Data?

    init(repository: any PilotMeasurementRepository, now: @escaping @Sendable () -> Date = { Date() }) {
        self.repository = repository
        self.now = now
    }

    func load() async {
        guard !isBusy else { return }
        isBusy = true
        defer { isBusy = false }
        do {
            let value = try await repository.measurementSummary(at: now())
            try Task.checkCancellation()
            summary = value
            isUnavailable = false
        } catch is CancellationError {
            return
        } catch {
            summary = nil
            isUnavailable = true
        }
    }

    func prepareExport() async {
        guard !isBusy else { return }
        isBusy = true
        actionFailed = false
        exportData = nil
        defer { isBusy = false }
        do {
            let data = try await repository.exportMeasurement(at: now())
            try Task.checkCancellation()
            exportData = data
        } catch is CancellationError {
            return
        } catch { actionFailed = true }
    }

    func delete() async {
        guard !isBusy else { return }
        isBusy = true
        actionFailed = false
        exportData = nil
        let id = deletionID ?? UUID()
        deletionID = id
        do {
            try await repository.deleteMeasurement(operationID: id, at: now())
            deletionID = nil
            summary = nil
        } catch { actionFailed = true }
        isBusy = false
        await load()
    }

    func discardExport() {
        exportData = nil
    }

    func exportFailed() {
        actionFailed = true
    }
}

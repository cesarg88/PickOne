import Foundation
@testable import PickOne
import Synchronization

final class InMemoryViewerProfileDataStore: ViewerProfileDataStore {
    private struct State: Sendable {
        var data: Data?
        var rejectReads = false
        var rejectReplacements = false
        var replacementCount = 0
        var removalCount = 0
    }

    private let state: Mutex<State>

    init(data: Data? = nil) {
        state = Mutex(State(data: data))
    }

    var data: Data? {
        state.withLock { $0.data }
    }

    var replacementCount: Int {
        state.withLock { $0.replacementCount }
    }

    func setRejectReads(_ value: Bool) {
        state.withLock { $0.rejectReads = value }
    }

    func setRejectReplacements(_ value: Bool) {
        state.withLock { $0.rejectReplacements = value }
    }

    func read() throws -> Data? {
        try state.withLock { state in
            if state.rejectReads {
                throw TestViewerProfileStoreError.rejected
            }
            return state.data
        }
    }

    func replace(with data: Data) throws {
        try state.withLock { state in
            if state.rejectReplacements {
                throw TestViewerProfileStoreError.rejected
            }
            state.data = data
            state.replacementCount += 1
        }
    }

    func remove() throws {
        state.withLock { state in
            state.data = nil
            state.removalCount += 1
        }
    }
}

enum TestViewerProfileStoreError: Error {
    case rejected
}

struct ImmediateCalibrationCatalogResolver: ResolveCalibrationCatalogUseCase {
    let resolution: CalibrationCatalogResolution

    init(
        resolution: CalibrationCatalogResolution = CalibrationCatalogTestFixtures.resolution(
            source: .bundled
        )
    ) {
        self.resolution = resolution
    }

    func prefetch(region _: String, locale _: String) async {}

    func execute(
        region _: String,
        locale _: String,
        deadline _: Date
    ) async throws -> CalibrationCatalogResolution {
        resolution
    }
}

actor CalibrationCatalogResolverSpy: ResolveCalibrationCatalogUseCase {
    private let resolution: CalibrationCatalogResolution
    private var executeFailures: Int
    private(set) var prefetchCallCount = 0
    private(set) var resolveCallCount = 0
    private(set) var requestedDeadlines: [Date] = []

    init(
        resolution: CalibrationCatalogResolution = CalibrationCatalogTestFixtures.resolution(
            source: .bundled
        ),
        executeFailures: Int = 0
    ) {
        self.resolution = resolution
        self.executeFailures = executeFailures
    }

    func prefetch(region _: String, locale _: String) {
        prefetchCallCount += 1
    }

    func execute(
        region _: String,
        locale _: String,
        deadline: Date
    ) throws -> CalibrationCatalogResolution {
        resolveCallCount += 1
        requestedDeadlines.append(deadline)
        if executeFailures > 0 {
            executeFailures -= 1
            throw ViewerProfileViewModelTestError.failed
        }
        return resolution
    }
}

actor CancellableCalibrationCatalogResolver: ResolveCalibrationCatalogUseCase {
    private(set) var didStartResolving = false
    private(set) var wasCancelled = false

    func prefetch(region _: String, locale _: String) async {}

    func execute(
        region _: String,
        locale _: String,
        deadline _: Date
    ) async throws -> CalibrationCatalogResolution {
        didStartResolving = true
        do {
            try await Task.sleep(for: .seconds(60))
            return CalibrationCatalogTestFixtures.resolution(source: .bundled)
        } catch is CancellationError {
            wasCancelled = true
            throw CancellationError()
        }
    }
}

struct FailingViewerProfileEncoder: ViewerProfileEnvelopeCoding {
    private let decoder = JSONViewerProfileEnvelopeCoder()

    func decodeEnvelope(from data: Data) throws -> ViewerStateEnvelopeV1DTO {
        try decoder.decodeEnvelope(from: data)
    }

    func encodeEnvelope(_ envelope: ViewerStateEnvelopeV1DTO) throws -> Data {
        throw TestViewerProfileStoreError.rejected
    }
}

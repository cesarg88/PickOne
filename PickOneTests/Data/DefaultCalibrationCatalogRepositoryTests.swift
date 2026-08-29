import Foundation
@testable import PickOne
import Synchronization
import Testing

@Suite("Default calibration catalog repository")
struct DefaultCalibrationCatalogRepositoryTests {
    @Test("valid remote wins and replaces the explicit last-valid cache")
    func remoteWinsAndCaches() async throws {
        let remote = ControlledCalibrationCatalogRemoteSource()
        let cache = InMemoryCalibrationCatalogCacheStore()
        let sut = try makeSUT(remote: remote, cache: cache)
        let document = try CalibrationCatalogTestFixtures.document()
        let task = Task { try await resolve(sut) }
        await remote.waitUntilCallCount(1)

        await remote.complete(with: .success(document))
        let resolution = try await task.value

        #expect(resolution.source == .remote)
        #expect(resolution.remoteFailure == nil)
        #expect(!resolution.cacheWriteFailed)
        #expect(cache.writeCount == 1)
        #expect(cache.data == document.data)
    }

    @Test("cache wins after each classified remote failure")
    func cacheWinsAfterRemoteFailure() async throws {
        let cachedData = try CalibrationCatalogTestFixtures.documentData()

        for failure in [
            CalibrationCatalogRemoteFailure.absent,
            .invalid,
            .incompatible,
            .unavailable,
        ] {
            let cache = InMemoryCalibrationCatalogCacheStore(data: cachedData)
            let sut = try makeSUT(
                remote: FixedCalibrationCatalogRemoteSource(result: .failure(failure)),
                cache: cache
            )

            let resolution = try await resolve(sut)

            #expect(resolution.source == .cached)
            #expect(resolution.remoteFailure == failure)
            #expect(resolution.snapshot == CalibrationCatalogTestFixtures.snapshot())
        }
    }

    @Test("invalid cache is never admitted and bundled completes offline")
    func invalidCacheFallsBackToBundled() async throws {
        let cache = InMemoryCalibrationCatalogCacheStore(data: Data("{}".utf8))
        let sut = try makeSUT(
            remote: FixedCalibrationCatalogRemoteSource(result: .failure(.unavailable)),
            cache: cache
        )

        let resolution = try await resolve(sut)

        #expect(resolution.source == .bundled)
        #expect(resolution.remoteFailure == .unavailable)
        #expect(resolution.snapshot.catalog == .spainHouseholdV1)
        #expect(cache.data == Data("{}".utf8))
    }

    @Test("the injected absolute deadline selects fallback while remote continues")
    func deadlineSelectsFallbackWithoutCancellingRemote() async throws {
        let remote = ControlledCalibrationCatalogRemoteSource()
        let clock = RecordingImmediateCatalogClock()
        let deadline = Date(timeIntervalSince1970: 2000)
        let sut = try makeSUT(remote: remote, clock: clock)

        let resolution = try await sut.resolve(
            region: "ES",
            locale: "es-ES",
            deadline: deadline
        )

        #expect(resolution.source == .bundled)
        #expect(resolution.remoteFailure == .unavailable)
        #expect(await clock.deadlines == [deadline])
        #expect(await remote.callCount == 1)

        await remote.complete(with: .failure(.unavailable))
    }

    @Test("late remote result is cached and can affect only a later resolution")
    func lateRemoteAffectsNextResolutionOnly() async throws {
        let remote = ControlledCalibrationCatalogRemoteSource()
        let cache = InMemoryCalibrationCatalogCacheStore()
        let document = try CalibrationCatalogTestFixtures.document()
        let sut = try makeSUT(
            remote: remote,
            cache: cache,
            clock: RecordingImmediateCatalogClock()
        )

        let current = try await resolve(sut, deadline: .distantPast)
        #expect(current.source == .bundled)

        await remote.complete(with: .success(document))
        await waitUntil { cache.writeCount == 1 }
        #expect(current.source == .bundled)

        let next = try await resolve(sut)
        #expect(next.source == .remote)
        #expect(next.snapshot == CalibrationCatalogTestFixtures.snapshot())
    }

    @Test("concurrent callers share one in-flight prefetch")
    func concurrentCallersSharePrefetch() async throws {
        let remote = ControlledCalibrationCatalogRemoteSource()
        let sut = try makeSUT(remote: remote)
        let document = try CalibrationCatalogTestFixtures.document()

        await sut.prefetch(region: "ES", locale: "es-ES")
        let first = Task { try await resolve(sut) }
        let second = Task { try await resolve(sut) }
        await remote.waitUntilCallCount(1)
        #expect(await remote.callCount == 1)

        await remote.complete(with: .success(document))
        let resolutions = try await [first.value, second.value]

        #expect(resolutions.map(\.source) == [.remote, .remote])
        #expect(await remote.callCount == 1)
    }

    @Test("caller cancellation ends only its wait and shared prefetch still populates cache")
    func cancellationPreservesSharedPrefetch() async throws {
        let remote = ControlledCalibrationCatalogRemoteSource()
        let cache = InMemoryCalibrationCatalogCacheStore()
        let sut = try makeSUT(remote: remote, cache: cache)
        let document = try CalibrationCatalogTestFixtures.document()
        let task = Task { try await resolve(sut) }
        await remote.waitUntilCallCount(1)

        task.cancel()
        await #expect(throws: CancellationError.self) {
            try await task.value
        }
        #expect(await remote.callCount == 1)

        await remote.complete(with: .success(document))
        await waitUntil { cache.writeCount == 1 }
        #expect(cache.data == document.data)
    }

    @Test("cache write failure uses remote in memory and retains previous valid bytes")
    func cacheWriteFailureRetainsPrevious() async throws {
        let document = try CalibrationCatalogTestFixtures.document()
        let previous = document.data
        let cache = InMemoryCalibrationCatalogCacheStore(
            data: previous,
            failsWrites: true
        )
        let sut = try makeSUT(
            remote: FixedCalibrationCatalogRemoteSource(
                result: .success(document)
            ),
            cache: cache
        )

        let resolution = try await resolve(sut)

        #expect(resolution.source == .remote)
        #expect(resolution.cacheWriteFailed)
        #expect(cache.data == previous)
    }

    @Test("invalid bundled fallback is a blocking programmer error")
    func invalidBundledIsBlocking() async throws {
        let sut = DefaultCalibrationCatalogRepository(
            remote: FixedCalibrationCatalogRemoteSource(result: .failure(.unavailable)),
            cache: InMemoryCalibrationCatalogCacheStore(),
            bundled: FixedBundledCalibrationCatalogSource(data: Data("{}".utf8))
        )

        await #expect(throws: CalibrationCatalogResolutionError.invalidBundledCatalog) {
            try await resolve(sut)
        }
    }

    @Test("Caches store round trips one exact entry per region and locale")
    func cacheStoreRoundTrip() throws {
        let root = FileManager.default.temporaryDirectory.appending(
            path: UUID().uuidString,
            directoryHint: .isDirectory
        )
        defer { try? FileManager.default.removeItem(at: root) }
        let sut = try CachesCalibrationCatalogStore(directoryURL: root)
        let data = try CalibrationCatalogTestFixtures.documentData()

        #expect(try sut.read(region: "ES", locale: "es-ES") == nil)
        try sut.replace(data, region: "ES", locale: "es-ES")

        #expect(try sut.read(region: "ES", locale: "es-ES") == data)
        #expect(try sut.read(region: "US", locale: "en-US") == nil)
    }

    private func makeSUT(
        remote: any CalibrationCatalogRemoteSource,
        cache: InMemoryCalibrationCatalogCacheStore = InMemoryCalibrationCatalogCacheStore(),
        clock: any CalibrationCatalogClock = SystemCalibrationCatalogClock()
    ) throws -> DefaultCalibrationCatalogRepository {
        try DefaultCalibrationCatalogRepository(
            remote: remote,
            cache: cache,
            bundled: FixedBundledCalibrationCatalogSource(
                data: CalibrationCatalogTestFixtures.documentData()
            ),
            clock: clock
        )
    }

    private func resolve(
        _ repository: DefaultCalibrationCatalogRepository,
        deadline: Date = Date().addingTimeInterval(30)
    ) async throws -> CalibrationCatalogResolution {
        try await repository.resolve(
            region: "ES",
            locale: "es-ES",
            deadline: deadline
        )
    }

    private func waitUntil(_ condition: @escaping @Sendable () -> Bool) async {
        for _ in 0 ..< 100 where !condition() {
            await Task.yield()
        }
        #expect(condition())
    }
}

private actor ControlledCalibrationCatalogRemoteSource: CalibrationCatalogRemoteSource {
    private var continuations: [
        CheckedContinuation<CalibrationCatalogRemoteResult, Error>
    ] = []
    private(set) var callCount = 0

    func fetch(
        region _: String,
        locale _: String
    ) async throws -> CalibrationCatalogRemoteResult {
        callCount += 1
        return try await withCheckedThrowingContinuation { continuation in
            continuations.append(continuation)
        }
    }

    func waitUntilCallCount(_ expected: Int) async {
        while callCount < expected {
            await Task.yield()
        }
    }

    func complete(with result: CalibrationCatalogRemoteResult) {
        guard !continuations.isEmpty else { return }
        continuations.removeFirst().resume(returning: result)
    }
}

private struct FixedCalibrationCatalogRemoteSource: CalibrationCatalogRemoteSource {
    let result: CalibrationCatalogRemoteResult

    func fetch(
        region _: String,
        locale _: String
    ) async throws -> CalibrationCatalogRemoteResult {
        result
    }
}

private final class InMemoryCalibrationCatalogCacheStore: CalibrationCatalogCacheStore, Sendable {
    private struct State: Sendable {
        var data: Data?
        var failsWrites: Bool
        var writeCount = 0
    }

    private let state: Mutex<State>

    init(data: Data? = nil, failsWrites: Bool = false) {
        state = Mutex(State(data: data, failsWrites: failsWrites))
    }

    var data: Data? {
        state.withLock { $0.data }
    }

    var writeCount: Int {
        state.withLock { $0.writeCount }
    }

    func read(region _: String, locale _: String) throws -> Data? {
        data
    }

    func replace(_ data: Data, region _: String, locale _: String) throws {
        try state.withLock { state in
            guard !state.failsWrites else {
                throw CocoaError(.fileWriteUnknown)
            }
            state.data = data
            state.writeCount += 1
        }
    }
}

private struct FixedBundledCalibrationCatalogSource: BundledCalibrationCatalogSource {
    let data: Data

    func load() throws -> Data {
        data
    }
}

private actor RecordingImmediateCatalogClock: CalibrationCatalogClock {
    private(set) var deadlines: [Date] = []

    func sleep(until deadline: Date) {
        deadlines.append(deadline)
    }
}

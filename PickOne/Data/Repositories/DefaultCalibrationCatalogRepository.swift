import Foundation

protocol CalibrationCatalogClock: Sendable {
    func sleep(until deadline: Date) async throws
}

struct SystemCalibrationCatalogClock: CalibrationCatalogClock {
    func sleep(until deadline: Date) async throws {
        let interval = max(0, deadline.timeIntervalSinceNow)
        try await Task.sleep(for: .seconds(interval))
    }
}

actor DefaultCalibrationCatalogRepository: CalibrationCatalogRepository {
    private struct CatalogKey: Hashable, Sendable {
        let region: String
        let locale: String
    }

    private struct CompletedRemote: Sendable {
        let result: CalibrationCatalogRemoteResult
        let cacheWriteFailed: Bool
    }

    private struct Waiter {
        let key: CatalogKey
        let continuation: CheckedContinuation<RemoteWaitResult, Never>
        let timeoutTask: Task<Void, Never>
    }

    private enum RemoteWaitResult: Sendable {
        case completed(CompletedRemote)
        case timedOut
        case cancelled
    }

    private let remote: any CalibrationCatalogRemoteSource
    private let cache: any CalibrationCatalogCacheStore
    private let bundled: any BundledCalibrationCatalogSource
    private let decoder: CalibrationCatalogDocumentDecoder
    private let clock: any CalibrationCatalogClock

    private var inFlightIDs: [CatalogKey: UUID] = [:]
    private var completedRemote: [CatalogKey: CompletedRemote] = [:]
    private var waiters: [UUID: Waiter] = [:]

    init(
        remote: any CalibrationCatalogRemoteSource,
        cache: any CalibrationCatalogCacheStore,
        bundled: any BundledCalibrationCatalogSource,
        decoder: CalibrationCatalogDocumentDecoder = CalibrationCatalogDocumentDecoder(),
        clock: any CalibrationCatalogClock = SystemCalibrationCatalogClock()
    ) {
        self.remote = remote
        self.cache = cache
        self.bundled = bundled
        self.decoder = decoder
        self.clock = clock
    }

    func prefetch(region: String, locale: String) {
        let key = CatalogKey(region: region, locale: locale)
        guard inFlightIDs[key] == nil else { return }

        completedRemote[key] = nil
        startRemote(for: key)
    }

    func resolve(
        region: String,
        locale: String,
        deadline: Date
    ) async throws -> CalibrationCatalogResolution {
        try Task.checkCancellation()
        let key = CatalogKey(region: region, locale: locale)
        if inFlightIDs[key] == nil, completedRemote[key] == nil {
            startRemote(for: key)
        }

        let cached = loadCached(for: key)
        let remoteResult: RemoteWaitResult = if let completed = completedRemote[key] {
            .completed(completed)
        } else {
            await waitForRemote(key: key, deadline: deadline)
        }

        switch remoteResult {
            case let .completed(completed):
                switch completed.result {
                    case let .success(document):
                        return CalibrationCatalogResolution(
                            snapshot: document.snapshot,
                            source: .remote,
                            remoteFailure: nil,
                            cacheWriteFailed: completed.cacheWriteFailed
                        )
                    case let .failure(failure):
                        return try fallback(
                            cached: cached,
                            key: key,
                            remoteFailure: failure
                        )
                }
            case .timedOut:
                return try fallback(
                    cached: cached,
                    key: key,
                    remoteFailure: .unavailable
                )
            case .cancelled:
                throw CancellationError()
        }
    }

    private func startRemote(for key: CatalogKey) {
        let requestID = UUID()
        inFlightIDs[key] = requestID
        let remote = remote
        Task {
            let result: CalibrationCatalogRemoteResult
            do {
                result = try await remote.fetch(region: key.region, locale: key.locale)
            } catch {
                result = .failure(.unavailable)
            }
            remoteCompleted(result, for: key, requestID: requestID)
        }
    }

    private func remoteCompleted(
        _ result: CalibrationCatalogRemoteResult,
        for key: CatalogKey,
        requestID: UUID
    ) {
        guard inFlightIDs[key] == requestID else { return }
        inFlightIDs[key] = nil

        var cacheWriteFailed = false
        if case let .success(document) = result {
            do {
                try cache.replace(
                    document.data,
                    region: key.region,
                    locale: key.locale
                )
            } catch {
                cacheWriteFailed = true
            }
        }
        let completed = CompletedRemote(
            result: result,
            cacheWriteFailed: cacheWriteFailed
        )
        completedRemote[key] = completed

        let matchingIDs = waiters.compactMap { id, waiter in
            waiter.key == key ? id : nil
        }
        for id in matchingIDs {
            guard let waiter = waiters.removeValue(forKey: id) else { continue }
            waiter.timeoutTask.cancel()
            waiter.continuation.resume(returning: .completed(completed))
        }
    }

    private func waitForRemote(
        key: CatalogKey,
        deadline: Date
    ) async -> RemoteWaitResult {
        if let completed = completedRemote[key] {
            return .completed(completed)
        }

        let waiterID = UUID()
        return await withTaskCancellationHandler {
            await withCheckedContinuation { continuation in
                if Task.isCancelled {
                    continuation.resume(returning: .cancelled)
                    return
                }
                let clock = clock
                let timeoutTask = Task {
                    do {
                        try await clock.sleep(until: deadline)
                        deadlineReached(waiterID: waiterID)
                    } catch {
                        return
                    }
                }
                waiters[waiterID] = Waiter(
                    key: key,
                    continuation: continuation,
                    timeoutTask: timeoutTask
                )
            }
        } onCancel: {
            Task { await self.cancelWaiter(waiterID: waiterID) }
        }
    }

    private func deadlineReached(waiterID: UUID) {
        guard let waiter = waiters.removeValue(forKey: waiterID) else { return }
        waiter.continuation.resume(returning: .timedOut)
    }

    private func cancelWaiter(waiterID: UUID) {
        guard let waiter = waiters.removeValue(forKey: waiterID) else { return }
        waiter.timeoutTask.cancel()
        waiter.continuation.resume(returning: .cancelled)
    }

    private func loadCached(for key: CatalogKey) -> CalibrationCatalogDocument? {
        do {
            guard let data = try cache.read(region: key.region, locale: key.locale) else {
                return nil
            }
            return try decoder.decode(
                data,
                expectedRegion: key.region,
                expectedLocale: key.locale
            )
        } catch {
            return nil
        }
    }

    private func fallback(
        cached: CalibrationCatalogDocument?,
        key: CatalogKey,
        remoteFailure: CalibrationCatalogRemoteFailure
    ) throws -> CalibrationCatalogResolution {
        if let cached {
            return CalibrationCatalogResolution(
                snapshot: cached.snapshot,
                source: .cached,
                remoteFailure: remoteFailure,
                cacheWriteFailed: false
            )
        }

        let bundledDocument: CalibrationCatalogDocument
        do {
            bundledDocument = try decoder.decode(
                bundled.load(),
                expectedRegion: key.region,
                expectedLocale: key.locale
            )
        } catch {
            throw CalibrationCatalogResolutionError.invalidBundledCatalog
        }
        return CalibrationCatalogResolution(
            snapshot: bundledDocument.snapshot,
            source: .bundled,
            remoteFailure: remoteFailure,
            cacheWriteFailed: false
        )
    }
}

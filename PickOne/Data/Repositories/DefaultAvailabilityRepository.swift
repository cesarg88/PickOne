import Foundation

enum AvailabilityDataError: Error {
    case invalidMovieIdentity
}

actor DefaultAvailabilityRepository: AvailabilityRepository {
    private struct CacheKey: Hashable, Sendable {
        let movieID: Int
        let region: ViewingRegion
    }

    private struct InFlightRequest {
        let id: UUID
        let task: Task<VerifiedAvailabilityEvidence?, Error>
        var waiterIDs: Set<UUID>
    }

    private let client: MovieAvailabilityClient
    private let clock: AvailabilityClock
    private let freshnessInterval: TimeInterval
    private var cache: [CacheKey: VerifiedAvailabilityEvidence] = [:]
    private var inFlight: [CacheKey: InFlightRequest] = [:]

    init(
        client: MovieAvailabilityClient,
        clock: AvailabilityClock,
        freshnessInterval: TimeInterval = AvailabilityFreshness.interval
    ) {
        self.client = client
        self.clock = clock
        self.freshnessInterval = freshnessInterval
    }

    func getVerifiedEvidence(
        movieID: Int,
        region: ViewingRegion,
        policy: AvailabilityFetchPolicy
    ) async throws -> VerifiedAvailabilityEvidence? {
        let key = CacheKey(movieID: movieID, region: region)
        if
            policy == .useFreshCache,
            let cached = cache[key],
            cached.isFresh(
                at: clock.now(),
                freshnessInterval: freshnessInterval
            )
        {
            AvailabilityDiagnosticsContext.operation?.recordCacheHit()
            return cached
        }

        let waiterID = UUID()
        let requestID: UUID
        let request: Task<VerifiedAvailabilityEvidence?, Error>

        if var currentRequest = inFlight[key] {
            currentRequest.waiterIDs.insert(waiterID)
            inFlight[key] = currentRequest
            requestID = currentRequest.id
            request = currentRequest.task
        } else {
            let client = client
            let clock = clock
            let diagnostics = AvailabilityDiagnosticsContext.operation
            requestID = UUID()
            diagnostics?.networkRequestStarted()
            request = Task<VerifiedAvailabilityEvidence?, Error> {
                defer { diagnostics?.networkRequestFinished() }
                let response = try await client.getWatchProviders(
                    movieID: movieID
                )
                guard response.id == movieID else {
                    throw AvailabilityDataError.invalidMovieIdentity
                }
                guard let regionalEvidence = AvailabilityMapper.map(
                    response: response,
                    region: region
                ) else {
                    return nil
                }
                return VerifiedAvailabilityEvidence(
                    regionalEvidence: regionalEvidence,
                    verifiedAt: clock.now()
                )
            }
            inFlight[key] = InFlightRequest(
                id: requestID,
                task: request,
                waiterIDs: [waiterID]
            )
        }

        return try await withTaskCancellationHandler {
            do {
                let evidence = try await request.value
                try Task.checkCancellation()
                finishWaiter(
                    for: key,
                    requestID: requestID,
                    waiterID: waiterID,
                    evidence: evidence
                )
                return evidence
            } catch is CancellationError {
                cancelWaiter(
                    for: key,
                    requestID: requestID,
                    waiterID: waiterID
                )
                throw CancellationError()
            } catch {
                releaseWaiter(
                    for: key,
                    requestID: requestID,
                    waiterID: waiterID
                )
                throw error
            }
        } onCancel: {
            Task {
                await self.cancelWaiter(
                    for: key,
                    requestID: requestID,
                    waiterID: waiterID
                )
            }
        }
    }

    private func finishWaiter(
        for key: CacheKey,
        requestID: UUID,
        waiterID: UUID,
        evidence: VerifiedAvailabilityEvidence?
    ) {
        guard
            var currentRequest = inFlight[key],
            currentRequest.id == requestID
        else {
            return
        }

        if let evidence {
            cache[key] = evidence
        }
        currentRequest.waiterIDs.remove(waiterID)
        storeOrRemove(currentRequest, for: key)
    }

    private func releaseWaiter(
        for key: CacheKey,
        requestID: UUID,
        waiterID: UUID
    ) {
        guard
            var currentRequest = inFlight[key],
            currentRequest.id == requestID
        else {
            return
        }

        currentRequest.waiterIDs.remove(waiterID)
        storeOrRemove(currentRequest, for: key)
    }

    private func cancelWaiter(
        for key: CacheKey,
        requestID: UUID,
        waiterID: UUID
    ) {
        guard
            var currentRequest = inFlight[key],
            currentRequest.id == requestID,
            currentRequest.waiterIDs.remove(waiterID) != nil
        else {
            return
        }

        if currentRequest.waiterIDs.isEmpty {
            currentRequest.task.cancel()
            inFlight[key] = nil
        } else {
            inFlight[key] = currentRequest
        }
    }

    private func storeOrRemove(
        _ request: InFlightRequest,
        for key: CacheKey
    ) {
        if request.waiterIDs.isEmpty {
            inFlight[key] = nil
        } else {
            inFlight[key] = request
        }
    }

    #if DEBUG
        func activeWaiterCount(
            movieID: Int,
            region: ViewingRegion
        ) -> Int {
            inFlight[
                CacheKey(movieID: movieID, region: region)
            ]?.waiterIDs.count ?? 0
        }
    #endif
}

import Foundation

enum AvailabilityDataError: Error {
    case invalidMovieIdentity
}

actor DefaultAvailabilityRepository: AvailabilityRepository {
    private struct CacheKey: Hashable, Sendable {
        let movieID: Int
        let region: ViewingRegion
    }

    private let client: MovieAvailabilityClientProtocol
    private let clock: AvailabilityClock
    private let freshnessInterval: TimeInterval
    private var cache: [CacheKey: VerifiedAvailabilityEvidence] = [:]
    private var inFlight: [
        CacheKey: Task<VerifiedAvailabilityEvidence?, Error>
    ] = [:]

    init(
        client: MovieAvailabilityClientProtocol,
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
            return cached
        }

        if let currentRequest = inFlight[key] {
            return try await currentRequest.value
        }

        let client = self.client
        let clock = self.clock
        let request = Task<VerifiedAvailabilityEvidence?, Error> {
            let response = try await client.getWatchProviders(movieID: movieID)
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
        inFlight[key] = request

        return try await withTaskCancellationHandler {
            do {
                let evidence = try await request.value
                inFlight[key] = nil
                if let evidence {
                    cache[key] = evidence
                }
                return evidence
            } catch {
                inFlight[key] = nil
                throw error
            }
        } onCancel: {
            request.cancel()
        }
    }
}

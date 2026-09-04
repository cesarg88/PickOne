import Foundation

enum AvailabilityFetchPolicy: Equatable, Sendable {
    case useFreshCache
    case reloadIgnoringCache
}

protocol AvailabilityRepository: Sendable {
    func getVerifiedEvidence(
        movieID: Int,
        region: ViewingRegion,
        policy: AvailabilityFetchPolicy
    ) async throws -> VerifiedAvailabilityEvidence?
}

struct AvailabilityDiagnosticsCounters: Equatable, Sendable {
    let cacheHits: Int
    let networkRequests: Int
    let maximumSimultaneousNetworkRequests: Int
}

protocol AvailabilityDiagnosticsProviding: Sendable {
    func availabilityDiagnosticsCounters() async -> AvailabilityDiagnosticsCounters
}

protocol AvailabilityClock: Sendable {
    func now() -> Date
}

struct SystemAvailabilityClock: AvailabilityClock {
    func now() -> Date {
        Date()
    }
}

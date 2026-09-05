import Foundation
import Synchronization

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
    let checks: Int
    let cacheHits: Int
    let networkRequests: Int
    let maximumSimultaneousNetworkRequests: Int
}

final class AvailabilityOperationDiagnostics: Sendable {
    private struct State: Sendable {
        var checks = 0
        var cacheHits = 0
        var networkRequests = 0
        var activeNetworkRequests = 0
        var maximumSimultaneousNetworkRequests = 0
    }

    private let state = Mutex(State())

    func recordCheck() {
        state.withLock { $0.checks += 1 }
    }

    func recordCacheHit() {
        state.withLock { $0.cacheHits += 1 }
    }

    func networkRequestStarted() {
        state.withLock { state in
            state.networkRequests += 1
            state.activeNetworkRequests += 1
            state.maximumSimultaneousNetworkRequests = max(
                state.maximumSimultaneousNetworkRequests,
                state.activeNetworkRequests
            )
        }
    }

    func networkRequestFinished() {
        state.withLock { $0.activeNetworkRequests -= 1 }
    }

    var counters: AvailabilityDiagnosticsCounters {
        state.withLock {
            AvailabilityDiagnosticsCounters(
                checks: $0.checks,
                cacheHits: $0.cacheHits,
                networkRequests: $0.networkRequests,
                maximumSimultaneousNetworkRequests:
                $0.maximumSimultaneousNetworkRequests
            )
        }
    }
}

enum AvailabilityDiagnosticsContext {
    @TaskLocal static var operation: AvailabilityOperationDiagnostics?
}

protocol AvailabilityClock: Sendable {
    func now() -> Date
}

struct SystemAvailabilityClock: AvailabilityClock {
    func now() -> Date {
        Date()
    }
}

import Foundation
@testable import PickOne
import Synchronization
import Testing

@Suite("Dynamic viewing context tests")
struct DynamicViewingContextTests {
    @Test("completed profile is the only source of current viewing context")
    func currentContextRequiresProfile() async throws {
        let repository = DefaultViewerProfileRepository(
            store: InMemoryViewerProfileDataStore()
        )
        let sut = GetCurrentViewingContext(repository: repository)

        await #expect(throws: CurrentViewingContextError.unavailable) {
            try await sut.execute()
        }

        _ = try await ViewerProfileTestFixtures.completedProfile(
            in: repository,
            services: [.amazonPrimeVideo, .hboMax]
        )
        let context = try await sut.execute()
        #expect(context.region == .spain)
        #expect(context.selectedServices == [.amazonPrimeVideo, .hboMax])
    }

    @Test("availability resolves services per execution and reuses fresh regional evidence")
    func serviceEditReevaluatesFreshEvidence() async throws {
        let profileRepository = DefaultViewerProfileRepository(
            store: InMemoryViewerProfileDataStore()
        )
        _ = try await ViewerProfileTestFixtures.completedProfile(
            in: profileRepository,
            services: [.netflix]
        )
        let client = DynamicAvailabilityClient(providerIDs: [8, 337])
        let evidenceRepository = DefaultAvailabilityRepository(
            client: client,
            clock: LockedDynamicAvailabilityClock(now: AvailabilityTestFixtures.now)
        )
        let sut = CheckMovieAvailability(
            repository: evidenceRepository,
            getCurrentViewingContext: GetCurrentViewingContext(
                repository: profileRepository
            )
        )

        let first = try await sut.execute(movieID: 42)
        _ = try await profileRepository.updateServices([.disneyPlus])
        let second = try await sut.execute(movieID: 42)

        #expect(providerIDs(from: first) == [8])
        #expect(providerIDs(from: second) == [337])
        #expect(await client.callCount == 1)
    }

    @Test("stale handoff revalidation applies services selected at revalidation time")
    func handoffUsesCurrentServices() async throws {
        let profileRepository = DefaultViewerProfileRepository(
            store: InMemoryViewerProfileDataStore()
        )
        _ = try await ViewerProfileTestFixtures.completedProfile(
            in: profileRepository,
            services: [.netflix]
        )
        let clock = LockedDynamicAvailabilityClock(now: AvailabilityTestFixtures.now)
        let client = DynamicAvailabilityClient(providerIDs: [8])
        let evidenceRepository = DefaultAvailabilityRepository(client: client, clock: clock)
        let checker = CheckMovieAvailability(
            repository: evidenceRepository,
            getCurrentViewingContext: GetCurrentViewingContext(
                repository: profileRepository
            )
        )
        let initial = try await checker.execute(movieID: 42)
        _ = try await profileRepository.updateServices([.disneyPlus])
        clock.advance(by: AvailabilityFreshness.interval + 1)
        let sut = PreparePlaybackOptions(checkAvailability: checker, clock: clock)

        let result = try await sut.execute(movieID: 42, currentOutcome: initial)

        guard case let .updatedOutcome(outcome) = result else {
            Issue.record("Expected updated availability")
            return
        }
        guard case .ineligible = outcome else {
            Issue.record("Expected the newly selected service to make evidence ineligible")
            return
        }
        #expect(await client.callCount == 2)
    }

    @Test("missing profile is typed unknown and never all-services eligibility")
    func missingProfileFailsClosed() async throws {
        let profileRepository = DefaultViewerProfileRepository(
            store: InMemoryViewerProfileDataStore()
        )
        let client = DynamicAvailabilityClient(providerIDs: [8, 119, 337, 1899])
        let checker = CheckMovieAvailability(
            repository: DefaultAvailabilityRepository(
                client: client,
                clock: LockedDynamicAvailabilityClock(now: AvailabilityTestFixtures.now)
            ),
            getCurrentViewingContext: GetCurrentViewingContext(
                repository: profileRepository
            )
        )

        let outcome = try await checker.execute(movieID: 42)

        #expect(outcome == .unknown(reason: .viewingContextUnavailable))
        #expect(await client.callCount == 0)
    }

    private func providerIDs(from outcome: AvailabilityOutcome) -> [Int] {
        guard case let .eligible(providers, _) = outcome else { return [] }
        return providers.map(\.id)
    }
}

private final class LockedDynamicAvailabilityClock: AvailabilityClock {
    private let date: Mutex<Date>

    init(now: Date) {
        date = Mutex(now)
    }

    func now() -> Date {
        date.withLock { $0 }
    }

    func advance(by interval: TimeInterval) {
        date.withLock { $0 = $0.addingTimeInterval(interval) }
    }
}

private actor DynamicAvailabilityClient: MovieAvailabilityClient {
    private let providerIDs: [Int]
    private(set) var callCount = 0

    init(providerIDs: [Int]) {
        self.providerIDs = providerIDs
    }

    func getWatchProviders(movieID: Int) async throws -> WatchProvidersResponseDTO {
        callCount += 1
        return AvailabilityTestFixtures.responseDTO(
            movieID: movieID,
            results: [
                "ES": AvailabilityTestFixtures.regionDTO(
                    flatrate: providerIDs.map {
                        AvailabilityTestFixtures.providerDTO(id: $0)
                    }
                ),
            ]
        )
    }
}

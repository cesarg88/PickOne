import Foundation
@testable import PickOne
import Synchronization
import Testing

@Suite("AvailabilityRepository tests")
struct AvailabilityRepositoryTests {
    @Test(
        "cache freshness boundary is deterministic",
        arguments: [
            (AvailabilityFreshness.interval - 1, 1),
            (AvailabilityFreshness.interval, 1),
            (AvailabilityFreshness.interval + 1, 2),
        ]
    )
    func cacheFreshnessBoundary(
        ageAndExpectedCalls: (TimeInterval, Int)
    ) async throws {
        let (age, expectedCalls) = ageAndExpectedCalls
        let clock = LockedAvailabilityClock(
            now: AvailabilityTestFixtures.now
        )
        let client = MockMovieAvailabilityClient { movieID, callIndex in
            Self.response(
                movieID: movieID,
                providerID: callIndex == 0 ? 8 : 337
            )
        }
        let sut = DefaultAvailabilityRepository(
            client: client,
            clock: clock
        )

        _ = try await sut.getVerifiedEvidence(
            movieID: 42,
            region: .spain,
            policy: .useFreshCache
        )
        clock.advance(by: age)
        let result = try await sut.getVerifiedEvidence(
            movieID: 42,
            region: .spain,
            policy: .useFreshCache
        )

        #expect(await client.callCount == expectedCalls)
        let expectedProvider = expectedCalls == 1 ? 8 : 337
        #expect(
            result?.regionalEvidence.flatrate.first?.providerID
                == expectedProvider
        )
    }

    @Test("unknown regional evidence is not cached")
    func unknownIsNotCached() async throws {
        let client = MockMovieAvailabilityClient { movieID, _ in
            AvailabilityTestFixtures.responseDTO(
                movieID: movieID,
                results: ["FR": AvailabilityTestFixtures.regionDTO()]
            )
        }
        let sut = DefaultAvailabilityRepository(
            client: client,
            clock: LockedAvailabilityClock(
                now: AvailabilityTestFixtures.now
            )
        )

        let first = try await sut.getVerifiedEvidence(
            movieID: 42,
            region: .spain,
            policy: .useFreshCache
        )
        let second = try await sut.getVerifiedEvidence(
            movieID: 42,
            region: .spain,
            policy: .useFreshCache
        )

        #expect(first == nil)
        #expect(second == nil)
        #expect(await client.callCount == 2)
    }

    @Test("cache key isolates movie and region")
    func cacheKeyIsolation() async throws {
        let client = MockMovieAvailabilityClient { movieID, _ in
            AvailabilityTestFixtures.responseDTO(
                movieID: movieID,
                results: [
                    "ES": AvailabilityTestFixtures.regionDTO(
                        flatrate: [
                            AvailabilityTestFixtures.providerDTO(id: 8),
                        ]
                    ),
                    "FR": AvailabilityTestFixtures.regionDTO(
                        flatrate: [
                            AvailabilityTestFixtures.providerDTO(id: 337),
                        ]
                    ),
                ]
            )
        }
        let sut = DefaultAvailabilityRepository(
            client: client,
            clock: LockedAvailabilityClock(
                now: AvailabilityTestFixtures.now
            )
        )

        _ = try await sut.getVerifiedEvidence(
            movieID: 1,
            region: .spain,
            policy: .useFreshCache
        )
        _ = try await sut.getVerifiedEvidence(
            movieID: 1,
            region: ViewingRegion(code: "FR"),
            policy: .useFreshCache
        )
        _ = try await sut.getVerifiedEvidence(
            movieID: 2,
            region: .spain,
            policy: .useFreshCache
        )
        _ = try await sut.getVerifiedEvidence(
            movieID: 1,
            region: .spain,
            policy: .useFreshCache
        )

        #expect(await client.callCount == 3)
    }

    @Test("simultaneous requests share one in-flight source request")
    func inFlightRequestsAreDeduplicated() async throws {
        let client = MockMovieAvailabilityClient(
            yieldsBeforeResponse: 100
        ) { movieID, _ in
            Self.response(movieID: movieID, providerID: 8)
        }
        let sut = DefaultAvailabilityRepository(
            client: client,
            clock: LockedAvailabilityClock(
                now: AvailabilityTestFixtures.now
            )
        )

        async let first = sut.getVerifiedEvidence(
            movieID: 42,
            region: .spain,
            policy: .useFreshCache
        )
        async let second = sut.getVerifiedEvidence(
            movieID: 42,
            region: .spain,
            policy: .useFreshCache
        )
        let (firstResult, secondResult) = try await (first, second)

        #expect(firstResult == secondResult)
        #expect(await client.callCount == 1)
    }

    @Test("cancelling one waiter preserves the shared source request")
    func cancellingOneWaiterPreservesSharedRequest() async throws {
        let gate = AvailabilityRequestGate()
        let client = MockMovieAvailabilityClient(gate: gate) {
            movieID,
                _ in
            Self.response(movieID: movieID, providerID: 8)
        }
        let sut = DefaultAvailabilityRepository(
            client: client,
            clock: LockedAvailabilityClock(
                now: AvailabilityTestFixtures.now
            )
        )

        let first = Task {
            try await sut.getVerifiedEvidence(
                movieID: 42,
                region: .spain,
                policy: .useFreshCache
            )
        }
        while await client.callCount == 0 {
            await Task.yield()
        }

        let second = Task {
            try await sut.getVerifiedEvidence(
                movieID: 42,
                region: .spain,
                policy: .useFreshCache
            )
        }
        for _ in 0 ..< 1000 {
            guard await sut.activeWaiterCount(
                movieID: 42,
                region: .spain
            ) < 2 else {
                break
            }
            await Task.yield()
        }
        #expect(
            await sut.activeWaiterCount(
                movieID: 42,
                region: .spain
            ) == 2
        )

        first.cancel()
        for _ in 0 ..< 1000 {
            guard await sut.activeWaiterCount(
                movieID: 42,
                region: .spain
            ) > 1 else {
                break
            }
            await Task.yield()
        }
        #expect(
            await sut.activeWaiterCount(
                movieID: 42,
                region: .spain
            ) == 1
        )
        await gate.open()

        await #expect(throws: CancellationError.self) {
            try await first.value
        }
        let secondResult = try await second.value

        #expect(
            secondResult?.regionalEvidence.flatrate.first?.providerID == 8
        )
        #expect(await client.callCount == 1)
    }

    @Test("selected services reevaluate the same cached evidence")
    func selectedServicesAreNotPartOfCacheKey() async throws {
        let client = MockMovieAvailabilityClient { movieID, _ in
            Self.response(movieID: movieID, providerID: 8)
        }
        let repository = DefaultAvailabilityRepository(
            client: client,
            clock: LockedAvailabilityClock(
                now: AvailabilityTestFixtures.now
            )
        )
        let netflixChecker = CheckMovieAvailability(
            repository: repository,
            context: AvailabilityViewingContext(
                region: .spain,
                selectedServices: [.netflix]
            )
        )
        let disneyChecker = CheckMovieAvailability(
            repository: repository,
            context: AvailabilityViewingContext(
                region: .spain,
                selectedServices: [.disneyPlus]
            )
        )

        let netflix = try await netflixChecker.execute(movieID: 42)
        let disney = try await disneyChecker.execute(movieID: 42)

        guard case .eligible = netflix else {
            Issue.record("Expected Netflix eligibility")
            return
        }
        guard case .ineligible = disney else {
            Issue.record("Expected Disney ineligibility")
            return
        }
        #expect(await client.callCount == 1)
    }

    @Test("a new repository begins with an empty memory cache")
    func newRepositoryHasEmptyCache() async throws {
        let client = MockMovieAvailabilityClient { movieID, _ in
            Self.response(movieID: movieID, providerID: 8)
        }
        let clock = LockedAvailabilityClock(
            now: AvailabilityTestFixtures.now
        )

        let firstRepository = DefaultAvailabilityRepository(
            client: client,
            clock: clock
        )
        _ = try await firstRepository.getVerifiedEvidence(
            movieID: 42,
            region: .spain,
            policy: .useFreshCache
        )
        let secondRepository = DefaultAvailabilityRepository(
            client: client,
            clock: clock
        )
        _ = try await secondRepository.getVerifiedEvidence(
            movieID: 42,
            region: .spain,
            policy: .useFreshCache
        )

        #expect(await client.callCount == 2)
    }

    private static func response(
        movieID: Int,
        providerID: Int
    ) -> WatchProvidersResponseDTO {
        AvailabilityTestFixtures.responseDTO(
            movieID: movieID,
            results: [
                "ES": AvailabilityTestFixtures.regionDTO(
                    flatrate: [
                        AvailabilityTestFixtures.providerDTO(id: providerID),
                    ]
                ),
            ]
        )
    }
}

private final class LockedAvailabilityClock: AvailabilityClock, Sendable {
    private let date: Mutex<Date>

    init(now: Date) {
        date = Mutex(now)
    }

    func now() -> Date {
        date.withLock { $0 }
    }

    func advance(by interval: TimeInterval) {
        date.withLock {
            $0 = $0.addingTimeInterval(interval)
        }
    }
}

private actor MockMovieAvailabilityClient: MovieAvailabilityClient {
    typealias Handler = @Sendable (
        _ movieID: Int,
        _ callIndex: Int
    ) throws -> WatchProvidersResponseDTO

    private let yieldsBeforeResponse: Int
    private let gate: AvailabilityRequestGate?
    private let handler: Handler
    private(set) var callCount = 0

    init(
        yieldsBeforeResponse: Int = 0,
        gate: AvailabilityRequestGate? = nil,
        handler: @escaping Handler
    ) {
        self.yieldsBeforeResponse = yieldsBeforeResponse
        self.gate = gate
        self.handler = handler
    }

    func getWatchProviders(
        movieID: Int
    ) async throws -> WatchProvidersResponseDTO {
        let index = callCount
        callCount += 1
        for _ in 0 ..< yieldsBeforeResponse {
            await Task.yield()
        }
        if let gate {
            await gate.wait()
        }
        try Task.checkCancellation()
        return try handler(movieID, index)
    }
}

private actor AvailabilityRequestGate {
    private var isOpen = false
    private var continuations: [CheckedContinuation<Void, Never>] = []

    func wait() async {
        guard !isOpen else {
            return
        }

        await withCheckedContinuation {
            continuations.append($0)
        }
    }

    func open() {
        isOpen = true
        for continuation in continuations {
            continuation.resume()
        }
        continuations.removeAll()
    }
}

import Foundation
@testable import PickOne
import Testing

@Suite("PreparePlaybackOptions tests")
struct PreparePlaybackOptionsTests {
    @Test(
        "fresh evidence opens without revalidation",
        arguments: [
            AvailabilityFreshness.interval - 1,
            AvailabilityFreshness.interval,
        ]
    )
    func freshEvidenceOpens(age: TimeInterval) async throws {
        let clock = FixedAvailabilityClock(now: AvailabilityTestFixtures.now)
        let checker = MockAvailabilityChecker()
        let sut = PreparePlaybackOptions(
            checkAvailability: checker,
            clock: clock
        )
        let outcome = eligibleOutcome(
            verifiedAt: AvailabilityTestFixtures.now.addingTimeInterval(-age)
        )

        let result = try await sut.execute(
            movieID: 42,
            currentOutcome: outcome
        )

        #expect(
            try result == .open(#require(URL(string: AvailabilityTestFixtures.tmdbURL)))
        )
        #expect(await checker.callCount == 0)
    }

    @Test("stale evidence opens only the newly verified URL")
    func staleEvidenceUsesNewURL() async throws {
        let newURL = "https://www.themoviedb.org/movie/42/watch?locale=ES&new=1"
        let refreshed = eligibleOutcome(
            verifiedAt: AvailabilityTestFixtures.now,
            watchURL: newURL
        )
        let checker = MockAvailabilityChecker(outcomes: [refreshed])
        let sut = PreparePlaybackOptions(
            checkAvailability: checker,
            clock: FixedAvailabilityClock(
                now: AvailabilityTestFixtures.now
            )
        )
        let stale = eligibleOutcome(
            verifiedAt: AvailabilityTestFixtures.now.addingTimeInterval(
                -AvailabilityFreshness.interval - 1
            )
        )

        let result = try await sut.execute(
            movieID: 42,
            currentOutcome: stale
        )

        #expect(try result == .open(#require(URL(string: newURL))))
        #expect(await checker.policies == [.reloadIgnoringCache])
    }

    @Test("stale provider disappearance publishes ineligible")
    func staleBecomesIneligible() async throws {
        let evidence = AvailabilityTestFixtures.verifiedEvidence()
        let updated = AvailabilityOutcome.ineligible(evidence: evidence)
        let checker = MockAvailabilityChecker(outcomes: [updated])
        let sut = makeSUT(checker: checker)

        let result = try await sut.execute(
            movieID: 42,
            currentOutcome: staleEligibleOutcome()
        )

        #expect(result == .updatedOutcome(updated))
    }

    @Test("stale verification failure publishes unknown")
    func staleBecomesUnknown() async throws {
        let updated = AvailabilityOutcome.unknown(
            reason: .verificationFailed
        )
        let checker = MockAvailabilityChecker(outcomes: [updated])
        let sut = makeSUT(checker: checker)

        let result = try await sut.execute(
            movieID: 42,
            currentOutcome: staleEligibleOutcome()
        )

        #expect(result == .updatedOutcome(updated))
    }

    @Test(
        "invalid or absent URL never opens",
        arguments: [
            nil,
            "http://www.themoviedb.org/movie/42/watch",
            "https://example.com/movie/42/watch",
        ] as [String?]
    )
    func invalidURLIsUnavailable(watchURL: String?) async throws {
        let checker = MockAvailabilityChecker()
        let sut = makeSUT(checker: checker)
        let outcome = eligibleOutcome(
            verifiedAt: AvailabilityTestFixtures.now,
            watchURL: watchURL
        )

        let result = try await sut.execute(
            movieID: 42,
            currentOutcome: outcome
        )

        #expect(result == .unavailable)
    }

    @Test("revalidation cancellation propagates")
    func cancellationPropagates() async {
        let checker = MockAvailabilityChecker(throwsCancellation: true)
        let sut = makeSUT(checker: checker)

        await #expect(throws: CancellationError.self) {
            try await sut.execute(
                movieID: 42,
                currentOutcome: staleEligibleOutcome()
            )
        }
    }

    private func makeSUT(
        checker: MockAvailabilityChecker
    ) -> PreparePlaybackOptions {
        PreparePlaybackOptions(
            checkAvailability: checker,
            clock: FixedAvailabilityClock(
                now: AvailabilityTestFixtures.now
            )
        )
    }

    private func staleEligibleOutcome() -> AvailabilityOutcome {
        eligibleOutcome(
            verifiedAt: AvailabilityTestFixtures.now.addingTimeInterval(
                -AvailabilityFreshness.interval - 1
            )
        )
    }

    private func eligibleOutcome(
        verifiedAt: Date,
        watchURL: String? = AvailabilityTestFixtures.tmdbURL
    ) -> AvailabilityOutcome {
        let evidence = AvailabilityTestFixtures.verifiedEvidence(
            verifiedAt: verifiedAt,
            watchURL: watchURL,
            flatrate: [AvailabilityTestFixtures.offer(id: 8)]
        )
        return .eligible(
            providers: [
                EligibleStreamingProvider(
                    id: 8,
                    name: "Netflix",
                    logoPath: "/netflix.png",
                    productOrder: 1
                ),
            ],
            evidence: evidence
        )
    }
}

private struct FixedAvailabilityClock: AvailabilityClock {
    let currentDate: Date

    init(now: Date) {
        currentDate = now
    }

    func now() -> Date {
        currentDate
    }
}

private actor MockAvailabilityChecker: CheckMovieAvailabilityUseCase {
    private let outcomes: [AvailabilityOutcome]
    private let throwsCancellation: Bool
    private var index = 0
    private(set) var policies: [AvailabilityFetchPolicy] = []

    var callCount: Int {
        policies.count
    }

    init(
        outcomes: [AvailabilityOutcome] = [],
        throwsCancellation: Bool = false
    ) {
        self.outcomes = outcomes
        self.throwsCancellation = throwsCancellation
    }

    func execute(
        movieID: Int,
        policy: AvailabilityFetchPolicy
    ) async throws -> AvailabilityOutcome {
        policies.append(policy)
        if throwsCancellation {
            throw CancellationError()
        }
        defer { index += 1 }
        return outcomes[index]
    }
}

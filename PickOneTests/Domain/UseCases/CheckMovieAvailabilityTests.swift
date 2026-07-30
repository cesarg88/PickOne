import Foundation
import Testing
@testable import PickOne

@Suite("CheckMovieAvailability tests")
struct CheckMovieAvailabilityTests {
    @Test("exact selected flatrate provider is eligible")
    func exactFlatrateMatchIsEligible() async throws {
        let evidence = AvailabilityTestFixtures.verifiedEvidence(
            flatrate: [AvailabilityTestFixtures.offer(id: 8)]
        )
        let sut = makeSUT(evidence: evidence)

        let outcome = try await sut.execute(movieID: 42)

        guard case .eligible(let providers, _) = outcome else {
            Issue.record("Expected eligible")
            return
        }
        #expect(providers.map(\.id) == [8])
        #expect(providers.first?.name == "Netflix")
    }

    @Test("returns every match in product order and deduplicates IDs")
    func ordersAndDeduplicatesProviders() async throws {
        let evidence = AvailabilityTestFixtures.verifiedEvidence(
            flatrate: [
                AvailabilityTestFixtures.offer(id: 1899, name: "Source Max"),
                AvailabilityTestFixtures.offer(id: 8, name: "Source Netflix"),
                AvailabilityTestFixtures.offer(id: 119),
                AvailabilityTestFixtures.offer(id: 8, logoPath: "/duplicate.png"),
                AvailabilityTestFixtures.offer(id: 337)
            ]
        )
        let sut = makeSUT(evidence: evidence)

        let outcome = try await sut.execute(movieID: 42)

        guard case .eligible(let providers, _) = outcome else {
            Issue.record("Expected eligible")
            return
        }
        #expect(providers.map(\.id) == [8, 119, 337, 1899])
        #expect(
            providers.map(\.name)
                == ["Netflix", "Amazon Prime Video", "Disney Plus", "HBO Max"]
        )
    }

    @Test("other monetization categories never prove eligibility")
    func otherCategoriesAreIneligible() async throws {
        let regional = AvailabilityTestFixtures.regionalEvidence(
            rent: [AvailabilityTestFixtures.offer(id: 8)],
            buy: [AvailabilityTestFixtures.offer(id: 119)],
            ads: [AvailabilityTestFixtures.offer(id: 337)],
            free: [AvailabilityTestFixtures.offer(id: 1899)]
        )
        let evidence = VerifiedAvailabilityEvidence(
            regionalEvidence: regional,
            verifiedAt: AvailabilityTestFixtures.now
        )
        let sut = makeSUT(evidence: evidence)

        let outcome = try await sut.execute(movieID: 42)

        guard case .ineligible = outcome else {
            Issue.record("Expected ineligible")
            return
        }
    }

    @Test("flatrate remains eligible when also present in another category")
    func flatrateWinsOverOtherCategory() async throws {
        let offer = AvailabilityTestFixtures.offer(id: 8)
        let evidence = VerifiedAvailabilityEvidence(
            regionalEvidence: AvailabilityTestFixtures.regionalEvidence(
                flatrate: [offer],
                rent: [offer]
            ),
            verifiedAt: AvailabilityTestFixtures.now
        )
        let sut = makeSUT(evidence: evidence)

        let outcome = try await sut.execute(movieID: 42)

        guard case .eligible = outcome else {
            Issue.record("Expected eligible")
            return
        }
    }

    @Test("unselected and non-allowlisted providers are ineligible")
    func unselectedAndNonAllowlistedAreIneligible() async throws {
        let evidence = AvailabilityTestFixtures.verifiedEvidence(
            flatrate: [
                AvailabilityTestFixtures.offer(id: 337),
                AvailabilityTestFixtures.offer(id: 999)
            ]
        )
        let context = AvailabilityViewingContext(
            region: .spain,
            selectedServices: [
                .netflix,
                PilotStreamingService(
                    providerID: 999,
                    name: "Unsupported",
                    productOrder: 0
                )
            ]
        )
        let sut = makeSUT(evidence: evidence, context: context)

        let outcome = try await sut.execute(movieID: 42)

        guard case .ineligible = outcome else {
            Issue.record("Expected ineligible")
            return
        }
    }

    @Test("missing regional evidence is unknown and fails closed")
    func missingEvidenceIsUnknown() async throws {
        let sut = makeSUT(evidence: nil)

        let outcome = try await sut.execute(movieID: 42)

        #expect(
            outcome == .unknown(reason: .regionalEvidenceMissing)
        )
        #expect(outcome.isEligibleForRecommendation == false)
    }

    @Test("repository failure is unknown")
    func failureIsUnknown() async throws {
        let repository = MockAvailabilityRepository(mode: .failure)
        let sut = CheckMovieAvailability(
            repository: repository,
            context: .spainPilot
        )

        let outcome = try await sut.execute(movieID: 42)

        #expect(outcome == .unknown(reason: .verificationFailed))
    }

    @Test("cancellation propagates")
    func cancellationPropagates() async {
        let repository = MockAvailabilityRepository(mode: .cancelled)
        let sut = CheckMovieAvailability(
            repository: repository,
            context: .spainPilot
        )

        await #expect(throws: CancellationError.self) {
            try await sut.execute(movieID: 42)
        }
    }

    private func makeSUT(
        evidence: VerifiedAvailabilityEvidence?,
        context: AvailabilityViewingContext = .spainPilot
    ) -> CheckMovieAvailability {
        CheckMovieAvailability(
            repository: MockAvailabilityRepository(
                mode: .evidence(evidence)
            ),
            context: context
        )
    }
}

private actor MockAvailabilityRepository: AvailabilityRepository {
    enum Mode: Sendable {
        case evidence(VerifiedAvailabilityEvidence?)
        case failure
        case cancelled
    }

    private let mode: Mode

    init(mode: Mode) {
        self.mode = mode
    }

    func getVerifiedEvidence(
        movieID: Int,
        region: ViewingRegion,
        policy: AvailabilityFetchPolicy
    ) async throws -> VerifiedAvailabilityEvidence? {
        switch mode {
        case .evidence(let evidence):
            evidence
        case .failure:
            throw TestAvailabilityError.failed
        case .cancelled:
            throw CancellationError()
        }
    }
}

private enum TestAvailabilityError: Error {
    case failed
}

import Foundation

protocol CheckMovieAvailabilityUseCase: Sendable {
    func execute(
        movieID: Int,
        policy: AvailabilityFetchPolicy
    ) async throws -> AvailabilityOutcome
}

struct CheckMovieAvailability: CheckMovieAvailabilityUseCase {
    private let repository: AvailabilityRepository
    private let context: AvailabilityViewingContext

    init(
        repository: AvailabilityRepository,
        context: AvailabilityViewingContext
    ) {
        self.repository = repository
        self.context = context
    }

    func execute(
        movieID: Int,
        policy: AvailabilityFetchPolicy = .useFreshCache
    ) async throws -> AvailabilityOutcome {
        do {
            guard let evidence = try await repository.getVerifiedEvidence(
                movieID: movieID,
                region: context.region,
                policy: policy
            ) else {
                return .unknown(reason: .regionalEvidenceMissing)
            }
            return evaluate(evidence)
        } catch is CancellationError {
            throw CancellationError()
        } catch {
            return .unknown(reason: .verificationFailed)
        }
    }

    private func evaluate(
        _ evidence: VerifiedAvailabilityEvidence
    ) -> AvailabilityOutcome {
        let selectedIDs = Set(context.selectedServices.map(\.providerID))
        let allowlistedByID = Dictionary(
            uniqueKeysWithValues: PilotStreamingService.allowlist.map {
                ($0.providerID, $0)
            }
        )
        var matchedIDs = Set<Int>()
        var providers: [EligibleStreamingProvider] = []

        for offer in evidence.regionalEvidence.flatrate {
            guard
                selectedIDs.contains(offer.providerID),
                let service = allowlistedByID[offer.providerID],
                matchedIDs.insert(offer.providerID).inserted
            else {
                continue
            }
            providers.append(
                EligibleStreamingProvider(
                    id: service.providerID,
                    name: service.name,
                    logoPath: offer.logoPath,
                    productOrder: service.productOrder
                )
            )
        }

        providers.sort { $0.productOrder < $1.productOrder }

        if providers.isEmpty {
            return .ineligible(evidence: evidence)
        }
        return .eligible(providers: providers, evidence: evidence)
    }
}

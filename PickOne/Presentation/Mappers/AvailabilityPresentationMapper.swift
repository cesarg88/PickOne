import Foundation

@MainActor
enum AvailabilityPresentationMapper {
    static func map(
        outcome: AvailabilityOutcome
    ) -> MovieAvailabilityViewState {
        switch outcome {
            case let .eligible(providers, evidence):
                .eligible(
                    EligibleAvailabilityPresentationModel(
                        providers: providers.map {
                            AvailabilityProviderPresentationModel(
                                id: $0.id,
                                name: $0.name,
                                logoURL: ImageURLBuilder.providerLogoURL(
                                    path: $0.logoPath
                                )
                            )
                        },
                        showsPlaybackOptionsAction:
                        evidence.validTMDBWatchURL != nil
                    )
                )
            case .ineligible:
                .ineligible
            case .unknown:
                .unknown
        }
    }
}

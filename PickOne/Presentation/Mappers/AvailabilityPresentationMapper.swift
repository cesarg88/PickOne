import Foundation

@MainActor
enum AvailabilityPresentationMapper {
    static func map(
        outcome: AvailabilityOutcome
    ) -> MovieAvailabilityViewState {
        switch outcome {
        case .eligible(let providers, let evidence):
            return .eligible(
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
            return .ineligible
        case .unknown:
            return .unknown
        }
    }
}

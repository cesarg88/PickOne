import Foundation

enum AvailabilityMapper {
    static func map(
        response: WatchProvidersResponseDTO,
        region: ViewingRegion
    ) -> RegionalAvailabilityEvidence? {
        guard let regionDTO = response.results[region.code] else {
            return nil
        }

        return RegionalAvailabilityEvidence(
            movieID: response.id,
            region: region,
            watchURL: regionDTO.link,
            flatrate: map(regionDTO.flatrate),
            rent: map(regionDTO.rent),
            buy: map(regionDTO.buy),
            ads: map(regionDTO.ads),
            free: map(regionDTO.free)
        )
    }

    private static func map(
        _ providers: [WatchProviderDTO]?
    ) -> [ProviderOfferEvidence] {
        (providers ?? []).map {
            ProviderOfferEvidence(
                providerID: $0.providerId,
                sourceName: $0.providerName,
                logoPath: $0.logoPath
            )
        }
    }
}

import Foundation
@testable import PickOne

enum AvailabilityTestFixtures {
    static let now = Date(timeIntervalSince1970: 1_800_000_000)
    static let tmdbURL = "https://www.themoviedb.org/movie/42/watch?locale=ES"

    static func offer(
        id: Int,
        name: String = "Source provider",
        logoPath: String? = "/logo.png"
    ) -> ProviderOfferEvidence {
        ProviderOfferEvidence(
            providerID: id,
            sourceName: name,
            logoPath: logoPath
        )
    }

    static func regionalEvidence(
        movieID: Int = 42,
        region: ViewingRegion = .spain,
        watchURL: String? = tmdbURL,
        flatrate: [ProviderOfferEvidence] = [],
        rent: [ProviderOfferEvidence] = [],
        buy: [ProviderOfferEvidence] = [],
        ads: [ProviderOfferEvidence] = [],
        free: [ProviderOfferEvidence] = []
    ) -> RegionalAvailabilityEvidence {
        RegionalAvailabilityEvidence(
            movieID: movieID,
            region: region,
            watchURL: watchURL,
            flatrate: flatrate,
            rent: rent,
            buy: buy,
            ads: ads,
            free: free
        )
    }

    static func verifiedEvidence(
        movieID: Int = 42,
        verifiedAt: Date = now,
        watchURL: String? = tmdbURL,
        flatrate: [ProviderOfferEvidence] = []
    ) -> VerifiedAvailabilityEvidence {
        VerifiedAvailabilityEvidence(
            regionalEvidence: regionalEvidence(
                movieID: movieID,
                watchURL: watchURL,
                flatrate: flatrate
            ),
            verifiedAt: verifiedAt
        )
    }

    static func providerDTO(
        id: Int,
        name: String = "Provider",
        logoPath: String? = "/logo.png"
    ) -> WatchProviderDTO {
        WatchProviderDTO(
            providerId: id,
            providerName: name,
            logoPath: logoPath
        )
    }

    static func responseDTO(
        movieID: Int = 42,
        results: [String: WatchProviderRegionDTO]
    ) -> WatchProvidersResponseDTO {
        WatchProvidersResponseDTO(id: movieID, results: results)
    }

    static func regionDTO(
        link: String? = tmdbURL,
        flatrate: [WatchProviderDTO]? = nil,
        rent: [WatchProviderDTO]? = nil,
        buy: [WatchProviderDTO]? = nil,
        ads: [WatchProviderDTO]? = nil,
        free: [WatchProviderDTO]? = nil
    ) -> WatchProviderRegionDTO {
        WatchProviderRegionDTO(
            link: link,
            flatrate: flatrate,
            rent: rent,
            buy: buy,
            ads: ads,
            free: free
        )
    }
}

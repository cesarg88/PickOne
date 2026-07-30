import Foundation

struct WatchProvidersResponseDTO: Decodable, Sendable {
    let id: Int
    let results: [String: WatchProviderRegionDTO]
}

struct WatchProviderRegionDTO: Decodable, Sendable {
    let link: String?
    let flatrate: [WatchProviderDTO]?
    let rent: [WatchProviderDTO]?
    let buy: [WatchProviderDTO]?
    let ads: [WatchProviderDTO]?
    let free: [WatchProviderDTO]?
}

struct WatchProviderDTO: Decodable, Sendable {
    let providerId: Int
    let providerName: String
    let logoPath: String?
}

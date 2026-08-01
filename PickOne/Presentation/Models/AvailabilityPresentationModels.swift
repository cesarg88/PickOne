import Foundation

struct AvailabilityProviderPresentationModel: Identifiable, Equatable {
    let id: Int
    let name: String
    let logoURL: URL?
}

struct EligibleAvailabilityPresentationModel: Equatable {
    let providers: [AvailabilityProviderPresentationModel]
    let showsPlaybackOptionsAction: Bool
}

enum MovieAvailabilityViewState: Equatable {
    case loading
    case eligible(EligibleAvailabilityPresentationModel)
    case ineligible
    case unknown

    static let title = "Available on"
    static let ineligibleMessage = "Not shown as included with your services."
    static let unknownMessage = "We couldn't verify availability."
    static let attribution = "Availability data from JustWatch · may change"
    static let handoffTitle = "View playback options on TMDB"
}

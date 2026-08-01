import Foundation

struct ViewingRegion: Hashable, Sendable {
    let code: String

    init(code: String) {
        self.code = code.uppercased()
    }

    static let spain = ViewingRegion(code: "ES")
}

struct PilotStreamingService: Hashable, Sendable {
    let providerID: Int
    let name: String
    let productOrder: Int

    static let netflix = PilotStreamingService(
        providerID: 8,
        name: "Netflix",
        productOrder: 1
    )
    static let amazonPrimeVideo = PilotStreamingService(
        providerID: 119,
        name: "Amazon Prime Video",
        productOrder: 2
    )
    static let disneyPlus = PilotStreamingService(
        providerID: 337,
        name: "Disney Plus",
        productOrder: 3
    )
    static let hboMax = PilotStreamingService(
        providerID: 1899,
        name: "HBO Max",
        productOrder: 4
    )

    static let allowlist = [
        netflix,
        amazonPrimeVideo,
        disneyPlus,
        hboMax,
    ]
}

struct AvailabilityViewingContext: Equatable, Sendable {
    let region: ViewingRegion
    let selectedServices: [PilotStreamingService]

    static let spainPilot = AvailabilityViewingContext(
        region: .spain,
        selectedServices: PilotStreamingService.allowlist
    )
}

enum AvailabilityMonetizationType: Sendable {
    case flatrate
    case rent
    case buy
    case ads
    case free
}

struct ProviderOfferEvidence: Equatable, Sendable {
    let providerID: Int
    let sourceName: String
    let logoPath: String?
}

struct RegionalAvailabilityEvidence: Equatable, Sendable {
    let movieID: Int
    let region: ViewingRegion
    let watchURL: String?
    let flatrate: [ProviderOfferEvidence]
    let rent: [ProviderOfferEvidence]
    let buy: [ProviderOfferEvidence]
    let ads: [ProviderOfferEvidence]
    let free: [ProviderOfferEvidence]

    func offers(for type: AvailabilityMonetizationType) -> [ProviderOfferEvidence] {
        switch type {
            case .flatrate:
                flatrate
            case .rent:
                rent
            case .buy:
                buy
            case .ads:
                ads
            case .free:
                free
        }
    }
}

struct VerifiedAvailabilityEvidence: Equatable, Sendable {
    let regionalEvidence: RegionalAvailabilityEvidence
    let verifiedAt: Date

    func isFresh(
        at date: Date,
        freshnessInterval: TimeInterval = AvailabilityFreshness.interval
    ) -> Bool {
        date.timeIntervalSince(verifiedAt) <= freshnessInterval
    }

    var validTMDBWatchURL: URL? {
        guard
            let rawURL = regionalEvidence.watchURL,
            let url = URL(string: rawURL),
            url.scheme?.lowercased() == "https",
            let host = url.host?.lowercased(),
            host == "www.themoviedb.org" || host == "themoviedb.org"
        else {
            return nil
        }
        return url
    }
}

struct EligibleStreamingProvider: Identifiable, Equatable, Sendable {
    let id: Int
    let name: String
    let logoPath: String?
    let productOrder: Int
}

enum AvailabilityUnknownReason: Equatable, Sendable {
    case regionalEvidenceMissing
    case verificationFailed
}

enum AvailabilityOutcome: Equatable, Sendable {
    case eligible(
        providers: [EligibleStreamingProvider],
        evidence: VerifiedAvailabilityEvidence
    )
    case ineligible(evidence: VerifiedAvailabilityEvidence)
    case unknown(reason: AvailabilityUnknownReason)

    var isEligibleForRecommendation: Bool {
        if case .eligible = self {
            return true
        }
        return false
    }

    var evidence: VerifiedAvailabilityEvidence? {
        switch self {
            case let .eligible(_, evidence), let .ineligible(evidence):
                evidence
            case .unknown:
                nil
        }
    }
}

enum AvailabilityFreshness {
    static let interval: TimeInterval = 24 * 60 * 60
}

enum PlaybackOptionsPreparation: Equatable, Sendable {
    case open(URL)
    case updatedOutcome(AvailabilityOutcome)
    case unavailable
}

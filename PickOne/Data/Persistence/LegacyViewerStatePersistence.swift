import Foundation

protocol LegacyViewerStateSource: Sendable {
    func readProfile() throws -> Data?
    func readWatchlist() throws -> Data?
}

enum LegacyViewerStateSourceError: Error, Equatable, Sendable {
    case invalidSuiteName
}

struct UserDefaultsLegacyViewerStateSource: LegacyViewerStateSource {
    private let suiteName: String?

    init(suiteName: String? = nil) {
        self.suiteName = suiteName
    }

    func readProfile() throws -> Data? {
        try makeUserDefaults().data(forKey: UserDefaultsViewerProfileDataStore.storageKey)
    }

    func readWatchlist() throws -> Data? {
        try makeUserDefaults().data(forKey: "watchlist_items_v2")
    }

    private func makeUserDefaults() throws -> UserDefaults {
        guard let suiteName else { return .standard }
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            throw LegacyViewerStateSourceError.invalidSuiteName
        }
        return defaults
    }
}

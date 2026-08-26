import Foundation

protocol LegacyViewerStateSource: Sendable {
    func readProfile() throws -> Data?
    func readWatchlist() throws -> Data?
}

protocol LegacyViewerStateResetter: Sendable {
    func removeLegacyViewerState() throws
}

enum LegacyViewerStateSourceError: Error, Equatable, Sendable {
    case invalidSuiteName
}

struct UserDefaultsLegacyViewerStateSource: LegacyViewerStateSource, LegacyViewerStateResetter {
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

    func removeLegacyViewerState() throws {
        let defaults = try makeUserDefaults()
        defaults.removeObject(forKey: UserDefaultsViewerProfileDataStore.storageKey)
        defaults.removeObject(forKey: "watchlist_items_v2")
    }

    private func makeUserDefaults() throws -> UserDefaults {
        guard let suiteName else { return .standard }
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            throw LegacyViewerStateSourceError.invalidSuiteName
        }
        return defaults
    }
}

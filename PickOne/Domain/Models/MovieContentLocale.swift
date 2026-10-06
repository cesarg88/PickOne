import Foundation

/// The language used for movie display metadata, independent of viewing region.
enum MovieContentLocale: String, CaseIterable, Sendable {
    case english = "en-US"
    case spanish = "es-ES"

    init(effectiveLocale: Locale) {
        self = effectiveLocale.language.languageCode?.identifier == "es" ? .spanish : .english
    }

    var locale: Locale {
        Locale(identifier: rawValue)
    }
}

struct MovieDisplayMetadata: Equatable, Sendable {
    let movieID: Int
    let title: String
    let genreNames: [Int: String]
}

import Foundation

enum ViewerProfileCopy {
    static let serviceTitle = "Streaming services"
    static let region = "Availability region: Spain"
    static let serviceGuidance = "Choose the services where you can watch movies without paying extra."
    static let progress = "8 taste signals help us start with more confidence."
    static let lowSignalTitle = "Want to rate a few more?"
    static let lowSignalBody = "We can start broadly with what you have told us, or you can rate a few more movies first."
    static let resetTitle = "Reset preferences?"
    static let resetBody = "This removes your streaming services and movie calibration. Your Watchlist and Search History will stay."
    static let unsupportedTitle = "Preferences need to be reset"
    static let unsupportedBody =
        "This saved preference version isn't supported by this build. " +
        "Your Watchlist and Search History won't be affected."
    static let corruptTitle = "Preferences couldn't be read"
    static let corruptBody =
        "Your saved preferences are damaged. You can try again or reset them. " +
        "Your Watchlist and Search History won't be affected."
}

enum AppRootViewState: Equatable {
    case loading
    case onboarding
    case main
    case recovery(ViewerProfileRecoveryReason)
}

enum CalibrationPresentationMode: Equatable {
    case firstOnboarding
    case recalibration
}

struct CalibrationMovieCardPresentationModel: Equatable {
    let id: Int
    let primaryText: String
    let secondaryText: String?
    let posterURL: URL?
    let fallbackTitle: String
}

@MainActor
enum CalibrationMoviePresentationMapper {
    static func map(
        catalogMovie: CalibrationMovie,
        metadata: CalibrationMovieMetadata?
    ) -> CalibrationMovieCardPresentationModel {
        let primary = nonempty(metadata?.title) ?? catalogMovie.titleKnownInSpain
        let original = nonempty(metadata?.originalTitle) ?? catalogMovie.originalOrEnglishTitle
        let year = metadata?.releaseYear ?? catalogMovie.year
        let equivalent = normalized(primary) == normalized(original)

        return CalibrationMovieCardPresentationModel(
            id: catalogMovie.id,
            primaryText: equivalent ? "\(primary) · \(year)" : primary,
            secondaryText: equivalent ? nil : "\(original) · \(year)",
            posterURL: ImageURLBuilder.posterURL(path: metadata?.posterPath, size: .posterLarge),
            fallbackTitle: catalogMovie.titleKnownInSpain
        )
    }

    static func normalized(_ title: String) -> String {
        title
            .split(whereSeparator: \.isWhitespace)
            .joined(separator: " ")
            .lowercased()
    }

    private static func nonempty(_ value: String?) -> String? {
        guard let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines),
              !trimmed.isEmpty else { return nil }
        return trimmed
    }
}

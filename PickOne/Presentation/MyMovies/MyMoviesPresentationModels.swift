import Foundation

struct MyMoviesItemPresentation: Identifiable, Equatable {
    let id: Int
    let title: String
    let releaseYear: String?
    let posterURL: URL?
    let stateLabel: String
    var hasPickOneProvenance = false
}

@MainActor
enum MyMoviesPresentationMapper {
    static func map(
        _ states: [ViewerMovieState]
    ) -> [MyMoviesItemPresentation] {
        states.map { state in
            MyMoviesItemPresentation(
                id: state.movieID,
                title: state.displayMetadata.title,
                releaseYear: state.displayMetadata.releaseYear.map(String.init),
                posterURL: posterURL(for: state.displayMetadata.posterPath),
                stateLabel: stateLabel(for: state),
                hasPickOneProvenance: state.watchState.isWatched && state.pickOneProvenance != nil
            )
        }
    }

    private static func stateLabel(
        for state: ViewerMovieState
    ) -> String {
        if let reaction = state.reaction {
            switch reaction {
                case .loveIt:
                    return String(localized: "Love it")
                case .likeIt:
                    return String(localized: "Like it")
                case .itWasOkay:
                    return String(localized: "It was okay")
                case .didNotLikeIt:
                    return String(localized: "Didn't like it")
            }
        }
        return state.isNotInterested ? String(localized: "Not interested") : String(localized: "Watched")
    }

    private static func posterURL(for path: String?) -> URL? {
        guard let path else { return nil }
        return URL(string: "https://image.tmdb.org/t/p/w342\(path)")
    }
}

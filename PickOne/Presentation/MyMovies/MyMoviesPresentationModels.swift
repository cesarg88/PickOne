import Foundation

struct MyMoviesItemPresentation: Identifiable, Equatable {
    let id: Int
    let title: String
    let releaseYear: String?
    let posterURL: URL?
    let stateLabel: String
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
                stateLabel: stateLabel(for: state)
            )
        }
    }

    private static func stateLabel(
        for state: ViewerMovieState
    ) -> String {
        if let reaction = state.reaction {
            switch reaction {
                case .loveIt:
                    return "Love it"
                case .likeIt:
                    return "Like it"
                case .itWasOkay:
                    return "It was okay"
                case .didNotLikeIt:
                    return "Didn't like it"
            }
        }
        return state.isNotInterested ? "Not interested" : "Watched"
    }

    private static func posterURL(for path: String?) -> URL? {
        guard let path else { return nil }
        return URL(string: "https://image.tmdb.org/t/p/w342\(path)")
    }
}

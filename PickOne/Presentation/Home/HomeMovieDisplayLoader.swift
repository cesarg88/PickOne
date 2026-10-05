import Foundation

struct HomeMovieDisplayLoader: Sendable {
    let getMovieDisplayMetadata: any GetMovieDisplayMetadataUseCase

    func load(
        snapshot: ThreeForTonightSnapshot,
        contentLocale: MovieContentLocale
    ) async -> HomeMovieDisplayProjection {
        let movieIDs = Set(snapshot.decisionSet.recommendations.map(\.display.movieID))
        let anchorIDs = Set(snapshot.decisionSet.recommendations.compactMap { recommendation in
            recommendation.evidence.primary.positiveAnchorMovieID
        })
        // A decision set has at most three cards and one anchor per card, so
        // this task group is bounded to six metadata reads.
        let requestedIDs = Array(movieIDs.union(anchorIDs)).sorted()
        let metadata = await withTaskGroup(of: MovieDisplayMetadata?.self) { group in
            for movieID in requestedIDs {
                group.addTask {
                    try? await getMovieDisplayMetadata.execute(movieID: movieID, contentLocale: contentLocale)
                }
            }
            var values: [Int: MovieDisplayMetadata] = [:]
            for await value in group {
                if let value { values[value.movieID] = value }
            }
            return values
        }
        return HomeMovieDisplayProjection(movies: metadata)
    }
}

private extension RecommendationPrimaryEvidence {
    var positiveAnchorMovieID: Int? {
        switch self {
            case let .positiveAnchor(anchor): anchor.movieID
            case let .watchlistIntent(match):
                if case let .positiveAnchor(anchor) = match { anchor.movieID } else { nil }
            case .positiveGenreAffinity, .sparseQuality: nil
        }
    }
}

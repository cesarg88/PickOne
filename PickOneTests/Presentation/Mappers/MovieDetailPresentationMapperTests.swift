import Foundation
@testable import PickOne
import Testing

@MainActor
@Suite("MovieDetailPresentationMapper Tests", .serialized)
struct MovieDetailPresentationMapperTests {
    @Test("maps snapshot to presentation model")
    func mapsSnapshotToPresentationModel() {
        let snapshot = MovieDetailSnapshot(
            movie: Movie(
                id: 1,
                title: "Movie A",
                originalTitle: "Movie A",
                overview: "Overview",
                releaseDate: nil,
                runtime: 120,
                rating: 8.0,
                voteCount: 100,
                posterPath: "/posterA.jpg",
                backdropPath: "/backdropA.jpg",
                genres: [],
                tagline: nil
            ),
            similar: [
                MovieSummary(id: 2, title: "Movie B", posterPath: "/posterB.jpg", releaseYear: 2022, rating: 7.4),
            ],
            isInWatchlist: false,
            isWatched: false,
            director: Person(id: 10, name: "Director", profilePath: nil, role: .director),
            topCast: [Person(id: 11, name: "Actor", profilePath: nil, role: .cast(character: "Hero"))],
            isSimilarUnavailable: false,
            isCreditsUnavailable: true,
            asOf: Date()
        )

        let model = MovieDetailPresentationMapper.map(snapshot: snapshot)

        #expect(model.title == "Movie A")
        #expect(model.similar.count == 1)
        #expect(model.isCreditsUnavailable == true)
        #expect(model.directorName == "Director")
        #expect(model.similar[0].posterURL?.absoluteString.contains("posterB.jpg") == true)
    }
}

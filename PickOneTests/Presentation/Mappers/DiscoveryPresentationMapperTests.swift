import Foundation
@testable import PickOne
import Testing

@MainActor
@Suite("DiscoveryPresentationMapper Tests", .serialized)
struct DiscoveryPresentationMapperTests {
    @Test("maps snapshot to presentation model")
    func mapsSnapshotToPresentationModel() {
        let snapshot = DiscoverySnapshot(
            movies: [
                MovieSummary(id: 1, title: "Movie A", posterPath: "/posterA.jpg", releaseYear: 2023, rating: 8.1),
            ],
            currentPage: 1,
            hasMorePages: true,
            asOf: Date()
        )

        let model = DiscoveryPresentationMapper.map(snapshot: snapshot)

        #expect(model.currentPage == 1)
        #expect(model.hasMorePages == true)
        #expect(model.movies.count == 1)
        #expect(model.movies[0].title == "Movie A")
        #expect(model.movies[0].releaseYearText == "2023")
        #expect(model.movies[0].ratingText == "8.1")
        #expect(model.movies[0].posterURL?.absoluteString.contains("posterA.jpg") == true)
    }
}

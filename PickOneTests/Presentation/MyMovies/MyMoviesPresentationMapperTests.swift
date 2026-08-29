import Foundation
@testable import PickOne
import Testing

@MainActor
@Suite("My movies presentation mapper")
struct MyMoviesPresentationMapperTests {
    @Test("maps every accepted history label and offline metadata")
    func mapsLabelsAndMetadata() throws {
        let states = try [
            state(id: 1, preference: .reaction(.loveIt)),
            state(id: 2, preference: .reaction(.likeIt)),
            state(id: 3, preference: .reaction(.itWasOkay)),
            state(id: 4, preference: .reaction(.didNotLikeIt)),
            state(id: 5, preference: nil),
            state(id: 6, watched: false, preference: .notInterested),
        ]

        let items = MyMoviesPresentationMapper.map(states)

        #expect(items.map(\.id) == [1, 2, 3, 4, 5, 6])
        #expect(items.map(\.stateLabel) == [
            "Love it",
            "Like it",
            "It was okay",
            "Didn't like it",
            "Watched",
            "Not interested",
        ])
        #expect(items.first?.title == "Movie 1")
        #expect(items.first?.releaseYear == "2024")
        #expect(items.first?.posterURL?.absoluteString == "https://image.tmdb.org/t/p/w342/poster-1.jpg")
    }

    private func state(
        id: Int,
        watched: Bool = true,
        preference: MoviePreference?
    ) throws -> ViewerMovieState {
        try ViewerMovieState(
            movieID: id,
            displayMetadata: MovieFeedbackMetadata(
                title: "Movie \(id)",
                releaseYear: 2024,
                posterPath: "/poster-\(id).jpg"
            ),
            watchState: watched ? .watched : .unwatched,
            preference: preference,
            watchlistIntent: nil,
            stateChangedAt: Date(timeIntervalSince1970: TimeInterval(id))
        )
    }
}

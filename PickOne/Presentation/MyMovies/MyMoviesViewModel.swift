import Foundation
import Observation

enum MyMoviesViewState: Equatable {
    case loading
    case empty
    case loaded([MyMoviesItemPresentation])
    case failure(String)
}

@MainActor
@Observable
final class MyMoviesViewModel {
    private let getMyMovies: any GetMyMoviesUseCase
    @ObservationIgnored private var activeLoadID = UUID()

    var state: MyMoviesViewState = .loading

    init(getMyMovies: any GetMyMoviesUseCase) {
        self.getMyMovies = getMyMovies
    }

    func load() async {
        let loadID = UUID()
        activeLoadID = loadID
        state = .loading

        do {
            let movies = try await getMyMovies.execute()
            try Task.checkCancellation()
            guard activeLoadID == loadID else { return }
            let items = MyMoviesPresentationMapper.map(movies)
            state = items.isEmpty ? .empty : .loaded(items)
        } catch is CancellationError {
            return
        } catch {
            guard activeLoadID == loadID else { return }
            state = .failure("Your movies couldn't be loaded. Please try again.")
        }
    }
}

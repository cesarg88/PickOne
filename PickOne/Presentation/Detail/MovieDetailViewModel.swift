import Foundation
import Observation

enum MovieDetailViewState: Equatable {
    case idle
    case loading
    case loaded(MovieDetailPresentationModel)
    case error(String)
}

@MainActor
@Observable
final class MovieDetailViewModel {
    let movieId: Int
    private let getMovieDetail: GetMovieDetailUseCase
    private let setMembership: SetWatchlistMembershipUseCase
    private let setWatched: SetWatchedUseCase
    private let checkAvailability: CheckMovieAvailabilityUseCase
    private let preparePlaybackOptionsUseCase: PreparePlaybackOptionsUseCase
    private let eligibilityDidChange: @MainActor (DecisionEligibilityChange) -> Void
    private var activeLoadID = UUID()
    private var availabilityOutcome: AvailabilityOutcome?

    var state: MovieDetailViewState = .idle
    var availabilityState: MovieAvailabilityViewState = .loading
    var actionErrorMessage: String?

    init(
        movieId: Int,
        getMovieDetail: GetMovieDetailUseCase,
        setMembership: SetWatchlistMembershipUseCase,
        setWatched: SetWatchedUseCase,
        checkAvailability: CheckMovieAvailabilityUseCase,
        preparePlaybackOptions: PreparePlaybackOptionsUseCase,
        eligibilityDidChange: @escaping @MainActor (DecisionEligibilityChange) -> Void = { _ in }
    ) {
        self.movieId = movieId
        self.getMovieDetail = getMovieDetail
        self.setMembership = setMembership
        self.setWatched = setWatched
        self.checkAvailability = checkAvailability
        preparePlaybackOptionsUseCase = preparePlaybackOptions
        self.eligibilityDidChange = eligibilityDidChange
    }

    // MARK: - Load

    func load() async {
        let loadID = UUID()
        activeLoadID = loadID
        state = .loading
        availabilityState = .loading
        availabilityOutcome = nil

        async let detailLoad: Void = loadDetail(loadID: loadID)
        async let availabilityLoad: Void = loadAvailability(loadID: loadID)
        _ = await (detailLoad, availabilityLoad)
    }

    private func loadDetail(loadID: UUID) async {
        do {
            let cached = try await getMovieDetail.execute(id: movieId, policy: .returnCacheElseLoad)
            try Task.checkCancellation()
            guard activeLoadID == loadID else { return }
            state = .loaded(MovieDetailPresentationMapper.map(snapshot: cached.value))
            if cached.isStale {
                let refreshed = try await getMovieDetail.execute(id: movieId, policy: .refresh)
                try Task.checkCancellation()
                guard activeLoadID == loadID else { return }
                state = .loaded(MovieDetailPresentationMapper.map(snapshot: refreshed.value))
            }
        } catch is CancellationError {
            return
        } catch {
            guard activeLoadID == loadID else { return }
            state = .error(error.localizedDescription)
        }
    }

    private func loadAvailability(loadID: UUID) async {
        do {
            let outcome = try await checkAvailability.execute(
                movieID: movieId,
                policy: .useFreshCache
            )
            try Task.checkCancellation()
            guard activeLoadID == loadID else { return }
            availabilityOutcome = outcome
            availabilityState = AvailabilityPresentationMapper.map(
                outcome: outcome
            )
        } catch is CancellationError {
            return
        } catch {
            guard activeLoadID == loadID else { return }
            let outcome = AvailabilityOutcome.unknown(
                reason: .verificationFailed
            )
            availabilityOutcome = outcome
            availabilityState = .unknown
        }
    }

    func preparePlaybackOptions() async -> URL? {
        guard let availabilityOutcome else {
            return nil
        }

        let loadID = activeLoadID
        do {
            let preparation = try await preparePlaybackOptionsUseCase.execute(
                movieID: movieId,
                currentOutcome: availabilityOutcome
            )
            try Task.checkCancellation()
            guard activeLoadID == loadID else { return nil }

            switch preparation {
                case let .open(url):
                    return url
                case let .updatedOutcome(outcome):
                    let didChange = outcome != availabilityOutcome
                    self.availabilityOutcome = outcome
                    availabilityState = AvailabilityPresentationMapper.map(
                        outcome: outcome
                    )
                    if didChange {
                        notifyEligibilityChange(cause: .availability)
                    }
                    return nil
                case .unavailable:
                    return nil
            }
        } catch is CancellationError {
            return nil
        } catch {
            return nil
        }
    }

    // MARK: - Watchlist Actions

    func toggleWatchlist() async {
        guard case var .loaded(model) = state else { return }

        let movie = MovieSummary(
            id: model.id,
            title: model.title,
            posterPath: extractPosterPath(from: model.posterURL),
            releaseYear: extractYear(from: model.releaseYear),
            rating: extractRating(from: model.rating)
        )

        do {
            try await setMembership.execute(movie: movie, isInWatchlist: !model.isInWatchlist)
            model.isInWatchlist.toggle()
            if !model.isInWatchlist {
                model.isWatched = false // Remove from watchlist clears watched status
            }
            state = .loaded(model)
            notifyEligibilityChange(cause: .watchlist)
        } catch {
            actionErrorMessage = error.localizedDescription
        }
    }

    func toggleWatched() async {
        guard case var .loaded(model) = state,
              model.isInWatchlist else { return }

        do {
            try await setWatched.execute(movieId: model.id, isWatched: !model.isWatched)
            model.isWatched.toggle()
            state = .loaded(model)
            notifyEligibilityChange(cause: .watchlist)
        } catch {
            actionErrorMessage = error.localizedDescription
        }
    }

    // MARK: - Helpers

    private func extractPosterPath(from url: URL?) -> String? {
        guard let url else { return nil }
        // URL format: https://image.tmdb.org/t/p/w500/path.jpg
        let path = url.path
        // Remove the size prefix (e.g., /w500)
        if let range = path.range(of: "/", options: .backwards) {
            return String(path[range.lowerBound...])
        }
        return path
    }

    private func extractYear(from yearText: String?) -> Int? {
        guard let yearText else { return nil }
        return Int(yearText)
    }

    private func extractRating(from ratingText: String) -> Double {
        // Rating format: "7.5 (1,234)"
        let components = ratingText.components(separatedBy: " ")
        return Double(components.first ?? "0") ?? 0
    }

    private func notifyEligibilityChange(cause: DecisionEligibilityRepairCause) {
        guard let change = DecisionEligibilityChange(movieID: movieId, cause: cause) else {
            return
        }
        eligibilityDidChange(change)
    }
}

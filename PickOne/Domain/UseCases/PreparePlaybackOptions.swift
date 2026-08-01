import Foundation

protocol PreparePlaybackOptionsUseCase: Sendable {
    func execute(
        movieID: Int,
        currentOutcome: AvailabilityOutcome
    ) async throws -> PlaybackOptionsPreparation
}

struct PreparePlaybackOptions: PreparePlaybackOptionsUseCase {
    private let checkAvailability: CheckMovieAvailabilityUseCase
    private let clock: AvailabilityClock

    init(
        checkAvailability: CheckMovieAvailabilityUseCase,
        clock: AvailabilityClock
    ) {
        self.checkAvailability = checkAvailability
        self.clock = clock
    }

    func execute(
        movieID: Int,
        currentOutcome: AvailabilityOutcome
    ) async throws -> PlaybackOptionsPreparation {
        guard case let .eligible(_, evidence) = currentOutcome else {
            return .unavailable
        }

        if evidence.isFresh(at: clock.now()) {
            return handoff(from: evidence)
        }

        let refreshed = try await checkAvailability.execute(
            movieID: movieID,
            policy: .reloadIgnoringCache
        )
        guard case let .eligible(_, refreshedEvidence) = refreshed else {
            return .updatedOutcome(refreshed)
        }

        switch handoff(from: refreshedEvidence) {
            case let .open(url):
                return .open(url)
            case .unavailable:
                return .updatedOutcome(refreshed)
            case .updatedOutcome:
                return .updatedOutcome(refreshed)
        }
    }

    private func handoff(
        from evidence: VerifiedAvailabilityEvidence
    ) -> PlaybackOptionsPreparation {
        guard let url = evidence.validTMDBWatchURL else {
            return .unavailable
        }
        return .open(url)
    }
}

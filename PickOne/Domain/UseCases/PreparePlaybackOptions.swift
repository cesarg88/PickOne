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
        guard case .eligible(_, let evidence) = currentOutcome else {
            return .unavailable
        }

        if evidence.isFresh(at: clock.now()) {
            return handoff(from: evidence)
        }

        let refreshed = try await checkAvailability.execute(
            movieID: movieID,
            policy: .reloadIgnoringCache
        )
        guard case .eligible(_, let refreshedEvidence) = refreshed else {
            return .updatedOutcome(refreshed)
        }

        switch handoff(from: refreshedEvidence) {
        case .open(let url):
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

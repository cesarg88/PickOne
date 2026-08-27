extension LocalViewerStateRepository {
    func loadState() -> ViewerMovieStateLoadState {
        do {
            let snapshot = try resolve().snapshot
            destructiveResetAvailability = .unavailable
            return .loaded(snapshot)
        } catch let failure as ExhaustedSourcesFailure {
            destructiveResetAvailability = .available
            return .recovery(failure.recoveryReason)
        } catch let failure as ResolutionFailure {
            destructiveResetAvailability = .unavailable
            return .recovery(failure.recoveryReason)
        } catch {
            destructiveResetAvailability = .unavailable
            return .recovery(.loadFailure)
        }
    }

    func snapshot() throws -> ViewerMovieStateSnapshot {
        do {
            let snapshot = try resolve().snapshot
            destructiveResetAvailability = .unavailable
            return snapshot
        } catch let failure as ExhaustedSourcesFailure {
            destructiveResetAvailability = .available
            throw failure.repositoryError
        } catch let failure as ResolutionFailure {
            destructiveResetAvailability = .unavailable
            throw failure.repositoryError
        } catch {
            destructiveResetAvailability = .unavailable
            throw ViewerMovieStateRepositoryError.loadFailure
        }
    }

    func state(movieID: Int) throws -> ViewerMovieState? {
        guard movieID > 0 else {
            throw ViewerMovieStateRepositoryError.invalidMovieID
        }
        return try snapshot().state(for: movieID)
    }
}

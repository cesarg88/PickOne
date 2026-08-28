import Foundation

enum DecisionTasteProfileHydrationError: Error, Equatable, Sendable {
    case movieUnavailable(movieID: Int)
}

struct HydrateDecisionTasteProfile: Sendable {
    private static let requestLimit = 4

    private let movieRepository: any MovieRepository

    init(movieRepository: any MovieRepository) {
        self.movieRepository = movieRepository
    }

    func execute(
        reactions: [Int: MovieReaction]
    ) async throws -> P1TasteProfile {
        let orderedReactions = reactions.sorted { $0.key < $1.key }
        var results = [HydrationResult?](
            repeating: nil,
            count: orderedReactions.count
        )
        var nextIndex = 0

        try await withThrowingTaskGroup(
            of: (Int, HydrationResult).self
        ) { group in
            func addTask(at index: Int) {
                let (movieID, reaction) = orderedReactions[index]
                group.addTask {
                    do {
                        let movie = try await movieRepository.getMovieDetail(
                            id: movieID,
                            policy: .returnCacheElseLoad
                        ).value
                        guard movie.id == movieID else {
                            return (index, .failure)
                        }
                        return (index, .evidence(TasteReactionEvidence(
                            movieID: movieID,
                            movieTitle: movie.title,
                            reaction: reaction.calibrationReaction,
                            genres: Set(movie.genres.map {
                                DecisionGenre(id: $0.id, name: $0.name)
                            }),
                            releaseYear: movie.releaseYear
                        )))
                    } catch is CancellationError {
                        throw CancellationError()
                    } catch {
                        return (index, .failure)
                    }
                }
            }

            while nextIndex < min(Self.requestLimit, orderedReactions.count) {
                addTask(at: nextIndex)
                nextIndex += 1
            }

            while let (index, result) = try await group.next() {
                results[index] = result
                try Task.checkCancellation()
                if nextIndex < orderedReactions.count {
                    addTask(at: nextIndex)
                    nextIndex += 1
                }
            }
        }

        var orderedEvidence: [TasteReactionEvidence] = []
        orderedEvidence.reserveCapacity(results.count)
        for (index, result) in results.enumerated() {
            guard case let .evidence(evidence) = result else {
                throw DecisionTasteProfileHydrationError.movieUnavailable(
                    movieID: orderedReactions[index].key
                )
            }
            orderedEvidence.append(evidence)
        }
        return P1TasteProfile(evidence: orderedEvidence)
    }
}

private enum HydrationResult: Sendable {
    case evidence(TasteReactionEvidence)
    case failure
}

extension MovieReaction {
    var calibrationReaction: CalibrationReaction {
        switch self {
            case .loveIt: .loveIt
            case .likeIt: .likeIt
            case .itWasOkay: .itWasOkay
            case .didNotLikeIt: .didNotLikeIt
        }
    }
}

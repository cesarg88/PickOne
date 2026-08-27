import Foundation
@testable import PickOne
import Synchronization
import Testing

@Suite("Three for Tonight coordinator")
struct ThreeForTonightCoordinatorTests {
    @Test("matching envelope relaunches without candidate or availability requests")
    func matchingEnvelopeRelaunchesWithoutNetwork() async throws {
        let profile = sparseProfile()
        let envelope = try emptyEnvelope(profile: profile)
        let candidateRepository = CoordinatorCandidateRepository()
        let availabilityRepository = CoordinatorAvailabilityRepository()
        let decisionSetRepository = CoordinatorDecisionSetRepository(loadResult: .available(envelope))
        let sut = makeCoordinator(
            profile: profile,
            candidateRepository: candidateRepository,
            availabilityRepository: availabilityRepository,
            decisionSetRepository: decisionSetRepository
        )

        let result = try await sut.load()

        #expect(result == .usable(ThreeForTonightSnapshot(
            decisionSet: envelope,
            savedMovieIDs: []
        )))
        #expect(await candidateRepository.requestedPages.isEmpty)
        #expect(await availabilityRepository.requestedMovieIDs.isEmpty)
        #expect(await decisionSetRepository.replacements.isEmpty)
    }

    @Test("initial generation recalls six pages and publishes only the persisted winner")
    func initialGenerationPersistsWinner() async throws {
        let profile = sparseProfile()
        let candidate = try #require(DecisionCandidateSeed(
            movieID: 10,
            localizedTitle: "Winner",
            posterPath: "/poster.jpg",
            backdropPath: nil,
            genres: [DecisionGenre(id: 18, name: "Drama")],
            releaseYear: 2024,
            voteAverage: 8.5,
            voteCount: 20000
        ))
        let candidateRepository = CoordinatorCandidateRepository(
            candidatesByPage: [1: [candidate]]
        )
        let evidence = verifiedEvidence(movieID: 10)
        let availabilityRepository = CoordinatorAvailabilityRepository(
            evidenceByMovieID: [10: evidence]
        )
        let decisionSetRepository = CoordinatorDecisionSetRepository(loadResult: .absent)
        let movieRepository = CoordinatorMovieRepository(movies: [
            10: movie(id: 10, title: "Hydrated title", runtime: 112),
        ])
        let sut = makeCoordinator(
            profile: profile,
            candidateRepository: candidateRepository,
            availabilityRepository: availabilityRepository,
            decisionSetRepository: decisionSetRepository,
            movieRepository: movieRepository
        )

        let result = try await sut.load()
        guard case let .usable(snapshot) = result else {
            Issue.record("Expected a usable generated snapshot")
            return
        }

        #expect(await candidateRepository.requestedPages == Array(1 ... 6))
        #expect(await decisionSetRepository.replacements == [snapshot.decisionSet])
        #expect(snapshot.decisionSet.recommendations.map(\.display.movieID) == [10])
        #expect(snapshot.decisionSet.recommendations.first?.display.localizedTitle == "Winner")
        #expect(snapshot.decisionSet.recommendations.first?.display.runtimeMinutes == 112)
        #expect(snapshot.decisionSet.cycle.shownMovieIDs == [10])
    }

    @Test("refresh failure retains a matching usable set and does not advance history")
    func refreshFailureRetainsSet() async throws {
        let profile = sparseProfile()
        let envelope = try emptyEnvelope(profile: profile, shownMovieIDs: [10, 20])
        let candidateRepository = CoordinatorCandidateRepository(error: .unavailable)
        let decisionSetRepository = CoordinatorDecisionSetRepository(loadResult: .available(envelope))
        let sut = makeCoordinator(
            profile: profile,
            candidateRepository: candidateRepository,
            availabilityRepository: CoordinatorAvailabilityRepository(),
            decisionSetRepository: decisionSetRepository
        )

        let result = try await sut.refresh()

        #expect(result == .retryableFailure(
            reason: .generationUnavailable,
            retained: ThreeForTonightSnapshot(decisionSet: envelope, savedMovieIDs: [])
        ))
        #expect(await decisionSetRepository.replacements.isEmpty)
    }

    @Test("quarantined recovery replaces only the recommendation envelope")
    func quarantinedRecoveryReplacesEnvelope() async throws {
        let profile = sparseProfile()
        let candidateRepository = CoordinatorCandidateRepository()
        let decisionSetRepository = CoordinatorDecisionSetRepository(
            loadResult: .recovery(.corruptData)
        )
        let sut = makeCoordinator(
            profile: profile,
            candidateRepository: candidateRepository,
            availabilityRepository: CoordinatorAvailabilityRepository(),
            decisionSetRepository: decisionSetRepository
        )

        let result = try await sut.load()

        guard case let .usable(snapshot) = result else {
            Issue.record("Expected successful empty recovery")
            return
        }
        #expect(snapshot.decisionSet.recommendations.isEmpty)
        #expect(await decisionSetRepository.replacements == [snapshot.decisionSet])
    }

    @Test("refresh excludes complete shown history and appends only new winners")
    func refreshPreservesShownHistory() async throws {
        let profile = sparseProfile()
        let envelope = try emptyEnvelope(profile: profile, shownMovieIDs: [10])
        let candidates = try [10, 20].map { movieID in
            try #require(DecisionCandidateSeed(
                movieID: movieID,
                localizedTitle: "Movie \(movieID)",
                posterPath: nil,
                backdropPath: nil,
                genres: [DecisionGenre(id: 18, name: "Drama")],
                releaseYear: 2024,
                voteAverage: 8.5,
                voteCount: 20000
            ))
        }
        let candidateRepository = CoordinatorCandidateRepository(
            candidatesByPage: [1: candidates]
        )
        let availabilityRepository = CoordinatorAvailabilityRepository(
            evidenceByMovieID: [20: verifiedEvidence(movieID: 20)]
        )
        let decisionSetRepository = CoordinatorDecisionSetRepository(
            loadResult: .available(envelope)
        )
        let sut = makeCoordinator(
            profile: profile,
            candidateRepository: candidateRepository,
            availabilityRepository: availabilityRepository,
            decisionSetRepository: decisionSetRepository,
            movieRepository: CoordinatorMovieRepository(movies: [
                20: movie(id: 20, title: "Movie 20", runtime: nil),
            ])
        )

        let result = try await sut.refresh()
        guard case let .usable(snapshot) = result else {
            Issue.record("Expected a usable refreshed snapshot")
            return
        }

        #expect(snapshot.decisionSet.recommendations.map(\.display.movieID) == [20])
        #expect(snapshot.decisionSet.cycle.id == envelope.cycle.id)
        #expect(snapshot.decisionSet.cycle.shownMovieIDs == [10, 20])
        #expect(await availabilityRepository.requestedMovieIDs == [20])
    }

    @Test("persistence failure retains the previous set without advancing storage")
    func persistenceFailureRetainsPreviousSet() async throws {
        let profile = sparseProfile()
        let envelope = try emptyEnvelope(profile: profile, shownMovieIDs: [10])
        let candidate = try #require(DecisionCandidateSeed(
            movieID: 20,
            localizedTitle: "Replacement",
            posterPath: nil,
            backdropPath: nil,
            genres: [DecisionGenre(id: 18, name: "Drama")],
            releaseYear: 2024,
            voteAverage: 8.5,
            voteCount: 20000
        ))
        let decisionSetRepository = CoordinatorDecisionSetRepository(
            loadResult: .available(envelope),
            replaceError: .unavailable
        )
        let sut = makeCoordinator(
            profile: profile,
            candidateRepository: CoordinatorCandidateRepository(
                candidatesByPage: [1: [candidate]]
            ),
            availabilityRepository: CoordinatorAvailabilityRepository(
                evidenceByMovieID: [20: verifiedEvidence(movieID: 20)]
            ),
            decisionSetRepository: decisionSetRepository,
            movieRepository: CoordinatorMovieRepository(movies: [
                20: movie(id: 20, title: "Replacement", runtime: 100),
            ])
        )

        let result = try await sut.refresh()

        #expect(result == .retryableFailure(
            reason: .persistenceFailed,
            retained: ThreeForTonightSnapshot(decisionSet: envelope, savedMovieIDs: [])
        ))
        #expect(await decisionSetRepository.replacements.isEmpty)
    }

    @Test("repository read and quarantine failures block recovery")
    func unsafeRecoveryStateDoesNotGenerate() async throws {
        let profile = sparseProfile()
        for reason in [DecisionSetRecoveryReason.loadFailed, .quarantineFailed] {
            let candidates = CoordinatorCandidateRepository()
            let sut = makeCoordinator(
                profile: profile,
                candidateRepository: candidates,
                availabilityRepository: CoordinatorAvailabilityRepository(),
                decisionSetRepository: CoordinatorDecisionSetRepository(
                    loadResult: .recovery(reason)
                )
            )

            #expect(try await sut.load() == .retryableFailure(
                reason: .recoveryFailed,
                retained: nil
            ))
            #expect(await candidates.requestedPages.isEmpty)
        }
    }

    @Test("unreadable Watchlist blocks generation with its bounded failure reason")
    func unreadableWatchlistBlocksGeneration() async throws {
        let candidates = CoordinatorCandidateRepository()
        let sut = makeCoordinator(
            profile: sparseProfile(),
            candidateRepository: candidates,
            availabilityRepository: CoordinatorAvailabilityRepository(),
            decisionSetRepository: CoordinatorDecisionSetRepository(loadResult: .absent),
            watchlistRepository: CoordinatorWatchlistRepository(loadError: .unavailable)
        )

        #expect(try await sut.load() == .retryableFailure(
            reason: .watchlistUnavailable,
            retained: nil
        ))
        #expect(await candidates.requestedPages.isEmpty)
    }

    @Test("a newer request cancels a generation before persistence")
    func newerRequestSupersedesOlderWork() async throws {
        let candidates = CoordinatorCandidateRepository(delay: .milliseconds(20))
        let decisionSetRepository = CoordinatorDecisionSetRepository(loadResult: .absent)
        let sut = makeCoordinator(
            profile: sparseProfile(),
            candidateRepository: candidates,
            availabilityRepository: CoordinatorAvailabilityRepository(),
            decisionSetRepository: decisionSetRepository
        )
        let first = Task { try await sut.load() }
        while await candidates.requestedPages.isEmpty {
            await Task.yield()
        }

        let second = try await sut.load()

        await #expect(throws: CancellationError.self) {
            _ = try await first.value
        }
        guard case .usable = second else {
            Issue.record("Expected the newer operation to publish")
            return
        }
        #expect(await decisionSetRepository.replacements.count == 1)
    }

    @Test("a cross-store change after persistence prevents stale publication")
    func crossStoreRaceDoesNotPublish() async throws {
        let profile = sparseProfile()
        let watchlist = MutableCoordinatorWatchlistRepository()
        let changedItem = WatchlistItem(
            id: 999,
            addedAt: Date(timeIntervalSince1970: 3000),
            isWatched: false,
            movie: MovieSummary(
                id: 999,
                title: "Changed",
                posterPath: nil,
                releaseYear: 2024,
                rating: 8
            )
        )
        let decisionSetRepository = CoordinatorDecisionSetRepository(
            loadResult: .absent,
            onReplace: { watchlist.setItems([changedItem]) }
        )
        let sut = makeCoordinator(
            profile: profile,
            candidateRepository: CoordinatorCandidateRepository(),
            availabilityRepository: CoordinatorAvailabilityRepository(),
            decisionSetRepository: decisionSetRepository,
            watchlistRepository: watchlist
        )

        let result = try await sut.load()

        #expect(result == .retryableFailure(
            reason: .trustedInputsChanged,
            retained: nil
        ))
        #expect(await decisionSetRepository.replacements.count == 1)
    }

    @Test("load repairs a newly watched member without resetting cycle history")
    func loadRepairsWatchedMember() async throws {
        let profile = sparseProfile()
        let envelope = try envelopeWithRecommendation(movieID: 10, profile: profile)
        let replacement = try #require(DecisionCandidateSeed(
            movieID: 20,
            localizedTitle: "Replacement",
            posterPath: nil,
            backdropPath: nil,
            genres: [DecisionGenre(id: 18, name: "Drama")],
            releaseYear: 2024,
            voteAverage: 8.5,
            voteCount: 20000
        ))
        let watchlist = CoordinatorWatchlistRepository(items: [WatchlistItem(
            id: 10,
            addedAt: Date(timeIntervalSince1970: 3000),
            isWatched: true,
            movie: MovieSummary(
                id: 10,
                title: "Watched",
                posterPath: nil,
                releaseYear: 2024,
                rating: 8.5
            )
        )])
        let availability = CoordinatorAvailabilityRepository(
            evidenceByMovieID: [
                10: verifiedEvidence(movieID: 10),
                20: verifiedEvidence(movieID: 20),
            ]
        )
        let decisionSets = CoordinatorDecisionSetRepository(loadResult: .available(envelope))
        let sut = makeCoordinator(
            profile: profile,
            candidateRepository: CoordinatorCandidateRepository(
                candidatesByPage: [1: [replacement]]
            ),
            availabilityRepository: availability,
            decisionSetRepository: decisionSets,
            movieRepository: CoordinatorMovieRepository(movies: [
                10: movie(id: 10, title: "Watched", runtime: 100),
                20: movie(id: 20, title: "Replacement", runtime: 110),
            ]),
            watchlistRepository: watchlist
        )

        let result = try await sut.load()
        guard case let .usable(snapshot) = result else {
            Issue.record("Expected a repaired snapshot")
            return
        }

        #expect(snapshot.decisionSet.recommendations.map(\.display.movieID) == [20])
        #expect(snapshot.decisionSet.cycle.id == envelope.cycle.id)
        #expect(snapshot.decisionSet.cycle.shownMovieIDs == [10, 20])
        #expect(await decisionSets.replacements == [snapshot.decisionSet])
    }
}

private extension ThreeForTonightCoordinatorTests {
    private func makeCoordinator(
        profile: ViewerProfile,
        candidateRepository: CoordinatorCandidateRepository,
        availabilityRepository: CoordinatorAvailabilityRepository,
        decisionSetRepository: CoordinatorDecisionSetRepository,
        movieRepository: CoordinatorMovieRepository = CoordinatorMovieRepository(),
        watchlistRepository: any WatchlistRepository = CoordinatorWatchlistRepository()
    ) -> ThreeForTonightCoordinator {
        let profileRepository = CoordinatorProfileRepository(profile: profile)
        return ThreeForTonightCoordinator(
            viewerProfileRepository: profileRepository,
            viewerMovieStateRepository: CoordinatorViewerMovieStateRepository(),
            watchlistRepository: watchlistRepository,
            decisionSetRepository: decisionSetRepository,
            inputAssembler: AssembleDecisionEngineInput(
                viewerProfileRepository: profileRepository,
                watchlistRepository: watchlistRepository,
                candidateRepository: candidateRepository,
                movieRepository: movieRepository,
                availabilityRepository: availabilityRepository
            ),
            movieRepository: movieRepository,
            availabilityRepository: availabilityRepository,
            signer: StableDecisionCycleSigner()
        )
    }

    private func sparseProfile() -> ViewerProfile {
        ViewerProfile(
            profileSchemaVersion: ViewerProfile.currentSchemaVersion,
            catalogID: .spainHouseholdV1,
            region: .spain,
            selectedServices: [.netflix],
            reactions: [:]
        )
    }

    private func emptyEnvelope(
        profile: ViewerProfile,
        shownMovieIDs: Set<Int> = [],
        sourceSnapshotID: ViewerStateSnapshotID = CoordinatorViewerMovieStateRepository.defaultSnapshotID
    ) throws -> PersistedDecisionSet {
        let signature = try StableDecisionCycleSigner().signature(for: DecisionCycleIdentity(
            engineModelVersion: .p1Model,
            profile: profile
        ))
        return try PersistedDecisionSet(
            id: UUID(),
            generatedAt: Date(timeIntervalSince1970: 1000),
            engineModelVersion: .p1Model,
            cycle: DecisionCycle(
                id: UUID(),
                identitySignature: signature,
                shownMovieIDs: shownMovieIDs
            ),
            sourceViewerStateSnapshotID: sourceSnapshotID,
            region: profile.region,
            selectedProviderIDs: profile.selectedServices.map(\.providerID),
            recommendations: []
        )
    }

    private func envelopeWithRecommendation(
        movieID: Int,
        profile: ViewerProfile
    ) throws -> PersistedDecisionSet {
        let signature = try StableDecisionCycleSigner().signature(for: DecisionCycleIdentity(
            engineModelVersion: .p1Model,
            profile: profile
        ))
        let display = try DecisionDisplaySnapshot(
            movieID: movieID,
            localizedTitle: "Movie \(movieID)",
            posterPath: nil,
            backdropPath: nil,
            runtimeMinutes: 100,
            releaseYear: 2024,
            genres: [DecisionGenre(id: 18, name: "Drama")]
        )
        let provider = try DecisionProviderSnapshot(
            providerID: PilotStreamingService.netflix.providerID,
            name: PilotStreamingService.netflix.name,
            logoPath: "/netflix.jpg",
            productOrder: PilotStreamingService.netflix.productOrder
        )
        let recommendation = try PersistedDecisionRecommendation(
            role: .safeChoice,
            evidence: RecommendationEvidence(primary: .sparseQuality, diversity: nil),
            display: display,
            availability: DecisionAvailabilitySnapshot(
                matchingProviders: [provider],
                verifiedAt: Date(timeIntervalSince1970: 2000),
                regionalWatchURL: URL(string: "https://www.themoviedb.org/movie/\(movieID)/watch")
            )
        )
        return try PersistedDecisionSet(
            id: UUID(),
            generatedAt: Date(timeIntervalSince1970: 1000),
            engineModelVersion: .p1Model,
            cycle: DecisionCycle(
                id: UUID(),
                identitySignature: signature,
                shownMovieIDs: [movieID]
            ),
            sourceViewerStateSnapshotID: CoordinatorViewerMovieStateRepository.defaultSnapshotID,
            region: profile.region,
            selectedProviderIDs: profile.selectedServices.map(\.providerID),
            recommendations: [recommendation]
        )
    }

    private func verifiedEvidence(movieID: Int) -> VerifiedAvailabilityEvidence {
        VerifiedAvailabilityEvidence(
            regionalEvidence: RegionalAvailabilityEvidence(
                movieID: movieID,
                region: .spain,
                watchURL: "https://www.themoviedb.org/movie/\(movieID)/watch",
                flatrate: [ProviderOfferEvidence(
                    providerID: PilotStreamingService.netflix.providerID,
                    sourceName: PilotStreamingService.netflix.name,
                    logoPath: "/netflix.jpg"
                )],
                rent: [],
                buy: [],
                ads: [],
                free: []
            ),
            verifiedAt: Date(timeIntervalSince1970: 2000)
        )
    }

    private func movie(id: Int, title: String, runtime: Int?) -> Movie {
        Movie(
            id: id,
            title: title,
            originalTitle: title,
            overview: "Overview",
            releaseDate: Date(timeIntervalSince1970: 1_704_067_200),
            runtime: runtime,
            rating: 8.5,
            voteCount: 20000,
            posterPath: "/detail-poster.jpg",
            backdropPath: nil,
            genres: [Genre(id: 18, name: "Drama")],
            tagline: nil
        )
    }
}

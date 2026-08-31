import Foundation
@testable import PickOne
import Testing

@Suite("Milestone 7 upgrade end to end", .serialized)
struct Milestone7UpgradeEndToEndTests {
    @Test("final M6 state migrates, reconciles, and relaunches as one coherent M7 state")
    func finalM6UpgradeAndRelaunch() async throws {
        let suiteName = "PickOneTests.Milestone7Upgrade.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let fixture = try makeLegacyFixture()
        defaults.set(fixture.profileData, forKey: UserDefaultsViewerProfileDataStore.storageKey)
        defaults.set(fixture.watchlistData, forKey: "watchlist_items_v2")
        defaults.set(fixture.searchHistory, forKey: "search_history")
        let files = InMemoryLocalViewerStateFileStore()
        let decisionStore = InMemoryDecisionSetDataStore(activeData: fixture.decisionSetData)
        let repositories = makeRepositories(
            suiteName: suiteName,
            files: files,
            decisionStore: decisionStore,
            snapshotIDs: [fixture.snapshotID]
        )

        let firstResult = try await makeCoordinator(
            repositories: repositories,
            fixture: fixture
        ).load()
        let firstSnapshot = try usableSnapshot(firstResult)

        #expect(firstSnapshot.decisionSet.cycle.id == fixture.cycleID)
        #expect(firstSnapshot.decisionSet.cycle.shownMovieIDs == fixture.shownMovieIDs.union([700]))
        #expect(firstSnapshot.decisionSet.recommendations.map(\.display.movieID) == [700])
        #expect(firstSnapshot.decisionSet.sourceViewerStateSnapshotID == fixture.snapshotID)
        #expect(files.activeReplacementCount == 1)
        #expect(decisionStore.activeReplacementCount == 1)
        #expect(decisionStore.activeData != fixture.decisionSetData)
        try await assertMigratedState(repositories: repositories, fixture: fixture)
        #expect(defaults.data(forKey: UserDefaultsViewerProfileDataStore.storageKey) == fixture.profileData)
        #expect(defaults.data(forKey: "watchlist_items_v2") == fixture.watchlistData)
        #expect(defaults.stringArray(forKey: "search_history") == fixture.searchHistory)

        let relaunched = makeRepositories(
            suiteName: suiteName,
            files: files,
            decisionStore: decisionStore,
            snapshotIDs: []
        )
        let relaunchedResult = try await makeCoordinator(
            repositories: relaunched,
            fixture: fixture
        ).load()
        let relaunchedSnapshot = try usableSnapshot(relaunchedResult)

        #expect(relaunchedSnapshot == firstSnapshot)
        #expect(decisionStore.activeReplacementCount == 1)
        try await assertMigratedState(repositories: relaunched, fixture: fixture)
    }

    private func assertMigratedState(
        repositories: Repositories,
        fixture: LegacyFixture
    ) async throws {
        let viewerSnapshot = try await repositories.viewerState.snapshot()
        #expect(viewerSnapshot.id == fixture.snapshotID)
        #expect(ViewerMovieStateProjections.reactions(from: viewerSnapshot) == fixture.reactions)

        guard case let .completed(profile, draft) = await repositories.profile.loadState() else {
            Issue.record("Expected a completed migrated profile")
            return
        }
        #expect(profile == fixture.profile)
        #expect(draft == nil)

        let watchlist = try await repositories.watchlist.loadAllItems()
        #expect(watchlist.map(\.id) == [fixture.savedMovieID])
        let history = try await GetMyMovies(repository: repositories.viewerState).execute()
        #expect(Set(history.map(\.movieID)) == Set(fixture.reactions.keys).union([fixture.watchedMovieID]))
    }

    private func makeCoordinator(
        repositories: Repositories,
        fixture: LegacyFixture
    ) throws -> ThreeForTonightCoordinator {
        try ThreeForTonightCoordinator(
            viewerProfileRepository: repositories.profile,
            viewerMovieStateRepository: repositories.viewerState,
            decisionSetRepository: repositories.decisionSet,
            inputAssembler: AssembleDecisionEngineInput(
                candidateRepository: CoordinatorCandidateRepository(candidatesByPage: [
                    1: [CoordinatorTestFixtures.candidate(700)],
                ]),
                movieRepository: fixture.movieRepository,
                availabilityRepository: fixture.availabilityRepository
            ),
            movieRepository: fixture.movieRepository,
            availabilityRepository: fixture.availabilityRepository,
            signer: StableDecisionCycleSigner(),
            clock: FixedDecisionSetClock(now: LocalViewerStateTestFixtures.date)
        )
    }

    private func makeRepositories(
        suiteName: String,
        files: InMemoryLocalViewerStateFileStore,
        decisionStore: InMemoryDecisionSetDataStore,
        snapshotIDs: [ViewerStateSnapshotID]
    ) -> Repositories {
        let sequence = SequenceUUIDGenerator(snapshotIDs.map(\.rawValue))
        let legacy = UserDefaultsLegacyViewerStateSource(suiteName: suiteName)
        let viewerState = LocalViewerStateRepository(
            fileStore: files,
            legacySource: legacy,
            legacyResetter: legacy,
            snapshotID: { sequence.next() },
            now: { LocalViewerStateTestFixtures.date }
        )
        return Repositories(
            viewerState: viewerState,
            profile: LocalViewerProfileRepositoryAdapter(repository: viewerState),
            watchlist: LocalViewerStateWatchlistAdapter(repository: viewerState),
            decisionSet: DefaultDecisionSetRepository(store: decisionStore)
        )
    }

    private func makeLegacyFixture() throws -> LegacyFixture {
        let catalogMovies = Array(CalibrationCatalog.spainHouseholdV1.movies.prefix(8))
        let profileReactions = Dictionary(
            uniqueKeysWithValues: catalogMovies.enumerated().map { index, movie in
                let reaction: CalibrationReaction = switch index {
                    case 0: .loveIt
                    case 1: .likeIt
                    default: .itWasOkay
                }
                return (movie.id, reaction)
            }
        )
        let reactions = try Dictionary(
            uniqueKeysWithValues: profileReactions.map { movieID, reaction in
                let movieReaction: MovieReaction = switch reaction {
                    case .loveIt: .loveIt
                    case .likeIt: .likeIt
                    case .itWasOkay: .itWasOkay
                    case .didNotLikeIt: .didNotLikeIt
                    case .haveNotSeenIt, .doNotKnowIt:
                        throw Milestone7UpgradeTestError.nonInformativeReaction
                }
                return (movieID, movieReaction)
            }
        )
        let profile = ViewerProfile(
            profileSchemaVersion: ViewerProfile.currentSchemaVersion,
            catalogID: .spainHouseholdV1,
            region: .spain,
            selectedServices: [.netflix],
            reactions: profileReactions
        )
        let profileData = try JSONViewerProfileEnvelopeCoder().encodeEnvelope(
            ViewerStateEnvelopeV1DTO(
                envelopeSchemaVersion: ViewerStateEnvelopeV1DTO.schemaVersion,
                completedProfile: ViewerProfileV1DTO(
                    profileSchemaVersion: 1,
                    calibrationCatalogVersion: CalibrationCatalogID.spainHouseholdV1.rawValue,
                    regionCode: ViewingRegion.spain.code,
                    selectedProviderIDs: [PilotStreamingService.netflix.providerID],
                    reactionsByMovieID: profileReactions.mapValues(\.rawValue)
                ),
                profileDraft: nil
            )
        )
        let savedMovieID = 501
        let watchedMovieID = 502
        let watchlistData = try JSONEncoder().encode([
            legacyWatchlistItem(movieID: savedMovieID, watched: false),
            legacyWatchlistItem(movieID: watchedMovieID, watched: true),
        ])
        let cycleID = try #require(UUID(uuidString: "40000000-0000-0000-0000-000000000004"))
        let snapshotID = try ViewerStateSnapshotID(
            rawValue: #require(LocalViewerStateTestFixtures.firstID)
        )
        let shownMovieIDs: Set<Int> = [601, 602]
        let signature = try StableDecisionCycleSigner().signature(
            for: DecisionCycleIdentity(engineModelVersion: .p1Model, profile: profile)
        )
        let decisionSetData = try encodeLegacyDecisionSet(
            cycleID: cycleID,
            signature: signature,
            shownMovieIDs: shownMovieIDs
        )
        let movies = Dictionary(
            uniqueKeysWithValues: (catalogMovies.map(\.id) + [700]).map {
                ($0, CoordinatorTestFixtures.movie($0))
            }
        )
        return LegacyFixture(
            profile: profile,
            reactions: reactions,
            profileData: profileData,
            watchlistData: watchlistData,
            decisionSetData: decisionSetData,
            searchHistory: ["Arrival", "Heat"],
            savedMovieID: savedMovieID,
            watchedMovieID: watchedMovieID,
            cycleID: cycleID,
            shownMovieIDs: shownMovieIDs,
            snapshotID: snapshotID,
            movieRepository: CoordinatorMovieRepository(movies: movies),
            availabilityRepository: CoordinatorAvailabilityRepository(
                evidenceByMovieID: [700: CoordinatorTestFixtures.evidence(700)]
            )
        )
    }

    private func legacyWatchlistItem(
        movieID: Int,
        watched: Bool
    ) -> PersistedWatchlistItem {
        PersistedWatchlistItem(
            movieId: movieID,
            title: "Movie \(movieID)",
            posterPath: "/movie-\(movieID).jpg",
            releaseYear: 2024,
            rating: 8,
            addedAt: LocalViewerStateTestFixtures.date,
            isWatched: watched
        )
    }

    private func encodeLegacyDecisionSet(
        cycleID: UUID,
        signature: DecisionCycleSignature,
        shownMovieIDs: Set<Int>
    ) throws -> Data {
        let envelope = try DecisionSetEnvelopeV1DTO(
            envelopeSchemaVersion: DecisionSetEnvelopeV1DTO.schemaVersion,
            decisionSetID: #require(
                UUID(uuidString: "50000000-0000-0000-0000-000000000005")
            ),
            generatedAt: LocalViewerStateTestFixtures.date,
            engineModelVersion: DecisionEngineModelVersion.p1Model.rawValue,
            cycle: DecisionCycleV1DTO(
                id: cycleID,
                identitySignature: signature.rawValue,
                shownMovieIDs: shownMovieIDs.sorted()
            ),
            regionCode: ViewingRegion.spain.code,
            selectedProviderIDs: [PilotStreamingService.netflix.providerID],
            recommendations: []
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        encoder.dateEncodingStrategy = .millisecondsSince1970
        return try encoder.encode(envelope)
    }

    private func usableSnapshot(
        _ result: ThreeForTonightResult
    ) throws -> ThreeForTonightSnapshot {
        guard case let .usable(snapshot) = result else {
            Issue.record("Expected a usable snapshot, got \(result)")
            throw Milestone7UpgradeTestError.expectedUsableSnapshot
        }
        return snapshot
    }
}

private extension Milestone7UpgradeEndToEndTests {
    struct Repositories {
        let viewerState: LocalViewerStateRepository
        let profile: LocalViewerProfileRepositoryAdapter
        let watchlist: LocalViewerStateWatchlistAdapter
        let decisionSet: DefaultDecisionSetRepository
    }

    struct LegacyFixture {
        let profile: ViewerProfile
        let reactions: [Int: MovieReaction]
        let profileData: Data
        let watchlistData: Data
        let decisionSetData: Data
        let searchHistory: [String]
        let savedMovieID: Int
        let watchedMovieID: Int
        let cycleID: UUID
        let shownMovieIDs: Set<Int>
        let snapshotID: ViewerStateSnapshotID
        let movieRepository: CoordinatorMovieRepository
        let availabilityRepository: CoordinatorAvailabilityRepository
    }

    struct FixedDecisionSetClock: DecisionSetClock {
        let nowValue: Date

        init(now: Date) {
            nowValue = now
        }

        func now() -> Date {
            nowValue
        }
    }
}

private enum Milestone7UpgradeTestError: Error {
    case expectedUsableSnapshot
    case nonInformativeReaction
}

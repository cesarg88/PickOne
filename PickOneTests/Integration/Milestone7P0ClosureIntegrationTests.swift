import Foundation
@testable import PickOne
import Testing

@Suite("Milestone 7 P0 closure integration", .serialized)
struct Milestone7P0ClosureIntegrationTests {
    #if DEBUG
        @Test("debug-only non-persisting diagnostics scenario reaches page twenty")
        func deviceDiagnosticsScenarioReachesPageTwenty() async throws {
            let movieIDs = Array(4001 ... 4060)
            let pages = try Dictionary(uniqueKeysWithValues: (1 ... 20).map { page in
                let start = (page - 1) * 3
                let pageMovieIDs = Array(movieIDs[start ..< start + 3])
                return try (page, pageMovieIDs.map(CoordinatorTestFixtures.candidate))
            })
            let candidates = CoordinatorCandidateRepository(candidatesByPage: pages)
            let movies = CoordinatorMovieRepository(movies: Dictionary(
                uniqueKeysWithValues: movieIDs.map {
                    ($0, CoordinatorTestFixtures.movie($0))
                }
            ))
            let availability = CoordinatorAvailabilityRepository(
                evidenceByMovieID: Dictionary(uniqueKeysWithValues: movieIDs.map {
                    ($0, CoordinatorTestFixtures.evidence($0))
                })
            )
            let sut = M7P0DeviceDiagnosticsScenario.makeUseCase(
                candidateRepository: candidates,
                movieRepository: movies,
                availabilityRepository: availability
            )

            guard case let .usable(snapshot) = try await sut.load() else {
                Issue.record("Expected the page-twenty fixture to produce a usable set")
                return
            }

            #expect(await candidates.requestedPages == Array(1 ... 20))
            #expect(Set(snapshot.decisionSet.recommendations.map(\.display.movieID))
                == Set(movieIDs.suffix(3)))
        }
    #endif

    @Test("sanitized blocked v2 state survives prolonged feedback, refresh, and relaunch")
    func blockedUpgradeProlongedFeedbackAndRelaunch() async throws {
        let scenario = try makeScenario()
        defer {
            scenario.searchDefaults.removePersistentDomain(
                forName: scenario.searchSuite
            )
        }
        var runtime = makeRuntime(
            viewerFiles: scenario.viewerFiles,
            decisionStore: scenario.decisionStore,
            candidates: scenario.candidates,
            movies: scenario.movies,
            availability: scenario.availability
        )
        let snapshot = try await usableSnapshot(runtime.coordinator.load())

        #expect(snapshot.decisionSet.recommendations.count == 3)
        #expect(snapshot.decisionSet.cycle.history.allShownMovieIDs.isSuperset(
            of: scenario.fixture.shownMovieIDs
        ))
        #expect(scenario.viewerFiles.activeData != scenario.fixture.viewerStateV2)
        #expect(scenario.decisionStore.activeData != scenario.fixture.decisionSetV2)
        try await assertPreservedState(
            runtime: runtime,
            fixture: scenario.fixture,
            searchSuite: scenario.searchSuite
        )

        let prolonged = try await exerciseProlongedFeedback(
            runtime: runtime,
            snapshot: snapshot,
            scenario: scenario
        )
        runtime = prolonged.runtime

        let requestedBeforeExhaustion = await scenario.candidates.requestedPages.count
        guard case let .exhausted(exhaustion) = try await runtime.coordinator.refresh() else {
            Issue.record("Expected retained-set exhaustion after the sanitized sequence")
            return
        }
        #expect(exhaustion.snapshot.decisionSet.recommendations.count == 3)
        #expect(await scenario.candidates.requestedPages.count == requestedBeforeExhaustion + 1)

        _ = try await runtime.coordinator.refresh()
        #expect(await scenario.candidates.requestedPages.count == requestedBeforeExhaustion + 1)

        runtime = makeRuntime(
            viewerFiles: scenario.viewerFiles,
            decisionStore: scenario.decisionStore,
            candidates: scenario.candidates,
            movies: scenario.movies,
            availability: scenario.availability
        )
        guard case let .exhausted(relaunchedExhaustion) = try await runtime.coordinator.load() else {
            Issue.record("Expected persisted exhaustion after relaunch")
            return
        }
        #expect(relaunchedExhaustion.snapshot == exhaustion.snapshot)
        #expect(await scenario.candidates.requestedPages.count == requestedBeforeExhaustion + 1)

        let finalState = try await runtime.viewerState.snapshot()
        let finalHistory = relaunchedExhaustion.snapshot.decisionSet.cycle.history
        #expect(prolonged.feedbackMovieIDs.isSubset(
            of: ViewerMovieStateProjections.recommendationExcludedMovieIDs(from: finalState)
        ))
        #expect(scenario.fixture.shownMovieIDs.isSubset(of: finalHistory.allShownMovieIDs))
        #expect(finalHistory.recentlyShownMovieIDs.count <= 30)
        #expect(Set(finalHistory.recentlyShownMovieIDs).count == finalHistory.recentlyShownMovieIDs.count)
        try await assertPreservedState(
            runtime: runtime,
            fixture: scenario.fixture,
            searchSuite: scenario.searchSuite
        )
    }
}

private extension Milestone7P0ClosureIntegrationTests {
    private func exerciseProlongedFeedback(
        runtime initialRuntime: Runtime,
        snapshot initialSnapshot: ThreeForTonightSnapshot,
        scenario: Scenario
    ) async throws -> ProlongedResult {
        var runtime = initialRuntime
        var snapshot = initialSnapshot
        var feedbackMovieIDs = Set<Int>()
        for index in 0 ..< 42 {
            let previousMovieIDs = Set(
                snapshot.decisionSet.recommendations.map(\.display.movieID)
            )
            let movieID = try #require(
                snapshot.decisionSet.recommendations.first?.display.movieID
            )
            let action: ViewerMovieStateTransition.Action = switch index % 3 {
                case 0: .assignReaction(index.isMultiple(of: 2) ? .loveIt : .likeIt)
                case 1: .markWatched
                default: .setNotInterested
            }
            let change = try await runtime.viewerState.apply(
                ViewerMovieStateTransition(movieID: movieID, action: action),
                metadata: MovieFeedbackMetadata(
                    title: "Sanitized feedback \(index)",
                    releaseYear: 2024,
                    posterPath: nil
                )
            )
            feedbackMovieIDs.insert(movieID)
            let decisionChange = try #require(DecisionViewerStateChange(
                movieID: movieID,
                impact: change.impact,
                snapshotID: change.snapshotID
            ))
            snapshot = try await usableSnapshot(
                runtime.coordinator.reconcileAfterViewerStateChange(decisionChange)
            )

            let currentMovieIDs = Set(
                snapshot.decisionSet.recommendations.map(\.display.movieID)
            )
            #expect(snapshot.decisionSet.recommendations.count == 3)
            #expect(previousMovieIDs.subtracting([movieID]).isSubset(of: currentMovieIDs))
            try await assertNoExplicitExclusionIsVisible(runtime: runtime, snapshot: snapshot)

            if (index + 1).isMultiple(of: 7) {
                let beforeRefresh = currentMovieIDs
                snapshot = try await usableSnapshot(runtime.coordinator.refresh())
                let afterRefresh = Set(
                    snapshot.decisionSet.recommendations.map(\.display.movieID)
                )
                #expect(beforeRefresh.isDisjoint(with: afterRefresh))
                try await assertNoExplicitExclusionIsVisible(
                    runtime: runtime,
                    snapshot: snapshot
                )
            }

            if (index + 1).isMultiple(of: 10) {
                let beforeRelaunch = snapshot
                runtime = makeRuntime(
                    viewerFiles: scenario.viewerFiles,
                    decisionStore: scenario.decisionStore,
                    candidates: scenario.candidates,
                    movies: scenario.movies,
                    availability: scenario.availability
                )
                snapshot = try await usableSnapshot(runtime.coordinator.load())
                #expect(snapshot == beforeRelaunch)
            }
        }
        return ProlongedResult(
            runtime: runtime,
            feedbackMovieIDs: feedbackMovieIDs
        )
    }

    private func makeScenario() throws -> Scenario {
        let fixture = try makeBlockedFixture()
        let viewerFiles = InMemoryLocalViewerStateFileStore(activeData: fixture.viewerStateV2)
        let decisionStore = InMemoryDecisionSetDataStore(activeData: fixture.decisionSetV2)
        let candidateIDs = Array(3001 ... 3294)
        let candidates = try CoordinatorCandidateRepository(
            candidateBatchesByPage: [
                1: candidateIDs.chunked(into: 6).map { ids in
                    try ids.map(CoordinatorTestFixtures.candidate)
                },
            ]
        )
        let allMovieIDs = candidateIDs + Array(fixture.watchedMovieIDs)
        let movies = CoordinatorMovieRepository(movies: Dictionary(
            uniqueKeysWithValues: allMovieIDs.map {
                ($0, CoordinatorTestFixtures.movie($0))
            }
        ))
        let availability = CoordinatorAvailabilityRepository(
            evidenceByMovieID: Dictionary(uniqueKeysWithValues: candidateIDs.map {
                ($0, CoordinatorTestFixtures.evidence($0))
            })
        )
        let searchSuite = "PickOneTests.M7P0Closure.\(UUID().uuidString)"
        let searchDefaults = try #require(UserDefaults(suiteName: searchSuite))
        UserDefaultsLocalStore(suiteName: searchSuite).addSearchQuery("Sanitized Query")
        return Scenario(
            fixture: fixture,
            viewerFiles: viewerFiles,
            decisionStore: decisionStore,
            candidates: candidates,
            movies: movies,
            availability: availability,
            searchSuite: searchSuite,
            searchDefaults: searchDefaults
        )
    }

    private func assertPreservedState(
        runtime: Runtime,
        fixture: BlockedFixture,
        searchSuite: String
    ) async throws {
        let viewerSnapshot = try await runtime.viewerState.snapshot()
        let watchedMovieIDs = Set(
            viewerSnapshot.states.filter(\.watchState.isWatched).map(\.movieID)
        )
        #expect(fixture.watchedMovieIDs.isSubset(of: watchedMovieIDs))
        #expect(fixture.initialReactionMovieIDs.allSatisfy {
            viewerSnapshot.state(for: $0)?.reaction != nil
        })

        guard case let .completed(profile, draft) = await runtime.profile.loadState() else {
            Issue.record("Expected the completed profile to survive")
            return
        }
        #expect(profile.selectedServices == [.netflix])
        #expect(draft == nil)

        let watchlist = try await runtime.watchlist.loadAllItems()
        #expect(watchlist.map(\.id) == [fixture.watchlistMovieID])
        #expect(UserDefaultsLocalStore(suiteName: searchSuite).getSearchHistory()
            == ["Sanitized Query"])
    }

    private func assertNoExplicitExclusionIsVisible(
        runtime: Runtime,
        snapshot: ThreeForTonightSnapshot
    ) async throws {
        let viewerSnapshot = try await runtime.viewerState.snapshot()
        let visibleMovieIDs = Set(snapshot.decisionSet.recommendations.map(\.display.movieID))
        #expect(visibleMovieIDs.isDisjoint(
            with: ViewerMovieStateProjections.recommendationExcludedMovieIDs(from: viewerSnapshot)
        ))
    }

    private func makeRuntime(
        viewerFiles: InMemoryLocalViewerStateFileStore,
        decisionStore: InMemoryDecisionSetDataStore,
        candidates: CoordinatorCandidateRepository,
        movies: CoordinatorMovieRepository,
        availability: CoordinatorAvailabilityRepository
    ) -> Runtime {
        let viewerState = LocalViewerStateRepository(
            fileStore: viewerFiles,
            legacySource: InMemoryLegacyViewerStateSource(),
            now: { Date(timeIntervalSince1970: 1_700_100_000) }
        )
        let profile = LocalViewerProfileRepositoryAdapter(repository: viewerState)
        let decisionSet = DefaultDecisionSetRepository(store: decisionStore)
        let coordinator = ThreeForTonightCoordinator(
            viewerProfileRepository: profile,
            viewerMovieStateRepository: viewerState,
            decisionSetRepository: decisionSet,
            inputAssembler: AssembleDecisionEngineInput(
                candidateRepository: candidates,
                movieRepository: movies,
                availabilityRepository: availability
            ),
            movieRepository: movies,
            availabilityRepository: availability,
            signer: StableDecisionCycleSigner(),
            clock: FixedClock()
        )
        return Runtime(
            viewerState: viewerState,
            profile: profile,
            watchlist: LocalViewerStateWatchlistAdapter(repository: viewerState),
            coordinator: coordinator
        )
    }

    private func makeBlockedFixture() throws -> BlockedFixture {
        let snapshotID = try requiredUUID("80000000-0000-0000-0000-000000000001")
        let shownMovieIDs = Set(1001 ... 1093)
        let watchedMovieIDs = Set(1067 ... 1113)
        let initialReactionMovieIDs = Set(1067 ... 1074)
        let watchlistMovieID = 1200
        #expect(shownMovieIDs.count == 93)
        #expect(watchedMovieIDs.count == 47)
        #expect(shownMovieIDs.union(watchedMovieIDs).count == 113)

        let watchedStates = watchedMovieIDs.sorted().map { movieID in
            ViewerMovieStateV2DTO(
                movieID: movieID,
                title: "Sanitized watched \(movieID)",
                releaseYear: 2020,
                posterPath: nil,
                watchState: "watched",
                preference: initialReactionMovieIDs.contains(movieID)
                    ? ViewerMoviePreferenceV2DTO(kind: "reaction", reaction: "likeIt")
                    : nil,
                watchlistAddedAt: nil,
                stateChangedAt: Date(timeIntervalSince1970: 1_700_000_000)
            )
        }
        let watchlistState = ViewerMovieStateV2DTO(
            movieID: watchlistMovieID,
            title: "Sanitized watchlist",
            releaseYear: 2021,
            posterPath: nil,
            watchState: "unwatched",
            preference: nil,
            watchlistAddedAt: Date(timeIntervalSince1970: 1_700_000_000),
            stateChangedAt: Date(timeIntervalSince1970: 1_700_000_000)
        )
        let viewerEnvelope = LocalViewerStateEnvelopeV2DTO(
            envelopeSchemaVersion: LocalViewerStateEnvelopeV2DTO.schemaVersion,
            committedStateSnapshotID: snapshotID,
            viewerProfileState: LocalViewerProfileStateV2DTO(
                completedProfile: CompletedViewerProfileV2DTO(
                    profileSchemaVersion: CompletedViewerProfileV2DTO.schemaVersion,
                    lastCompletedCatalogReference: CalibrationCatalogReferenceV2DTO(
                        schemaVersion: 1,
                        catalogID: CalibrationCatalogID.spainHouseholdV1.rawValue,
                        version: 1,
                        regionCode: ViewingRegion.spain.code,
                        localeIdentifier: "es-ES"
                    ),
                    regionCode: ViewingRegion.spain.code,
                    selectedProviderIDs: [PilotStreamingService.netflix.providerID]
                ),
                profileDraft: nil
            ),
            viewerMovieStates: watchedStates + [watchlistState],
            migrationRecord: LocalViewerStateMigrationRecordV2DTO(
                source: .legacyMigration,
                resolvedAt: Date(timeIntervalSince1970: 1_700_000_000)
            )
        )
        let decisionEnvelope = try makeDecisionEnvelope(
            snapshotID: snapshotID,
            shownMovieIDs: shownMovieIDs,
            reactionMovieIDs: initialReactionMovieIDs
        )
        let decisionEncoder = JSONEncoder()
        decisionEncoder.outputFormatting = [.sortedKeys]
        decisionEncoder.dateEncodingStrategy = .millisecondsSince1970
        return try BlockedFixture(
            viewerStateV2: JSONLocalViewerStateEnvelopeCoder().encodeLegacyV2(viewerEnvelope),
            decisionSetV2: decisionEncoder.encode(decisionEnvelope),
            shownMovieIDs: shownMovieIDs,
            watchedMovieIDs: watchedMovieIDs,
            initialReactionMovieIDs: initialReactionMovieIDs,
            watchlistMovieID: watchlistMovieID
        )
    }

    private func makeDecisionEnvelope(
        snapshotID: UUID,
        shownMovieIDs: Set<Int>,
        reactionMovieIDs: Set<Int>
    ) throws -> DecisionSetEnvelopeV2DTO {
        let reactions = Dictionary(
            uniqueKeysWithValues: reactionMovieIDs.map { ($0, CalibrationReaction.likeIt) }
        )
        let profile = ViewerProfile(
            profileSchemaVersion: ViewerProfile.currentSchemaVersion,
            catalogID: .spainHouseholdV1,
            region: .spain,
            selectedServices: [.netflix],
            reactions: reactions
        )
        let signature = try StableDecisionCycleSigner().signature(
            for: DecisionCycleIdentity(engineModelVersion: .p1Model, profile: profile)
        )
        return try DecisionSetEnvelopeV2DTO(
            envelopeSchemaVersion: DecisionSetEnvelopeV2DTO.schemaVersion,
            decisionSetID: requiredUUID("80000000-0000-0000-0000-000000000002"),
            generatedAt: Date(timeIntervalSince1970: 1_700_000_000),
            engineModelVersion: DecisionEngineModelVersion.p1Model.rawValue,
            cycle: DecisionCycleV1DTO(
                id: requiredUUID("80000000-0000-0000-0000-000000000003"),
                identitySignature: signature.rawValue,
                shownMovieIDs: shownMovieIDs.sorted()
            ),
            sourceViewerStateSnapshotID: snapshotID,
            regionCode: ViewingRegion.spain.code,
            selectedProviderIDs: [PilotStreamingService.netflix.providerID],
            recommendations: []
        )
    }

    private func usableSnapshot(
        _ result: ThreeForTonightResult
    ) throws -> ThreeForTonightSnapshot {
        guard case let .usable(snapshot) = result else {
            Issue.record("Expected a usable recommendation set, got \(result)")
            throw M7P0ClosureIntegrationError.expectedUsableSnapshot
        }
        return snapshot
    }

    private func requiredUUID(_ value: String) throws -> UUID {
        guard let uuid = UUID(uuidString: value) else {
            throw M7P0ClosureIntegrationError.invalidFixture
        }
        return uuid
    }

    struct Scenario {
        let fixture: BlockedFixture
        let viewerFiles: InMemoryLocalViewerStateFileStore
        let decisionStore: InMemoryDecisionSetDataStore
        let candidates: CoordinatorCandidateRepository
        let movies: CoordinatorMovieRepository
        let availability: CoordinatorAvailabilityRepository
        let searchSuite: String
        let searchDefaults: UserDefaults
    }

    struct ProlongedResult {
        let runtime: Runtime
        let feedbackMovieIDs: Set<Int>
    }

    struct Runtime {
        let viewerState: LocalViewerStateRepository
        let profile: LocalViewerProfileRepositoryAdapter
        let watchlist: LocalViewerStateWatchlistAdapter
        let coordinator: ThreeForTonightCoordinator
    }

    struct BlockedFixture {
        let viewerStateV2: Data
        let decisionSetV2: Data
        let shownMovieIDs: Set<Int>
        let watchedMovieIDs: Set<Int>
        let initialReactionMovieIDs: Set<Int>
        let watchlistMovieID: Int
    }

    struct FixedClock: DecisionSetClock {
        func now() -> Date {
            Date(timeIntervalSince1970: 1_700_100_000)
        }
    }
}

private extension Array {
    func chunked(into size: Int) -> [[Element]] {
        stride(from: 0, to: count, by: size).map {
            Array(self[$0 ..< Swift.min($0 + size, count)])
        }
    }
}

private enum M7P0ClosureIntegrationError: Error {
    case expectedUsableSnapshot
    case invalidFixture
}

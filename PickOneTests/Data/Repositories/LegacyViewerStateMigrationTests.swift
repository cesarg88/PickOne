import Foundation
@testable import PickOne
import Testing

@Suite("Legacy Viewer State migration")
struct LegacyViewerStateMigrationTests {
    @Test("profile-only migration imports informative reactions and removes them from profile v2")
    func profileOnly() async throws {
        let id = try LocalViewerStateTestFixtures.uuid(LocalViewerStateTestFixtures.firstID)
        let reactions = Dictionary(
            uniqueKeysWithValues: CalibrationCatalog.spainHouseholdV1.movies.prefix(15).enumerated().map {
                index, movie in
                (movie.id, index < 4 ? CalibrationReaction.loveIt.rawValue : CalibrationReaction.doNotKnowIt.rawValue)
            }
        )
        let profileData = try encodeLegacy(
            completedProfile: completedProfile(reactions: reactions)
        )
        let files = InMemoryLocalViewerStateFileStore()

        let snapshot = try await repository(
            files: files,
            profileData: profileData,
            id: id
        ).snapshot()

        #expect(snapshot.states.count == 4)
        #expect(snapshot.states.allSatisfy { $0.reaction == .loveIt && $0.watchState == .watched })
        #expect(snapshot.states.allSatisfy { $0.watchlistIntent == nil })
        let envelope = try activeEnvelope(files)
        #expect(envelope.viewerProfileState.completedProfile?.selectedProviderIDs == [8, 337])
        #expect(envelope.viewerProfileState.completedProfile?.profileSchemaVersion == 2)
        #expect(envelope.migrationRecord.source == .legacyMigration)
    }

    @Test("watchlist-only migration preserves independent watched facts and future intent")
    func watchlistOnly() async throws {
        let id = try LocalViewerStateTestFixtures.uuid(LocalViewerStateTestFixtures.firstID)
        let earlier = LocalViewerStateTestFixtures.date.addingTimeInterval(-100)
        let items = [
            watchlistItem(movieID: 10, addedAt: earlier, isWatched: false),
            watchlistItem(movieID: 20, addedAt: LocalViewerStateTestFixtures.date, isWatched: true),
        ]
        let files = InMemoryLocalViewerStateFileStore()

        let snapshot = try await repository(
            files: files,
            watchlistData: JSONEncoder().encode(items),
            id: id
        ).snapshot()

        let futureIntent = try #require(snapshot.state(for: 10))
        #expect(futureIntent.watchState == .unwatched)
        #expect(futureIntent.watchlistIntent?.addedAt == earlier)
        #expect(futureIntent.stateChangedAt == earlier)
        let watched = try #require(snapshot.state(for: 20))
        #expect(watched.watchState == .watched)
        #expect(watched.watchlistIntent == nil)
        #expect(watched.stateChangedAt == LocalViewerStateTestFixtures.date)
    }

    @Test("reaction and watched evidence win over conflicting legacy Watchlist membership")
    func overlappingEvidence() async throws {
        let id = try LocalViewerStateTestFixtures.uuid(LocalViewerStateTestFixtures.firstID)
        let movie = CalibrationCatalog.spainHouseholdV1.movies[0]
        let reactions = completedReactionPrefix(overriding: [movie.id: .likeIt])
        let profileData = try encodeLegacy(
            completedProfile: completedProfile(reactions: reactions.mapValues(\.rawValue))
        )
        let watchlistData = try JSONEncoder().encode([
            PersistedWatchlistItem(
                movieId: movie.id,
                title: "Stronger offline title",
                posterPath: "/stronger.jpg",
                releaseYear: movie.year,
                rating: 9,
                addedAt: LocalViewerStateTestFixtures.date.addingTimeInterval(-500),
                isWatched: false
            ),
        ])

        let state = try #require(
            try await repository(
                files: InMemoryLocalViewerStateFileStore(),
                profileData: profileData,
                watchlistData: watchlistData,
                id: id
            ).state(movieID: movie.id)
        )

        #expect(state.reaction == .likeIt)
        #expect(state.watchState == .watched)
        #expect(state.watchlistIntent == nil)
        #expect(state.displayMetadata.title == "Stronger offline title")
        #expect(state.displayMetadata.posterPath == "/stronger.jpg")
        #expect(state.stateChangedAt == LocalViewerStateTestFixtures.date)
    }

    @Test("valid empty legacy sources migrate explicitly rather than masquerading as fresh absence")
    func emptyValidLegacy() async throws {
        let id = try LocalViewerStateTestFixtures.uuid(LocalViewerStateTestFixtures.firstID)
        let profileData = try encodeLegacy()
        let files = InMemoryLocalViewerStateFileStore()

        let snapshot = try await repository(
            files: files,
            profileData: profileData,
            watchlistData: JSONEncoder().encode([PersistedWatchlistItem]()),
            id: id
        ).snapshot()

        #expect(snapshot.states.isEmpty)
        #expect(try activeEnvelope(files).migrationRecord.source == .legacyMigration)
    }

    @Test("first-onboarding draft freezes the exact supported catalog without publishing draft reactions")
    func firstOnboardingDraft() async throws {
        let id = try LocalViewerStateTestFixtures.uuid(LocalViewerStateTestFixtures.firstID)
        let movies = CalibrationCatalog.spainHouseholdV1.movies
        let draft = ViewerProfileDraftV1DTO(
            kind: .firstOnboarding,
            firstOnboarding: FirstOnboardingDraftV1DTO(
                calibrationCatalogVersion: CalibrationCatalogID.spainHouseholdV1.rawValue,
                currentStep: FirstOnboardingStep.calibration.rawValue,
                selectedProviderIDs: [8],
                reactionsByMovieID: [
                    movies[0].id: CalibrationReaction.loveIt.rawValue,
                    movies[1].id: CalibrationReaction.haveNotSeenIt.rawValue,
                ],
                currentCatalogPosition: 2,
                optionalExtensionAccepted: false
            ),
            recalibration: nil
        )
        let files = InMemoryLocalViewerStateFileStore()

        let snapshot = try await repository(
            files: files,
            profileData: encodeLegacy(draft: draft),
            id: id
        ).snapshot()

        #expect(snapshot.states.isEmpty)
        let migratedDraft = try #require(try activeEnvelope(files).viewerProfileState.profileDraft)
        #expect(migratedDraft.kind == .firstOnboarding)
        #expect(migratedDraft.currentCatalogPosition == 2)
        #expect(migratedDraft.reactionsByMovieID.count == 2)
        #expect(migratedDraft.frozenCatalog.reference.schemaVersion == 1)
        #expect(migratedDraft.frozenCatalog.reference.catalogID == "es-household-calibration")
        #expect(migratedDraft.frozenCatalog.reference.version == 1)
        #expect(migratedDraft.frozenCatalog.reference.regionCode == "ES")
        #expect(migratedDraft.frozenCatalog.reference.localeIdentifier == "es-ES")
        #expect(migratedDraft.frozenCatalog.updatedAt == Date(timeIntervalSince1970: 1_787_097_600))
        #expect(migratedDraft.frozenCatalog.movies.map(\.order) == Array(0 ..< movies.count))
        #expect(migratedDraft.frozenCatalog.movies.map(\.movieID) == movies.map(\.id))
    }

    @Test("recalibration draft remains separate from migrated current reactions")
    func recalibrationDraft() async throws {
        let id = try LocalViewerStateTestFixtures.uuid(LocalViewerStateTestFixtures.firstID)
        let movies = CalibrationCatalog.spainHouseholdV1.movies
        let profileReactions = completedReactionPrefix(overriding: [movies[0].id: .loveIt])
        let draft = ViewerProfileDraftV1DTO(
            kind: .recalibration,
            firstOnboarding: nil,
            recalibration: RecalibrationDraftV1DTO(
                calibrationCatalogVersion: CalibrationCatalogID.spainHouseholdV1.rawValue,
                reactionsByMovieID: [movies[0].id: CalibrationReaction.didNotLikeIt.rawValue],
                currentCatalogPosition: 1,
                optionalExtensionAccepted: false
            )
        )
        let profileData = try encodeLegacy(
            completedProfile: completedProfile(reactions: profileReactions.mapValues(\.rawValue)),
            draft: draft
        )
        let files = InMemoryLocalViewerStateFileStore()

        let state = try #require(
            try await repository(files: files, profileData: profileData, id: id)
                .state(movieID: movies[0].id)
        )

        #expect(state.reaction == .loveIt)
        let migratedDraft = try #require(try activeEnvelope(files).viewerProfileState.profileDraft)
        #expect(migratedDraft.kind == .recalibration)
        #expect(migratedDraft.reactionsByMovieID[movies[0].id] == "didNotLikeIt")
    }

    @Test("unknown legacy catalog versions fail the whole migration")
    func unknownCatalog() async throws {
        let id = try LocalViewerStateTestFixtures.uuid(LocalViewerStateTestFixtures.firstID)
        let profile = ViewerProfileV1DTO(
            profileSchemaVersion: 1,
            calibrationCatalogVersion: "unknown-catalog",
            regionCode: "ES",
            selectedProviderIDs: [8],
            reactionsByMovieID: [:]
        )
        let files = InMemoryLocalViewerStateFileStore()
        let profileData = try encodeLegacy(completedProfile: profile)

        #expect(
            await repository(
                files: files,
                profileData: profileData,
                id: id
            ).loadState() == .recovery(.migrationFailure)
        )
        #expect(files.activeData == nil)
    }

    @Test("duplicate and invalid Watchlist records fail closed")
    func invalidWatchlist() async throws {
        let id = try LocalViewerStateTestFixtures.uuid(LocalViewerStateTestFixtures.firstID)
        let duplicate = watchlistItem(
            movieID: 10,
            addedAt: LocalViewerStateTestFixtures.date,
            isWatched: false
        )
        let invalid = PersistedWatchlistItem(
            movieId: -1,
            title: "Invalid",
            posterPath: nil,
            releaseYear: nil,
            rating: 0,
            addedAt: LocalViewerStateTestFixtures.date,
            isWatched: false
        )

        for items in [[duplicate, duplicate], [invalid]] {
            let files = InMemoryLocalViewerStateFileStore()
            let watchlistData = try JSONEncoder().encode(items)
            #expect(
                await repository(
                    files: files,
                    watchlistData: watchlistData,
                    id: id
                ).loadState() == .recovery(.migrationFailure)
            )
            #expect(files.activeData == nil)
        }
    }

    @Test("migration reads legacy bytes without modifying them or Search History")
    func legacySourcesRemainReadOnly() async throws {
        let id = try LocalViewerStateTestFixtures.uuid(LocalViewerStateTestFixtures.firstID)
        let suiteName = "PickOneTests.LegacyViewerState.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let profileData = try encodeLegacy()
        let watchlistData = try JSONEncoder().encode([
            watchlistItem(
                movieID: 10,
                addedAt: LocalViewerStateTestFixtures.date,
                isWatched: false
            ),
        ])
        let searchHistory = ["Arrival", "Heat"]
        defaults.set(profileData, forKey: UserDefaultsViewerProfileDataStore.storageKey)
        defaults.set(watchlistData, forKey: "watchlist_items_v2")
        defaults.set(searchHistory, forKey: "search_history")
        let files = InMemoryLocalViewerStateFileStore()

        let legacySource = UserDefaultsLegacyViewerStateSource(suiteName: suiteName)
        let repository = try LocalViewerStateRepository(
            fileStore: files,
            legacySource: legacySource,
            legacyResetter: legacySource,
            snapshotID: SequenceUUIDGenerator([
                id,
                LocalViewerStateTestFixtures.uuid(LocalViewerStateTestFixtures.secondID),
            ]).next,
            now: { LocalViewerStateTestFixtures.date }
        )

        _ = try await repository.snapshot()
        _ = try await repository.apply(
            ViewerMovieStateTransition(movieID: 20, action: .saveToWatchlist),
            metadata: LocalViewerStateTestFixtures.metadata()
        )

        #expect(defaults.data(forKey: UserDefaultsViewerProfileDataStore.storageKey) == profileData)
        #expect(defaults.data(forKey: "watchlist_items_v2") == watchlistData)
        #expect(defaults.stringArray(forKey: "search_history") == searchHistory)
        #expect(await repository.successfulRecoveryNotice() == nil)
    }

    private func repository(
        files: InMemoryLocalViewerStateFileStore,
        profileData: Data? = nil,
        watchlistData: Data? = nil,
        id: UUID
    ) -> LocalViewerStateRepository {
        LocalViewerStateRepository(
            fileStore: files,
            legacySource: InMemoryLegacyViewerStateSource(
                profileData: profileData,
                watchlistData: watchlistData
            ),
            snapshotID: { id },
            now: { LocalViewerStateTestFixtures.date }
        )
    }

    private func encodeLegacy(
        completedProfile: ViewerProfileV1DTO? = nil,
        draft: ViewerProfileDraftV1DTO? = nil
    ) throws -> Data {
        try JSONViewerProfileEnvelopeCoder().encodeEnvelope(
            ViewerStateEnvelopeV1DTO(
                envelopeSchemaVersion: ViewerStateEnvelopeV1DTO.schemaVersion,
                completedProfile: completedProfile,
                profileDraft: draft
            )
        )
    }

    private func completedProfile(reactions: [Int: String]) -> ViewerProfileV1DTO {
        ViewerProfileV1DTO(
            profileSchemaVersion: 1,
            calibrationCatalogVersion: CalibrationCatalogID.spainHouseholdV1.rawValue,
            regionCode: "ES",
            selectedProviderIDs: [8, 337],
            reactionsByMovieID: reactions
        )
    }

    private func completedReactionPrefix(
        overriding: [Int: CalibrationReaction]
    ) -> [Int: CalibrationReaction] {
        Dictionary(
            uniqueKeysWithValues: CalibrationCatalog.spainHouseholdV1.movies.prefix(8).map {
                ($0.id, overriding[$0.id] ?? .likeIt)
            }
        )
    }

    private func watchlistItem(
        movieID: Int,
        addedAt: Date,
        isWatched: Bool
    ) -> PersistedWatchlistItem {
        PersistedWatchlistItem(
            movieId: movieID,
            title: "Movie \(movieID)",
            posterPath: "/poster.jpg",
            releaseYear: 2024,
            rating: 8,
            addedAt: addedAt,
            isWatched: isWatched
        )
    }

    private func activeEnvelope(
        _ files: InMemoryLocalViewerStateFileStore
    ) throws -> LocalViewerStateEnvelopeV3DTO {
        let decoded = try JSONLocalViewerStateEnvelopeCoder().decode(#require(files.activeData))
        guard case let .currentV3(envelope) = decoded else {
            throw LocalViewerStateTestError.rejected
        }
        return envelope
    }
}

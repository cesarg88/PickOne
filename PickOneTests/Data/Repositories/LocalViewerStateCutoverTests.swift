import Foundation
@testable import PickOne
import Testing

@Suite("Local Viewer State cutover")
struct LocalViewerStateCutoverTests {
    @Test("first onboarding completion commits profile and informative reactions together")
    func firstOnboardingCompletionIsAtomic() async throws {
        let firstID = try LocalViewerStateTestFixtures.uuid(LocalViewerStateTestFixtures.firstID)
        let secondID = try LocalViewerStateTestFixtures.uuid(LocalViewerStateTestFixtures.secondID)
        let draft = firstCompletionDraft()
        let active = try LocalViewerStateTestFixtures.encoded(
            envelope(id: firstID, profileDraft: draft)
        )
        let files = InMemoryLocalViewerStateFileStore(activeData: active)
        let stateRepository = repository(files: files, ids: [secondID])
        let repository = LocalViewerProfileRepositoryAdapter(repository: stateRepository)

        let profile = try await repository.completeFirstOnboarding()

        #expect(profile.selectedServices.map(\.providerID) == [8])
        #expect(profile.reactions.count == 8)
        #expect(profile.reactions[CalibrationCatalog.spainHouseholdV1.movies[0].id] == .loveIt)
        let persisted = try activeEnvelope(files)
        #expect(persisted.committedStateSnapshotID == secondID)
        #expect(persisted.viewerProfileState.completedProfile != nil)
        #expect(persisted.viewerProfileState.profileDraft == nil)
        #expect(persisted.viewerMovieStates.count == 8)
        #expect(persisted.viewerMovieStates.allSatisfy { $0.watchState == "watched" })
        #expect(files.previousData == active)

        let relaunched = LocalViewerProfileRepositoryAdapter(
            repository: self.repository(files: files, ids: [])
        )
        #expect(await relaunched.loadState() == .completed(profile: profile, recalibrationDraft: nil))
    }

    @Test("failed first completion leaves the completed draft authoritative")
    func failedFirstCompletionPreservesDraft() async throws {
        let firstID = try LocalViewerStateTestFixtures.uuid(LocalViewerStateTestFixtures.firstID)
        let secondID = try LocalViewerStateTestFixtures.uuid(LocalViewerStateTestFixtures.secondID)
        let active = try LocalViewerStateTestFixtures.encoded(
            envelope(id: firstID, profileDraft: firstCompletionDraft())
        )
        let files = InMemoryLocalViewerStateFileStore(activeData: active)
        files.rejectActiveReplacement = true
        let stateRepository = repository(files: files, ids: [secondID])
        let repository = LocalViewerProfileRepositoryAdapter(repository: stateRepository)

        await #expect(throws: ViewerProfileRepositoryError.storageFailed) {
            _ = try await repository.completeFirstOnboarding()
        }

        #expect(files.activeData == active)
        let relaunchedState = self.repository(files: files, ids: [])
        let relaunched = LocalViewerProfileRepositoryAdapter(repository: relaunchedState)
        guard case .firstOnboarding = await relaunched.loadState() else {
            Issue.record("Expected the completed onboarding draft to survive")
            return
        }
        #expect(try await relaunchedState.snapshot().states.isEmpty)
    }

    @Test("recalibration upserts informative responses and preserves unrelated current state")
    func recalibrationUpsertsOnlyInformativeResponses() async throws {
        let firstID = try LocalViewerStateTestFixtures.uuid(LocalViewerStateTestFixtures.firstID)
        let secondID = try LocalViewerStateTestFixtures.uuid(LocalViewerStateTestFixtures.secondID)
        let catalog = CalibrationCatalog.spainHouseholdV1
        let existingReaction = try viewerState(
            movie: catalog.movies[0],
            reaction: .loveIt,
            changedAt: LocalViewerStateTestFixtures.date
        )
        let omittedReaction = try viewerState(
            movie: catalog.movies[20],
            reaction: .likeIt,
            changedAt: LocalViewerStateTestFixtures.date
        )
        let draft = recalibrationCompletionDraft()
        let active = try LocalViewerStateTestFixtures.encoded(
            envelope(
                id: firstID,
                completedProfile: completedProfile(providerIDs: [8]),
                profileDraft: draft,
                states: [existingReaction, omittedReaction]
            )
        )
        let files = InMemoryLocalViewerStateFileStore(activeData: active)
        let stateRepository = repository(files: files, ids: [secondID])
        let repository = LocalViewerProfileRepositoryAdapter(repository: stateRepository)

        let profile = try await repository.completeRecalibration()

        #expect(profile.selectedServices.map(\.providerID) == [8])
        #expect(profile.reactions[catalog.movies[0].id] == .didNotLikeIt)
        #expect(profile.reactions[catalog.movies[1].id] == nil)
        #expect(profile.reactions[catalog.movies[20].id] == .likeIt)
        let snapshot = try await stateRepository.snapshot()
        #expect(snapshot.state(for: catalog.movies[0].id)?.reaction == .didNotLikeIt)
        #expect(snapshot.state(for: catalog.movies[1].id) == nil)
        #expect(snapshot.state(for: catalog.movies[20].id)?.reaction == .likeIt)
        #expect(snapshot.id.rawValue == secondID)
    }

    @Test("service edits preserve recalibration progress and replace one v2 envelope")
    func serviceEditPreservesDraft() async throws {
        let firstID = try LocalViewerStateTestFixtures.uuid(LocalViewerStateTestFixtures.firstID)
        let secondID = try LocalViewerStateTestFixtures.uuid(LocalViewerStateTestFixtures.secondID)
        let draft = recalibrationCompletionDraft()
        let active = try LocalViewerStateTestFixtures.encoded(
            envelope(
                id: firstID,
                completedProfile: completedProfile(providerIDs: [8]),
                profileDraft: draft
            )
        )
        let files = InMemoryLocalViewerStateFileStore(activeData: active)
        let stateRepository = repository(files: files, ids: [secondID])
        let repository = LocalViewerProfileRepositoryAdapter(repository: stateRepository)
        let replacementService = try #require(
            PilotStreamingService.allowlist.first { $0.providerID != 8 }
        )

        let profile = try await repository.updateServices([replacementService])

        #expect(profile.selectedServices == [replacementService])
        let persisted = try activeEnvelope(files)
        #expect(persisted.committedStateSnapshotID == secondID)
        #expect(persisted.viewerProfileState.profileDraft == draft)
        #expect(persisted.viewerProfileState.completedProfile?.selectedProviderIDs == [
            replacementService.providerID,
        ])
        #expect(files.previousData == active)
    }

    @Test("normal preference reset preserves watched facts and Watchlist intent")
    func preferenceResetScope() async throws {
        let firstID = try LocalViewerStateTestFixtures.uuid(LocalViewerStateTestFixtures.firstID)
        let secondID = try LocalViewerStateTestFixtures.uuid(LocalViewerStateTestFixtures.secondID)
        let catalog = CalibrationCatalog.spainHouseholdV1
        let rated = try viewerState(
            movie: catalog.movies[0],
            reaction: .loveIt,
            changedAt: LocalViewerStateTestFixtures.date
        )
        let rejected = try ViewerMovieState(
            movieID: catalog.movies[1].id,
            displayMetadata: metadata(for: catalog.movies[1]),
            watchState: .unwatched,
            preference: .notInterested,
            watchlistIntent: nil,
            stateChangedAt: LocalViewerStateTestFixtures.date
        )
        let saved = try ViewerMovieState(
            movieID: catalog.movies[2].id,
            displayMetadata: metadata(for: catalog.movies[2]),
            watchState: .unwatched,
            preference: nil,
            watchlistIntent: WatchlistIntent(addedAt: LocalViewerStateTestFixtures.date),
            stateChangedAt: LocalViewerStateTestFixtures.date
        )
        let active = try LocalViewerStateTestFixtures.encoded(
            envelope(
                id: firstID,
                completedProfile: completedProfile(providerIDs: [8]),
                states: [rated, rejected, saved]
            )
        )
        let files = InMemoryLocalViewerStateFileStore(activeData: active)
        let stateRepository = repository(files: files, ids: [secondID])
        let repository = LocalViewerProfileRepositoryAdapter(repository: stateRepository)

        try await repository.resetProfileAndDraft()

        #expect(await repository.loadState() == .absent)
        let snapshot = try await stateRepository.snapshot()
        #expect(snapshot.id.rawValue == secondID)
        #expect(snapshot.state(for: rated.movieID)?.watchState == .watched)
        #expect(snapshot.state(for: rated.movieID)?.preference == nil)
        #expect(snapshot.state(for: rejected.movieID) == nil)
        #expect(snapshot.state(for: saved.movieID)?.watchlistIntent != nil)
    }

    @Test("Watchlist adapter derives future-intent rows only from v2")
    func finalWatchlistProjection() async throws {
        let firstID = try LocalViewerStateTestFixtures.uuid(LocalViewerStateTestFixtures.firstID)
        let catalog = CalibrationCatalog.spainHouseholdV1
        let watched = try viewerState(
            movie: catalog.movies[0],
            reaction: .loveIt,
            changedAt: LocalViewerStateTestFixtures.date
        )
        let saved = try ViewerMovieState(
            movieID: catalog.movies[1].id,
            displayMetadata: metadata(for: catalog.movies[1]),
            watchState: .unwatched,
            preference: nil,
            watchlistIntent: WatchlistIntent(addedAt: LocalViewerStateTestFixtures.laterDate),
            stateChangedAt: LocalViewerStateTestFixtures.laterDate
        )
        let rejected = try ViewerMovieState(
            movieID: catalog.movies[2].id,
            displayMetadata: metadata(for: catalog.movies[2]),
            watchState: .unwatched,
            preference: .notInterested,
            watchlistIntent: nil,
            stateChangedAt: LocalViewerStateTestFixtures.date
        )
        let files = try InMemoryLocalViewerStateFileStore(activeData: LocalViewerStateTestFixtures.encoded(
            envelope(id: firstID, states: [watched, saved, rejected])
        ))
        let repository = LocalViewerStateWatchlistAdapter(
            repository: repository(files: files, ids: [])
        )

        let items = try await repository.loadAllItems()

        #expect(items.map(\.id) == [saved.movieID])
        #expect(!items.contains { $0.id == watched.movieID })
        #expect(!items.contains { $0.id == rejected.movieID })
    }

    @Test("Watchlist mutations use accepted unified-state transitions")
    func watchlistMutationsUseUnifiedState() async throws {
        let firstID = try LocalViewerStateTestFixtures.uuid(LocalViewerStateTestFixtures.firstID)
        let secondID = try LocalViewerStateTestFixtures.uuid(LocalViewerStateTestFixtures.secondID)
        let thirdID = try LocalViewerStateTestFixtures.uuid(LocalViewerStateTestFixtures.thirdID)
        let files = InMemoryLocalViewerStateFileStore()
        let stateRepository = repository(files: files, ids: [firstID, secondID, thirdID])
        let repository = LocalViewerStateWatchlistAdapter(repository: stateRepository)
        let updateViewerState = UpdateViewerMovieState(repository: stateRepository)
        let movie = MovieSummary(
            id: 500,
            title: "Arrival",
            posterPath: "/arrival.jpg",
            releaseYear: 2016,
            rating: 8
        )
        let feedbackMetadata = try MovieFeedbackMetadata(
            title: movie.title,
            releaseYear: movie.releaseYear,
            posterPath: movie.posterPath
        )

        let saved = try await repository.setMembership(
            movie: movie,
            isInWatchlist: true
        )
        #expect(saved == WatchlistMutationOutcome(status: .toWatch, didChange: true))

        let watched = try await updateViewerState.execute(
            transition: ViewerMovieStateTransition(
                movieID: movie.id,
                action: .markWatched
            ),
            metadata: feedbackMetadata
        )
        #expect(watched.impact == .eligibilityChanged)
        #expect(try await stateRepository.state(movieID: movie.id)?.watchlistIntent == nil)

        let unwatched = try await updateViewerState.execute(
            transition: ViewerMovieStateTransition(
                movieID: movie.id,
                action: .markUnwatched
            ),
            metadata: feedbackMetadata
        )
        #expect(unwatched.impact == .eligibilityChanged)
        #expect(try await stateRepository.state(movieID: movie.id) == nil)
    }

    @Test("My movies use case reads the deterministic v2 projection")
    func myMoviesUseCaseProjection() async throws {
        let firstID = try LocalViewerStateTestFixtures.uuid(LocalViewerStateTestFixtures.firstID)
        let catalog = CalibrationCatalog.spainHouseholdV1
        let older = try viewerState(
            movie: catalog.movies[0],
            reaction: .loveIt,
            changedAt: LocalViewerStateTestFixtures.date
        )
        let newer = try ViewerMovieState(
            movieID: catalog.movies[1].id,
            displayMetadata: metadata(for: catalog.movies[1]),
            watchState: .watched,
            preference: nil,
            watchlistIntent: nil,
            stateChangedAt: LocalViewerStateTestFixtures.laterDate
        )
        let files = try InMemoryLocalViewerStateFileStore(activeData: LocalViewerStateTestFixtures.encoded(
            envelope(id: firstID, states: [older, newer])
        ))
        let useCase = GetMyMovies(repository: repository(files: files, ids: []))

        let states = try await useCase.execute()

        #expect(states.map(\.movieID) == [newer.movieID, older.movieID])
    }

    private func repository(
        files: InMemoryLocalViewerStateFileStore,
        ids: [UUID]
    ) -> LocalViewerStateRepository {
        let sequence = SequenceUUIDGenerator(ids)
        return LocalViewerStateRepository(
            fileStore: files,
            legacySource: InMemoryLegacyViewerStateSource(),
            snapshotID: { sequence.next() },
            now: { LocalViewerStateTestFixtures.laterDate }
        )
    }

    private func activeEnvelope(
        _ files: InMemoryLocalViewerStateFileStore
    ) throws -> LocalViewerStateEnvelopeV2DTO {
        try JSONLocalViewerStateEnvelopeCoder().decode(#require(files.activeData))
    }

    private func envelope(
        id: UUID,
        completedProfile: CompletedViewerProfileV2DTO? = nil,
        profileDraft: ViewerProfileDraftV2DTO? = nil,
        states: [ViewerMovieState] = []
    ) -> LocalViewerStateEnvelopeV2DTO {
        LocalViewerStateEnvelopeV2DTO(
            envelopeSchemaVersion: LocalViewerStateEnvelopeV2DTO.schemaVersion,
            committedStateSnapshotID: id,
            viewerProfileState: LocalViewerProfileStateV2DTO(
                completedProfile: completedProfile,
                profileDraft: profileDraft
            ),
            viewerMovieStates: states.map(LocalViewerStateEnvelopeMapper().map),
            migrationRecord: LocalViewerStateMigrationRecordV2DTO(
                source: .freshInstall,
                resolvedAt: LocalViewerStateTestFixtures.date
            )
        )
    }

    private func completedProfile(providerIDs: [Int]) -> CompletedViewerProfileV2DTO {
        CompletedViewerProfileV2DTO(
            profileSchemaVersion: CompletedViewerProfileV2DTO.schemaVersion,
            lastCompletedCatalogReference: LocalViewerStateTestFixtures.catalogReference(),
            regionCode: "ES",
            selectedProviderIDs: providerIDs
        )
    }

    private func firstCompletionDraft() -> ViewerProfileDraftV2DTO {
        let catalog = CalibrationCatalog.spainHouseholdV1
        let responses = Dictionary(
            uniqueKeysWithValues: catalog.movies.prefix(15).enumerated().map { index, movie in
                (movie.id, index < 8 ? CalibrationReaction.loveIt.rawValue : CalibrationReaction.haveNotSeenIt.rawValue)
            }
        )
        return profileDraft(
            kind: .firstOnboarding,
            step: .completion,
            selectedProviderIDs: [8],
            responses: responses,
            position: 15
        )
    }

    private func recalibrationCompletionDraft() -> ViewerProfileDraftV2DTO {
        let catalog = CalibrationCatalog.spainHouseholdV1
        let responses = Dictionary(
            uniqueKeysWithValues: catalog.movies.prefix(15).enumerated().map { index, movie in
                let reaction: CalibrationReaction = switch index {
                    case 0: .didNotLikeIt
                    case 1: .haveNotSeenIt
                    default: .doNotKnowIt
                }
                return (movie.id, reaction.rawValue)
            }
        )
        return profileDraft(
            kind: .recalibration,
            step: nil,
            selectedProviderIDs: nil,
            responses: responses,
            position: 15
        )
    }

    private func profileDraft(
        kind: ViewerProfileDraftV2DTO.Kind,
        step: FirstOnboardingStep?,
        selectedProviderIDs: [Int]?,
        responses: [Int: String],
        position: Int
    ) -> ViewerProfileDraftV2DTO {
        let catalog = CalibrationCatalog.spainHouseholdV1
        return ViewerProfileDraftV2DTO(
            kind: kind,
            frozenCatalog: FrozenCalibrationCatalogV2DTO(
                reference: LocalViewerStateTestFixtures.catalogReference(),
                updatedAt: LocalViewerStateTestFixtures.date,
                movies: catalog.movies.enumerated().map { order, movie in
                    FrozenCalibrationMovieV2DTO(
                        order: order,
                        movieID: movie.id,
                        titleKnownInSpain: movie.titleKnownInSpain,
                        originalOrEnglishTitle: movie.originalOrEnglishTitle,
                        year: movie.year,
                        originalLanguage: movie.originalLanguage,
                        block: movie.block.rawValue
                    )
                }
            ),
            currentStep: step?.rawValue,
            selectedProviderIDs: selectedProviderIDs,
            reactionsByMovieID: responses,
            currentCatalogPosition: position,
            optionalExtensionAccepted: false,
            catalogIsFrozen: true
        )
    }

    private func viewerState(
        movie: CalibrationMovie,
        reaction: MovieReaction,
        changedAt: Date
    ) throws -> ViewerMovieState {
        try ViewerMovieState(
            movieID: movie.id,
            displayMetadata: metadata(for: movie),
            watchState: .watched,
            preference: .reaction(reaction),
            watchlistIntent: nil,
            stateChangedAt: changedAt
        )
    }

    private func metadata(for movie: CalibrationMovie) throws -> MovieFeedbackMetadata {
        try MovieFeedbackMetadata(
            title: movie.titleKnownInSpain,
            releaseYear: movie.year,
            posterPath: nil
        )
    }
}

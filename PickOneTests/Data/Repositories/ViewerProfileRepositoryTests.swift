import Foundation
@testable import PickOne
import Testing

@Suite("Viewer profile repository tests")
struct ViewerProfileRepositoryTests {
    @Test("absent storage begins and deterministically resumes first onboarding")
    func firstOnboardingResume() async throws {
        let store = InMemoryViewerProfileDataStore()
        let repository = DefaultViewerProfileRepository(store: store)

        #expect(await repository.loadState() == .absent)
        let empty = try await repository.beginFirstOnboarding(
            catalog: ViewerProfileTestFixtures.catalog
        )
        let selected = FirstOnboardingDraft(
            catalogID: empty.catalogID,
            step: .services,
            selectedServices: [.netflix, .disneyPlus],
            reactions: [:],
            currentCatalogPosition: 0,
            optionalExtensionAccepted: false
        )
        try await repository.saveFirstOnboardingDraft(selected)

        let reloaded = DefaultViewerProfileRepository(store: store)
        #expect(await reloaded.loadState() == .firstOnboarding(selected))
        #expect(store.replacementCount == 2)
    }

    @Test("first completion replaces draft with one completed profile envelope")
    func firstCompletion() async throws {
        let store = InMemoryViewerProfileDataStore()
        let repository = DefaultViewerProfileRepository(store: store)
        let profile = try await ViewerProfileTestFixtures.completedProfile(
            in: repository,
            services: [.netflix, .hboMax]
        )

        #expect(profile.informativeSignalCount == 8)
        #expect(
            await repository.loadState()
                == .completed(profile: profile, recalibrationDraft: nil)
        )
        let encoded = try #require(store.data)
        let json = try #require(String(data: encoded, encoding: .utf8))
        #expect(!json.contains("informativeSignalCount"))
        #expect(!json.contains("completedOnboarding"))
        #expect(!json.contains("isComplete"))
    }

    @Test("recalibration draft is calibration-only in persisted schema")
    func recalibrationDTOHasNoViewingContext() async throws {
        let store = InMemoryViewerProfileDataStore()
        let repository = DefaultViewerProfileRepository(store: store)
        _ = try await ViewerProfileTestFixtures.completedProfile(in: repository)

        _ = try await repository.beginRecalibration(
            catalog: ViewerProfileTestFixtures.catalog
        )

        let data = try #require(store.data)
        let dto = try JSONViewerProfileEnvelopeCoder().decodeEnvelope(from: data)
        let recalibration = try #require(dto.profileDraft?.recalibration)
        #expect(dto.profileDraft?.firstOnboarding == nil)
        #expect(recalibration.currentCatalogPosition == 0)
        let draftJSON = try JSONEncoder().encode(recalibration)
        let json = try #require(String(data: draftJSON, encoding: .utf8))
        #expect(!json.contains("region"))
        #expect(!json.contains("Provider"))
    }

    @Test("service changes during recalibration remain authoritative on completion")
    func recalibrationUsesCurrentServices() async throws {
        let store = InMemoryViewerProfileDataStore()
        let repository = DefaultViewerProfileRepository(store: store)
        _ = try await ViewerProfileTestFixtures.completedProfile(
            in: repository,
            services: [.netflix]
        )
        _ = try await repository.beginRecalibration(
            catalog: ViewerProfileTestFixtures.catalog
        )
        _ = try await repository.updateServices([.disneyPlus])
        try await repository.saveRecalibrationDraft(
            ViewerProfileTestFixtures.recalibrationDraft()
        )

        let replacement = try await repository.completeRecalibration()

        #expect(replacement.selectedServices == [.disneyPlus])
        #expect(replacement.reactions.values.allSatisfy { $0 == .likeIt })
        #expect(
            await repository.loadState()
                == .completed(profile: replacement, recalibrationDraft: nil)
        )
    }

    @Test("concurrent service edit cannot be restored by recalibration completion")
    func concurrentServiceEditWins() async throws {
        let repository = DefaultViewerProfileRepository(
            store: InMemoryViewerProfileDataStore()
        )
        _ = try await ViewerProfileTestFixtures.completedProfile(
            in: repository,
            services: [.netflix]
        )
        _ = try await repository.beginRecalibration(
            catalog: ViewerProfileTestFixtures.catalog
        )
        try await repository.saveRecalibrationDraft(
            ViewerProfileTestFixtures.recalibrationDraft()
        )

        async let edit = repository.updateServices([.hboMax])
        async let completion = repository.completeRecalibration()
        _ = try? await completion
        _ = try await edit

        guard case let .completed(profile, _) = await repository.loadState() else {
            Issue.record("Expected a completed profile")
            return
        }
        #expect(profile.selectedServices == [.hboMax])
    }

    @Test("failed envelope encoding preserves previous bytes")
    func encodingFailurePreservesBytes() async throws {
        let store = InMemoryViewerProfileDataStore()
        let normalRepository = DefaultViewerProfileRepository(store: store)
        _ = try await normalRepository.beginFirstOnboarding(
            catalog: ViewerProfileTestFixtures.catalog
        )
        try await normalRepository.saveFirstOnboardingDraft(
            ViewerProfileTestFixtures.firstDraft()
        )
        let before = store.data
        let failingRepository = DefaultViewerProfileRepository(
            store: store,
            coder: FailingViewerProfileEncoder()
        )

        await #expect(throws: ViewerProfileRepositoryError.encodingFailed) {
            try await failingRepository.completeFirstOnboarding()
        }
        #expect(store.data == before)
    }

    @Test("rejected replacement preserves previous envelope")
    func replacementFailurePreservesBytes() async throws {
        let store = InMemoryViewerProfileDataStore()
        let repository = DefaultViewerProfileRepository(store: store)
        _ = try await ViewerProfileTestFixtures.completedProfile(in: repository)
        let before = store.data
        store.setRejectReplacements(true)

        await #expect(throws: ViewerProfileRepositoryError.storageFailed) {
            _ = try await repository.updateServices([.disneyPlus])
        }
        #expect(store.data == before)
    }

    @Test("unsupported and corrupt bytes remain distinct and preserved")
    func recoveryStatesPreserveBytes() async {
        let unsupported = Data(#"{"envelopeSchemaVersion":2}"#.utf8)
        let unsupportedStore = InMemoryViewerProfileDataStore(data: unsupported)
        let unsupportedRepository = DefaultViewerProfileRepository(store: unsupportedStore)
        #expect(await unsupportedRepository.loadState() == .recovery(.unsupportedVersion))
        #expect(unsupportedStore.data == unsupported)

        let corrupt = Data("not-json".utf8)
        let corruptStore = InMemoryViewerProfileDataStore(data: corrupt)
        let corruptRepository = DefaultViewerProfileRepository(store: corruptStore)
        #expect(await corruptRepository.loadState() == .recovery(.corruptData))
        #expect(corruptStore.data == corrupt)
    }

    @Test("surfaced read error is retryable and preserves bytes")
    func readFailure() async {
        let bytes = Data("preserve-me".utf8)
        let store = InMemoryViewerProfileDataStore(data: bytes)
        store.setRejectReads(true)
        let repository = DefaultViewerProfileRepository(store: store)

        #expect(await repository.loadState() == .recovery(.loadFailed))
        #expect(store.data == bytes)
    }

    @Test("invalid tagged envelope combinations are corrupt")
    func invalidEnvelopeCombination() async throws {
        let recalibrationDTO = RecalibrationDraftV1DTO(
            calibrationCatalogVersion: CalibrationCatalogID.spainHouseholdV1.rawValue,
            reactionsByMovieID: [:],
            currentCatalogPosition: 0,
            optionalExtensionAccepted: false
        )
        let envelope = ViewerStateEnvelopeV1DTO(
            envelopeSchemaVersion: 1,
            completedProfile: nil,
            profileDraft: ViewerProfileDraftV1DTO(
                kind: .recalibration,
                firstOnboarding: nil,
                recalibration: recalibrationDTO
            )
        )
        let data = try JSONViewerProfileEnvelopeCoder().encodeEnvelope(envelope)
        let repository = DefaultViewerProfileRepository(
            store: InMemoryViewerProfileDataStore(data: data)
        )

        #expect(await repository.loadState() == .recovery(.corruptData))
    }

    @Test("empty completed profile is corrupt")
    func emptyCompletedProfileIsCorrupt() async throws {
        let state = try await loadCompletedProfile(reactions: [:])

        #expect(state == .recovery(.corruptData))
    }

    @Test("completed profile with a reaction gap is corrupt")
    func completedProfileWithGapIsCorrupt() async throws {
        var reactions = ViewerProfileTestFixtures.reactions(count: 8)
        reactions[ViewerProfileTestFixtures.catalog.movies[3].id] = nil
        reactions[ViewerProfileTestFixtures.catalog.movies[8].id] = .loveIt

        let state = try await loadCompletedProfile(reactions: reactions)

        #expect(state == .recovery(.corruptData))
    }

    @Test("incomplete completed profile is corrupt")
    func incompleteCompletedProfileIsCorrupt() async throws {
        let reactions = ViewerProfileTestFixtures.reactions(
            count: 7,
            reaction: .loveIt
        )

        let state = try await loadCompletedProfile(reactions: reactions)

        #expect(state == .recovery(.corruptData))
    }

    @Test("partial extension below target is corrupt")
    func impossibleExtensionIsCorrupt() async throws {
        let reactions = ViewerProfileTestFixtures.reactions(
            count: 16,
            reaction: .haveNotSeenIt
        )

        let state = try await loadCompletedProfile(reactions: reactions)

        #expect(state == .recovery(.corruptData))
    }

    @Test("early target is a valid completed profile")
    func earlyTargetIsValid() async throws {
        let reactions = ViewerProfileTestFixtures.reactions(count: 8)

        let state = try await loadCompletedProfile(reactions: reactions)

        guard case let .completed(profile, nil) = state else {
            Issue.record("Expected a completed profile")
            return
        }
        #expect(profile.reactions == reactions)
    }

    @Test("normal exhaustion with few signals is a valid completed profile")
    func normalExhaustionIsValid() async throws {
        var reactions = ViewerProfileTestFixtures.reactions(
            count: CalibrationFlow.normalLimit,
            reaction: .haveNotSeenIt
        )
        for movie in ViewerProfileTestFixtures.catalog.movies.prefix(3) {
            reactions[movie.id] = .likeIt
        }

        let state = try await loadCompletedProfile(reactions: reactions)

        guard case let .completed(profile, nil) = state else {
            Issue.record("Expected a completed profile")
            return
        }
        #expect(profile.informativeSignalCount == 3)
    }

    @Test("normal low-signal Continue is a valid completed profile")
    func normalLowSignalContinueIsValid() async throws {
        let reactions = ViewerProfileTestFixtures.reactions(
            count: CalibrationFlow.normalLimit,
            reaction: .doNotKnowIt
        )

        let state = try await loadCompletedProfile(reactions: reactions)

        guard case let .completed(profile, nil) = state else {
            Issue.record("Expected a completed profile")
            return
        }
        #expect(profile.informativeSignalCount == 0)
    }

    @Test("extension exhaustion with any signal count is a valid completed profile")
    func extensionExhaustionIsValid() async throws {
        let reactions = ViewerProfileTestFixtures.reactions(
            count: ViewerProfileTestFixtures.catalog.movies.count,
            reaction: .doNotKnowIt
        )

        let state = try await loadCompletedProfile(reactions: reactions)

        guard case let .completed(profile, nil) = state else {
            Issue.record("Expected a completed profile")
            return
        }
        #expect(profile.informativeSignalCount == 0)
    }

    @Test("target reached inside the extension is a valid completed profile")
    func extensionTargetIsValid() async throws {
        var reactions = ViewerProfileTestFixtures.reactions(
            count: 16,
            reaction: .haveNotSeenIt
        )
        for movie in ViewerProfileTestFixtures.catalog.movies.prefix(8) {
            reactions[movie.id] = .itWasOkay
        }

        let state = try await loadCompletedProfile(reactions: reactions)

        guard case let .completed(profile, nil) = state else {
            Issue.record("Expected a completed profile")
            return
        }
        #expect(profile.informativeSignalCount == 8)
    }

    @Test("reset draft preserves profile while profile reset removes both")
    func resetsAreIsolated() async throws {
        let repository = DefaultViewerProfileRepository(
            store: InMemoryViewerProfileDataStore()
        )
        let profile = try await ViewerProfileTestFixtures.completedProfile(in: repository)
        _ = try await repository.beginRecalibration(
            catalog: ViewerProfileTestFixtures.catalog
        )

        try await repository.resetDraft()
        #expect(
            await repository.loadState()
                == .completed(profile: profile, recalibrationDraft: nil)
        )

        try await repository.resetProfileAndDraft()
        #expect(await repository.loadState() == .absent)
    }

    private func loadCompletedProfile(
        reactions: [Int: CalibrationReaction]
    ) async throws -> ViewerProfileLoadState {
        let profile = ViewerProfileV1DTO(
            profileSchemaVersion: ViewerProfile.currentSchemaVersion,
            calibrationCatalogVersion: ViewerProfileTestFixtures.catalog.id.rawValue,
            regionCode: ViewingRegion.spain.code,
            selectedProviderIDs: [PilotStreamingService.netflix.providerID],
            reactionsByMovieID: reactions.mapValues(\.rawValue)
        )
        let envelope = ViewerStateEnvelopeV1DTO(
            envelopeSchemaVersion: ViewerStateEnvelopeV1DTO.schemaVersion,
            completedProfile: profile,
            profileDraft: nil
        )
        let data = try JSONViewerProfileEnvelopeCoder().encodeEnvelope(envelope)
        let repository = DefaultViewerProfileRepository(
            store: InMemoryViewerProfileDataStore(data: data)
        )
        return await repository.loadState()
    }
}

@Suite("Viewer profile UserDefaults isolation tests", .serialized)
struct ViewerProfileUserDefaultsIsolationTests {
    @Test("profile reset leaves Watchlist and Search History untouched")
    func resetIsolation() async throws {
        let suiteName = "PickOneTests.ViewerProfile.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defaults.removePersistentDomain(forName: suiteName)
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let localStore = UserDefaultsLocalStore(suiteName: suiteName)
        let profileRepository = DefaultViewerProfileRepository(
            store: UserDefaultsViewerProfileDataStore(suiteName: suiteName)
        )
        let item = PersistedWatchlistItem(
            movieId: 42,
            title: "Arrival",
            posterPath: nil,
            releaseYear: 2016,
            rating: 7.6,
            addedAt: Date(timeIntervalSince1970: 100),
            isWatched: true
        )
        try localStore.saveWatchlistItem(item)
        localStore.addSearchQuery("Arrival")
        _ = try await ViewerProfileTestFixtures.completedProfile(in: profileRepository)

        try await profileRepository.resetProfileAndDraft()

        #expect(localStore.getWatchlistItems() == [item])
        #expect(localStore.getSearchHistory() == ["Arrival"])
        #expect(defaults.data(forKey: UserDefaultsViewerProfileDataStore.storageKey) == nil)
    }
}

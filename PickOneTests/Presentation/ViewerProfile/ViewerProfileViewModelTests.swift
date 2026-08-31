import Foundation
@testable import PickOne
import Testing

@MainActor
@Suite("ViewerProfileViewModel tests", .serialized)
struct ViewerProfileViewModelTests {
    @Test("routes every persisted viewer-profile state")
    func routesPersistedStates() async {
        let onboardingDraft = makeFirstDraft(step: .services)
        let profile = makeCompletedProfile()
        let recalibrationDraft = RecalibrationDraft.empty(
            catalog: ViewerProfileTestFixtures.catalog
        )

        let absent = makeSUT(loadStates: [.absent])
        await absent.load()
        #expect(absent.rootState == .onboarding)
        #expect(absent.firstDraft == .empty(catalog: ViewerProfileTestFixtures.catalog))

        let draft = makeSUT(loadStates: [.firstOnboarding(onboardingDraft)])
        await draft.load()
        #expect(draft.rootState == .onboarding)
        #expect(draft.firstDraft == onboardingDraft)

        let completed = makeSUT(
            loadStates: [.completed(profile: profile, recalibrationDraft: nil)]
        )
        await completed.load()
        #expect(completed.rootState == .main)
        #expect(completed.activeProfile == profile)
        #expect(completed.recalibrationDraft == nil)

        let recalibrating = makeSUT(
            loadStates: [
                .completed(
                    profile: profile,
                    recalibrationDraft: recalibrationDraft
                ),
            ]
        )
        await recalibrating.load()
        #expect(recalibrating.rootState == .main)
        #expect(recalibrating.activeProfile == profile)
        #expect(recalibrating.recalibrationDraft == recalibrationDraft)

        for reason in [
            ViewerProfileRecoveryReason.unsupportedVersion,
            .corruptData,
            .loadFailed,
        ] {
            let recovery = makeSUT(loadStates: [.recovery(reason)])
            await recovery.load()
            #expect(recovery.rootState == .recovery(reason))
            #expect(!recovery.canDestructivelyResetViewerState)
        }
    }

    @Test("first onboarding prefetches while services are visible and freezes the resolved catalog")
    func firstOnboardingFreezesResolvedCatalog() async {
        let resolution = CalibrationCatalogTestFixtures.resolution(source: .remote)
        let resolver = CalibrationCatalogResolverSpy(resolution: resolution)
        let manage = ViewerProfileManageSpy(loadStates: [.absent])
        let now = Date(timeIntervalSince1970: 2000)
        let sut = makeSUT(manage: manage, resolver: resolver, now: { now })

        await sut.load()
        await waitUntil { await resolver.prefetchCallCount == 1 }
        await sut.toggleFirstOnboardingService(.netflix)
        await sut.continueFromServices()

        #expect(await resolver.requestedDeadlines == [now.addingTimeInterval(2)])
        #expect(await manage.firstCalibrationSnapshot == resolution.snapshot)
        #expect(sut.catalog == resolution.snapshot.catalog)
        #expect(sut.currentMovie?.id == resolution.snapshot.movies[0].id)
    }

    @Test("resumed calibration keeps its frozen catalog without resolving a newer one")
    func resumedCalibrationKeepsFrozenCatalog() async {
        let frozenSnapshot = CalibrationCatalogTestFixtures.snapshot(version: 2)
        let frozenDraft = FirstOnboardingDraft(
            catalog: frozenSnapshot.catalog,
            step: .calibration,
            selectedServices: [.netflix],
            reactions: [:],
            currentCatalogPosition: 0,
            optionalExtensionAccepted: false,
            isCatalogFrozen: true
        )
        let resolver = CalibrationCatalogResolverSpy(
            resolution: CalibrationCatalogTestFixtures.resolution(source: .remote)
        )
        let sut = makeSUT(
            manage: ViewerProfileManageSpy(loadStates: [.firstOnboarding(frozenDraft)]),
            resolver: resolver
        )

        await sut.load()

        #expect(await resolver.resolveCallCount == 0)
        #expect(sut.catalog == frozenSnapshot.catalog)
    }

    @Test("continuing after Back reuses the already frozen snapshot")
    func backKeepsFrozenSnapshot() async {
        let frozenSnapshot = CalibrationCatalogTestFixtures.snapshot(version: 2)
        let draft = FirstOnboardingDraft(
            catalog: frozenSnapshot.catalog,
            step: .services,
            selectedServices: [.netflix],
            reactions: [:],
            currentCatalogPosition: 0,
            optionalExtensionAccepted: false,
            isCatalogFrozen: true
        )
        let resolver = CalibrationCatalogResolverSpy()
        let manage = ViewerProfileManageSpy(loadStates: [.firstOnboarding(draft)])
        let sut = makeSUT(manage: manage, resolver: resolver)

        await sut.load()
        await sut.continueFromServices()

        #expect(await resolver.resolveCallCount == 0)
        #expect(await manage.firstCalibrationCallCount == 1)
        #expect(await manage.firstCalibrationSnapshot == nil)
        #expect(sut.catalog == frozenSnapshot.catalog)
    }

    @Test("recalibration retry keeps the original visible deadline")
    func recalibrationRetryKeepsDeadline() async {
        let now = Date(timeIntervalSince1970: 3000)
        let resolver = CalibrationCatalogResolverSpy(executeFailures: 1)
        let sut = makeSUT(
            manage: ViewerProfileManageSpy(
                loadStates: [
                    .completed(profile: makeCompletedProfile(), recalibrationDraft: nil),
                ]
            ),
            resolver: resolver,
            now: { now }
        )
        await sut.load()

        await sut.startRecalibration()
        await sut.retryLastAction()

        #expect(await resolver.requestedDeadlines == [
            now.addingTimeInterval(2),
            now.addingTimeInterval(2),
        ])
        #expect(sut.recalibrationDraft != nil)
    }

    @Test("recalibration shows loading while unresolved and Close cancels only its wait")
    func recalibrationLoadingCanBeCancelled() async {
        let resolver = CancellableCalibrationCatalogResolver()
        let sut = makeSUT(
            manage: ViewerProfileManageSpy(
                loadStates: [
                    .completed(profile: makeCompletedProfile(), recalibrationDraft: nil),
                ]
            ),
            resolver: resolver
        )
        await sut.load()

        let start = Task { await sut.startRecalibration() }
        await waitUntil { await resolver.didStartResolving }
        #expect(sut.presentedCalibration == .recalibration)
        #expect(sut.isResolvingCalibrationCatalog)

        sut.dismissRecalibration()
        await start.value

        #expect(await resolver.wasCancelled)
        #expect(sut.presentedCalibration == nil)
        #expect(!sut.isResolvingCalibrationCatalog)
        #expect(sut.saveErrorMessage == nil)
    }

    @Test("recalibration displays an existing reaction without counting it as a new response")
    func recalibrationReusesExistingReaction() async {
        let movieID = ViewerProfileTestFixtures.catalog.movies[0].id
        let profile = makeCompletedProfile(reactions: [movieID: .loveIt])
        let draft = RecalibrationDraft.empty(catalog: ViewerProfileTestFixtures.catalog)
        let sut = makeSUT(
            manage: ViewerProfileManageSpy(
                loadStates: [.completed(profile: profile, recalibrationDraft: draft)]
            )
        )

        await sut.load()
        await sut.startRecalibration()

        #expect(draft.informativeSignalCount == 0)
        #expect(sut.reactionForCurrentMovie(mode: .recalibration) == .loveIt)
    }

    @Test("detectable load failure can retry into onboarding")
    func loadFailureCanRetry() async {
        let sut = makeSUT(loadStates: [.recovery(.loadFailed), .absent])

        await sut.load()
        #expect(sut.rootState == .recovery(.loadFailed))

        await sut.retryLastAction()

        #expect(sut.rootState == .onboarding)
        #expect(sut.firstDraft == .empty(catalog: ViewerProfileTestFixtures.catalog))
    }

    @Test("older-snapshot recovery notice remains visible when recovery resumes onboarding")
    func recoveryNoticeSurvivesOnboardingRouting() async {
        let sut = makeSUT(
            manage: ViewerProfileManageSpy(loadStates: [.absent]),
            getRecoveryNotice: ConstantViewerStateRecoveryNotice(.olderSnapshot)
        )

        await sut.load()

        #expect(sut.rootState == .onboarding)
        #expect(sut.recoveryNotice == .olderSnapshot)
    }

    @Test("failed reaction save preserves the visible movie and retries")
    func reactionFailurePreservesVisibleStateAndRetries() async {
        let manage = ViewerProfileManageSpy(
            loadStates: [.firstOnboarding(makeFirstDraft())],
            firstReactionFailures: 1
        )
        let sut = makeSUT(manage: manage)
        await sut.load()
        let visibleMovie = sut.currentMovie

        await sut.react(.loveIt, mode: .firstOnboarding)

        #expect(sut.firstDraft?.currentCatalogPosition == 0)
        #expect(sut.currentMovie == visibleMovie)
        #expect(sut.pendingReaction == .loveIt)
        #expect(sut.saveErrorMessage != nil)
        #expect(!sut.isSaving)

        await sut.retryLastAction()

        #expect(sut.firstDraft?.currentCatalogPosition == 1)
        #expect(sut.currentMovie?.id == ViewerProfileTestFixtures.catalog.movies[1].id)
        #expect(sut.pendingReaction == nil)
        #expect(sut.saveErrorMessage == nil)
        #expect(!sut.isSaving)
    }

    @Test("cancelled reaction publishes no failure or advancement")
    func cancelledReactionDoesNotAdvance() async {
        let gate = AsyncViewerProfileGate()
        let manage = ViewerProfileManageSpy(
            loadStates: [.firstOnboarding(makeFirstDraft())],
            firstReactionGate: gate
        )
        let sut = makeSUT(manage: manage)
        await sut.load()

        let reactionTask = Task {
            await sut.react(.likeIt, mode: .firstOnboarding)
        }
        await waitUntil { await manage.firstReactionCallCount == 1 }
        reactionTask.cancel()
        await gate.open()
        await reactionTask.value

        #expect(sut.firstDraft?.currentCatalogPosition == 0)
        #expect(sut.pendingReaction == nil)
        #expect(sut.saveErrorMessage == nil)
        #expect(!sut.isSaving)
    }

    @Test("suspended metadata never blocks persistence or the next bundled fallback")
    func suspendedMetadataIsNonBlocking() async {
        let metadata = ControlledCalibrationMetadata(honorsCancellation: true)
        let manage = ViewerProfileManageSpy(
            loadStates: [.firstOnboarding(makeFirstDraft())]
        )
        let sut = makeSUT(manage: manage, metadata: metadata)
        let firstMovieID = ViewerProfileTestFixtures.catalog.movies[0].id
        let secondMovieID = ViewerProfileTestFixtures.catalog.movies[1].id

        await sut.load()
        await metadata.waitUntilStarted(movieID: firstMovieID)
        #expect(sut.currentMovie?.id == firstMovieID)

        await sut.react(.loveIt, mode: .firstOnboarding)
        await metadata.waitUntilStarted(movieID: secondMovieID)

        #expect(sut.firstDraft?.currentCatalogPosition == 1)
        #expect(sut.currentMovie?.id == secondMovieID)
        #expect(!sut.isSaving)
        await waitUntil { await metadata.wasCancelled(movieID: firstMovieID) }
        #expect(await metadata.wasCancelled(movieID: firstMovieID))

        await metadata.complete(
            movieID: secondMovieID,
            with: metadataValue(title: "Hydrated second")
        )
    }

    @Test("late metadata for a superseded movie cannot replace the current card")
    func staleMetadataIsIgnored() async {
        let metadata = ControlledCalibrationMetadata(honorsCancellation: false)
        let sut = makeSUT(
            manage: ViewerProfileManageSpy(
                loadStates: [.firstOnboarding(makeFirstDraft())]
            ),
            metadata: metadata
        )
        let firstMovieID = ViewerProfileTestFixtures.catalog.movies[0].id
        let secondMovieID = ViewerProfileTestFixtures.catalog.movies[1].id

        await sut.load()
        await metadata.waitUntilStarted(movieID: firstMovieID)
        await sut.react(.likeIt, mode: .firstOnboarding)
        await metadata.waitUntilStarted(movieID: secondMovieID)

        await metadata.complete(
            movieID: firstMovieID,
            with: metadataValue(title: "Stale title")
        )
        await Task.yield()

        #expect(sut.currentMovie?.id == secondMovieID)
        #expect(sut.currentMovie?.primaryText != "Stale title")

        await metadata.complete(
            movieID: secondMovieID,
            with: metadataValue(title: "Current title")
        )
        await waitUntil { sut.currentMovie?.primaryText == "Current title" }

        #expect(sut.currentMovie?.id == secondMovieID)
    }

    @Test("closing Preferences calibration cancels metadata and keeps it dismissed")
    func dismissingRecalibrationCancelsMetadata() async {
        let metadata = ControlledCalibrationMetadata(honorsCancellation: false)
        let profile = makeCompletedProfile()
        let recalibration = RecalibrationDraft.empty(
            catalog: ViewerProfileTestFixtures.catalog
        )
        let sut = makeSUT(
            manage: ViewerProfileManageSpy(
                loadStates: [
                    .completed(
                        profile: profile,
                        recalibrationDraft: recalibration
                    ),
                ]
            ),
            metadata: metadata
        )
        let movieID = ViewerProfileTestFixtures.catalog.movies[0].id

        await sut.load()
        await sut.startRecalibration()
        await metadata.waitUntilStarted(movieID: movieID)

        sut.dismissRecalibration()
        await waitUntil { await metadata.wasCancelled(movieID: movieID) }
        await metadata.complete(
            movieID: movieID,
            with: metadataValue(title: "Late title")
        )
        await Task.yield()

        #expect(sut.presentedCalibration == nil)
        #expect(sut.currentMovie == nil)
    }

    @Test("reset routes to recovery if the replacement draft cannot be created")
    func resetDraftCreationFailureRoutesCorrectly() async {
        let profile = makeCompletedProfile()
        let manage = ViewerProfileManageSpy(
            loadStates: [
                .completed(profile: profile, recalibrationDraft: nil),
                .absent,
            ],
            beginFirstFailures: 1
        )
        let sut = makeSUT(manage: manage)
        await sut.load()

        await sut.resetProfile()

        #expect(sut.activeProfile == nil)
        #expect(sut.firstDraft == nil)
        #expect(sut.rootState == .recovery(.loadFailed))
        #expect(await manage.resetProfileCallCount == 1)

        await sut.retryLastAction()

        #expect(sut.rootState == .onboarding)
        #expect(sut.firstDraft == .empty(catalog: ViewerProfileTestFixtures.catalog))
        #expect(await manage.resetProfileCallCount == 1)
    }

    @Test("confirmed destructive recovery creates a new onboarding route")
    func destructiveRecoveryRoutesToOnboarding() async {
        let reset = DestructiveViewerStateRecoverySpy(availability: .available)
        let sut = makeSUT(
            manage: ViewerProfileManageSpy(
                loadStates: [.recovery(.corruptData), .absent]
            ),
            resetUnrecoverableViewerState: reset
        )
        await sut.load()

        await sut.destructivelyResetUnrecoverableViewerState()

        #expect(await reset.callCount == 1)
        #expect(sut.rootState == .onboarding)
        #expect(sut.firstDraft == .empty(catalog: ViewerProfileTestFixtures.catalog))
    }

    private func makeSUT(
        loadStates: [ViewerProfileLoadState]
    ) -> ViewerProfileViewModel {
        makeSUT(manage: ViewerProfileManageSpy(loadStates: loadStates))
    }

    private func makeSUT(
        manage: ViewerProfileManageSpy,
        metadata: GetCalibrationMovieMetadataUseCase = FailingCalibrationMetadata(),
        resolver: ResolveCalibrationCatalogUseCase = CalibrationCatalogResolverSpy(),
        now: @escaping @Sendable () -> Date = Date.init,
        getRecoveryNotice: (any GetViewerStateRecoveryNoticeUseCase)? = nil,
        resetUnrecoverableViewerState: (any ResetUnrecoverableViewerStateUseCase)? = nil
    ) -> ViewerProfileViewModel {
        ViewerProfileViewModel(
            manageProfile: manage,
            getMovieMetadata: metadata,
            resolveCalibrationCatalog: resolver,
            now: now,
            getRecoveryNotice: getRecoveryNotice,
            resetUnrecoverableViewerState: resetUnrecoverableViewerState
        )
    }

    private func waitUntil(
        _ condition: @escaping @MainActor () async -> Bool
    ) async {
        for _ in 0 ..< 200 {
            if await condition() {
                return
            }
            await Task.yield()
        }
        #expect(await condition())
    }
}

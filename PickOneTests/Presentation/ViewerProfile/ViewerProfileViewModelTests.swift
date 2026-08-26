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
        }
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
        let reset = DestructiveViewerStateRecoverySpy()
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
        getRecoveryNotice: (any GetViewerStateRecoveryNoticeUseCase)? = nil,
        resetUnrecoverableViewerState: (any ResetUnrecoverableViewerStateUseCase)? = nil
    ) -> ViewerProfileViewModel {
        ViewerProfileViewModel(
            manageProfile: manage,
            getMovieMetadata: metadata,
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

private actor ControlledCalibrationMetadata: GetCalibrationMovieMetadataUseCase {
    private let honorsCancellation: Bool
    private var continuations: [
        Int: CheckedContinuation<CalibrationMovieMetadata, Error>
    ] = [:]
    private var startedMovieIDs: Set<Int> = []
    private var cancelledMovieIDs: Set<Int> = []

    init(honorsCancellation: Bool) {
        self.honorsCancellation = honorsCancellation
    }

    func execute(movieID: Int) async throws -> CalibrationMovieMetadata {
        startedMovieIDs.insert(movieID)
        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                continuations[movieID] = continuation
            }
        } onCancel: {
            Task { await self.cancel(movieID: movieID) }
        }
    }

    func waitUntilStarted(movieID: Int) async {
        while !startedMovieIDs.contains(movieID) {
            await Task.yield()
        }
    }

    func wasCancelled(movieID: Int) -> Bool {
        cancelledMovieIDs.contains(movieID)
    }

    func complete(
        movieID: Int,
        with metadata: CalibrationMovieMetadata
    ) {
        guard let continuation = continuations.removeValue(forKey: movieID) else {
            return
        }
        continuation.resume(returning: metadata)
    }

    private func cancel(movieID: Int) {
        cancelledMovieIDs.insert(movieID)
        guard honorsCancellation,
              let continuation = continuations.removeValue(forKey: movieID)
        else { return }
        continuation.resume(throwing: CancellationError())
    }
}

private actor AsyncViewerProfileGate {
    private var isOpen = false
    private var waiters: [CheckedContinuation<Void, Never>] = []

    func wait() async {
        if isOpen { return }
        await withCheckedContinuation { continuation in
            waiters.append(continuation)
        }
    }

    func open() {
        isOpen = true
        let currentWaiters = waiters
        waiters.removeAll()
        for waiter in currentWaiters {
            waiter.resume()
        }
    }
}

private actor ViewerProfileManageSpy: ManageViewerProfileUseCase {
    nonisolated let catalog = ViewerProfileTestFixtures.catalog

    private let loadStates: [ViewerProfileLoadState]
    private let firstReactionGate: AsyncViewerProfileGate?
    private var loadIndex = 0
    private var beginFirstFailures: Int
    private var firstReactionFailures: Int
    private(set) var firstReactionCallCount = 0
    private(set) var resetProfileCallCount = 0

    init(
        loadStates: [ViewerProfileLoadState],
        beginFirstFailures: Int = 0,
        firstReactionFailures: Int = 0,
        firstReactionGate: AsyncViewerProfileGate? = nil
    ) {
        self.loadStates = loadStates
        self.beginFirstFailures = beginFirstFailures
        self.firstReactionFailures = firstReactionFailures
        self.firstReactionGate = firstReactionGate
    }

    func loadState() async -> ViewerProfileLoadState {
        let state = loadStates[min(loadIndex, loadStates.count - 1)]
        loadIndex += 1
        return state
    }

    func beginFirstOnboarding() async throws -> FirstOnboardingDraft {
        if beginFirstFailures > 0 {
            beginFirstFailures -= 1
            throw ViewerProfileViewModelTestError.failed
        }
        return .empty(catalog: catalog)
    }

    func selectServices(
        _ services: [PilotStreamingService],
        in draft: FirstOnboardingDraft
    ) async throws -> FirstOnboardingDraft {
        FirstOnboardingDraft(
            catalogID: draft.catalogID,
            step: draft.step,
            selectedServices: services,
            reactions: draft.reactions,
            currentCatalogPosition: draft.currentCatalogPosition,
            optionalExtensionAccepted: draft.optionalExtensionAccepted
        )
    }

    func beginCalibration(
        from draft: FirstOnboardingDraft
    ) async throws -> FirstOnboardingDraft {
        firstDraft(draft, step: .calibration)
    }

    func react(
        _ reaction: CalibrationReaction,
        in draft: FirstOnboardingDraft
    ) async throws -> FirstOnboardingDraft {
        firstReactionCallCount += 1
        if let firstReactionGate {
            await firstReactionGate.wait()
            try Task.checkCancellation()
        }
        if firstReactionFailures > 0 {
            firstReactionFailures -= 1
            throw ViewerProfileViewModelTestError.failed
        }
        var reactions = draft.reactions
        reactions[catalog.movies[draft.currentCatalogPosition].id] = reaction
        return FirstOnboardingDraft(
            catalogID: draft.catalogID,
            step: .calibration,
            selectedServices: draft.selectedServices,
            reactions: reactions,
            currentCatalogPosition: draft.currentCatalogPosition + 1,
            optionalExtensionAccepted: draft.optionalExtensionAccepted
        )
    }

    func react(
        _ reaction: CalibrationReaction,
        in draft: RecalibrationDraft
    ) async throws -> RecalibrationDraft {
        var reactions = draft.reactions
        reactions[catalog.movies[draft.currentCatalogPosition].id] = reaction
        return RecalibrationDraft(
            catalogID: draft.catalogID,
            reactions: reactions,
            currentCatalogPosition: draft.currentCatalogPosition + 1,
            optionalExtensionAccepted: draft.optionalExtensionAccepted
        )
    }

    func goBack(in draft: FirstOnboardingDraft) async throws -> FirstOnboardingDraft {
        FirstOnboardingDraft(
            catalogID: draft.catalogID,
            step: draft.currentCatalogPosition == 0 ? .services : .calibration,
            selectedServices: draft.selectedServices,
            reactions: draft.reactions,
            currentCatalogPosition: max(0, draft.currentCatalogPosition - 1),
            optionalExtensionAccepted: draft.optionalExtensionAccepted
        )
    }

    func goBack(in draft: RecalibrationDraft) async throws -> RecalibrationDraft {
        RecalibrationDraft(
            catalogID: draft.catalogID,
            reactions: draft.reactions,
            currentCatalogPosition: max(0, draft.currentCatalogPosition - 1),
            optionalExtensionAccepted: draft.optionalExtensionAccepted
        )
    }

    func acceptOptionalExtension(
        in draft: FirstOnboardingDraft
    ) async throws -> FirstOnboardingDraft {
        FirstOnboardingDraft(
            catalogID: draft.catalogID,
            step: .calibration,
            selectedServices: draft.selectedServices,
            reactions: draft.reactions,
            currentCatalogPosition: draft.currentCatalogPosition,
            optionalExtensionAccepted: true
        )
    }

    func acceptOptionalExtension(
        in draft: RecalibrationDraft
    ) async throws -> RecalibrationDraft {
        RecalibrationDraft(
            catalogID: draft.catalogID,
            reactions: draft.reactions,
            currentCatalogPosition: draft.currentCatalogPosition,
            optionalExtensionAccepted: true
        )
    }

    func continueWithLowSignals(
        in draft: FirstOnboardingDraft
    ) async throws -> FirstOnboardingDraft {
        firstDraft(draft, step: .completion)
    }

    func completeFirstOnboarding() async throws -> ViewerProfile {
        makeCompletedProfile()
    }

    func beginRecalibration() async throws -> RecalibrationDraft {
        .empty(catalog: catalog)
    }

    func completeRecalibration() async throws -> ViewerProfile {
        makeCompletedProfile()
    }

    func updateServices(
        _ services: [PilotStreamingService]
    ) async throws -> ViewerProfile {
        let profile = makeCompletedProfile()
        return ViewerProfile(
            profileSchemaVersion: profile.profileSchemaVersion,
            catalogID: profile.catalogID,
            region: profile.region,
            selectedServices: services,
            reactions: profile.reactions
        )
    }

    func resetDraft() async throws {}

    func resetProfileAndDraft() async throws {
        resetProfileCallCount += 1
    }

    private func firstDraft(
        _ draft: FirstOnboardingDraft,
        step: FirstOnboardingStep
    ) -> FirstOnboardingDraft {
        FirstOnboardingDraft(
            catalogID: draft.catalogID,
            step: step,
            selectedServices: draft.selectedServices,
            reactions: draft.reactions,
            currentCatalogPosition: draft.currentCatalogPosition,
            optionalExtensionAccepted: draft.optionalExtensionAccepted
        )
    }
}

private func makeFirstDraft(
    step: FirstOnboardingStep = .calibration
) -> FirstOnboardingDraft {
    FirstOnboardingDraft(
        catalogID: ViewerProfileTestFixtures.catalog.id,
        step: step,
        selectedServices: [.netflix],
        reactions: [:],
        currentCatalogPosition: 0,
        optionalExtensionAccepted: false
    )
}

private func makeCompletedProfile() -> ViewerProfile {
    ViewerProfile(
        profileSchemaVersion: ViewerProfile.currentSchemaVersion,
        catalogID: ViewerProfileTestFixtures.catalog.id,
        region: .spain,
        selectedServices: [.netflix],
        reactions: ViewerProfileTestFixtures.reactions(count: 8)
    )
}

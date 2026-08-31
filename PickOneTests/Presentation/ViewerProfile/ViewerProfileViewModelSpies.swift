@testable import PickOne

actor ControlledCalibrationMetadata: GetCalibrationMovieMetadataUseCase {
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

actor AsyncViewerProfileGate {
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

actor ViewerProfileManageSpy: ManageViewerProfileUseCase {
    nonisolated let catalog = ViewerProfileTestFixtures.catalog

    private let loadStates: [ViewerProfileLoadState]
    private let firstReactionGate: AsyncViewerProfileGate?
    private var loadIndex = 0
    private var beginFirstFailures: Int
    private var firstReactionFailures: Int
    private(set) var firstReactionCallCount = 0
    private(set) var resetProfileCallCount = 0
    private(set) var firstCalibrationSnapshot: CalibrationCatalogSnapshot?
    private(set) var firstCalibrationCallCount = 0

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
        from draft: FirstOnboardingDraft,
        snapshot: CalibrationCatalogSnapshot?
    ) async throws -> FirstOnboardingDraft {
        firstCalibrationCallCount += 1
        firstCalibrationSnapshot = snapshot
        return firstDraft(draft, step: .calibration, catalog: snapshot?.catalog)
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

    func beginRecalibration(snapshot: CalibrationCatalogSnapshot) async throws -> RecalibrationDraft {
        .empty(snapshot: snapshot)
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
        step: FirstOnboardingStep,
        catalog: CalibrationCatalog? = nil
    ) -> FirstOnboardingDraft {
        FirstOnboardingDraft(
            catalog: catalog ?? draft.catalog,
            step: step,
            selectedServices: draft.selectedServices,
            reactions: draft.reactions,
            currentCatalogPosition: draft.currentCatalogPosition,
            optionalExtensionAccepted: draft.optionalExtensionAccepted
        )
    }
}

func makeFirstDraft(
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

func makeCompletedProfile() -> ViewerProfile {
    makeCompletedProfile(reactions: ViewerProfileTestFixtures.reactions(count: 8))
}

func makeCompletedProfile(
    reactions: [Int: CalibrationReaction]
) -> ViewerProfile {
    ViewerProfile(
        profileSchemaVersion: ViewerProfile.currentSchemaVersion,
        catalogID: ViewerProfileTestFixtures.catalog.id,
        region: .spain,
        selectedServices: [.netflix],
        reactions: reactions
    )
}

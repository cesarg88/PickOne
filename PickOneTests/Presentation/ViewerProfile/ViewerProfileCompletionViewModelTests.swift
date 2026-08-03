@testable import PickOne
import Testing

@MainActor
@Suite("Viewer profile completion presentation tests", .serialized)
struct ViewerProfileCompletionViewModelTests {
    @Test("failed first-onboarding completion stays unsaved and can retry")
    func firstCompletionFailureStaysUnsavedAndRetries() async {
        let draft = firstCompletionDraft()
        let manage = CompletionManageSpy(
            loadState: .firstOnboarding(draft),
            firstCompletionFailures: 1
        )
        let sut = makeSUT(manage: manage)

        await sut.load()
        await sut.complete(mode: .firstOnboarding)

        #expect(sut.rootState == .onboarding)
        #expect(sut.activeProfile == nil)
        #expect(sut.firstDraft == draft)
        #expect(sut.currentDestination(for: .firstOnboarding) == .completion)
        #expect(sut.saveErrorMessage != nil)
        #expect(await !(manage.didPersistFirstCompletion))

        await sut.retryLastAction()

        #expect(sut.rootState == .main)
        #expect(sut.activeProfile != nil)
        #expect(sut.firstDraft == nil)
        #expect(sut.saveErrorMessage == nil)
        #expect(await manage.didPersistFirstCompletion)
        #expect(await manage.firstCompletionCallCount == 2)
    }

    @Test("failed low-signal recalibration completion stays open and can retry")
    func recalibrationCompletionFailureStaysOpenAndRetries() async {
        let profile = completedProfile()
        let draft = lowSignalRecalibrationDraft()
        let manage = CompletionManageSpy(
            loadState: .completed(
                profile: profile,
                recalibrationDraft: draft
            ),
            recalibrationCompletionFailures: 1
        )
        let sut = makeSUT(manage: manage)

        await sut.load()
        await sut.startRecalibration()
        #expect(sut.currentDestination(for: .recalibration) == .lowSignalDecision)

        await sut.complete(mode: .recalibration)

        #expect(sut.activeProfile == profile)
        #expect(sut.recalibrationDraft == draft)
        #expect(sut.presentedCalibration == .recalibration)
        #expect(sut.currentDestination(for: .recalibration) == .lowSignalDecision)
        #expect(sut.saveErrorMessage != nil)
        #expect(await !(manage.didPersistRecalibrationCompletion))

        await sut.retryLastAction()

        #expect(sut.activeProfile != nil)
        #expect(sut.recalibrationDraft == nil)
        #expect(sut.presentedCalibration == nil)
        #expect(sut.saveErrorMessage == nil)
        #expect(await manage.didPersistRecalibrationCompletion)
        #expect(await manage.recalibrationCompletionCallCount == 2)
    }

    @Test("low-signal Continue creates a pre-save draft before entering main")
    func lowSignalContinueRequiresFinalPersistence() async {
        let manage = CompletionManageSpy(
            loadState: .firstOnboarding(lowSignalFirstDraft())
        )
        let sut = makeSUT(manage: manage)

        await sut.load()
        #expect(sut.currentDestination(for: .firstOnboarding) == .lowSignalDecision)

        await sut.continueWithLowSignals()

        #expect(sut.rootState == .onboarding)
        #expect(sut.activeProfile == nil)
        #expect(sut.firstDraft?.step == .completion)
        #expect(sut.currentDestination(for: .firstOnboarding) == .completion)
        #expect(await !(manage.didPersistFirstCompletion))

        await sut.complete(mode: .firstOnboarding)

        #expect(sut.rootState == .main)
        #expect(sut.activeProfile != nil)
        #expect(sut.firstDraft == nil)
        #expect(await manage.didPersistFirstCompletion)
    }

    @Test("first onboarding cannot enter main while persistence is suspended")
    func firstCompletionMustPersistBeforeEnteringMain() async {
        let gate = CompletionGate()
        let draft = firstCompletionDraft()
        let manage = CompletionManageSpy(
            loadState: .firstOnboarding(draft),
            firstCompletionGate: gate
        )
        let sut = makeSUT(manage: manage)
        await sut.load()

        let completionTask = Task {
            await sut.complete(mode: .firstOnboarding)
        }
        await waitUntil { await manage.firstCompletionCallCount == 1 }

        #expect(sut.isSaving)
        #expect(sut.rootState == .onboarding)
        #expect(sut.activeProfile == nil)
        #expect(sut.firstDraft == draft)
        #expect(await !(manage.didPersistFirstCompletion))

        await gate.open()
        await completionTask.value

        #expect(!sut.isSaving)
        #expect(await manage.didPersistFirstCompletion)
        #expect(sut.rootState == .main)
        #expect(sut.activeProfile != nil)
        #expect(sut.firstDraft == nil)
    }

    @Test("entering main requires a completed repository envelope")
    func enteringMainRequiresCompletedEnvelope() async throws {
        let store = InMemoryViewerProfileDataStore()
        let repository = DefaultViewerProfileRepository(store: store)
        _ = try await repository.beginFirstOnboarding(
            catalog: ViewerProfileTestFixtures.catalog
        )
        let draft = firstCompletionDraft()
        try await repository.saveFirstOnboardingDraft(draft)
        let sut = ViewerProfileViewModel(
            manageProfile: ManageViewerProfile(
                repository: repository,
                catalog: ViewerProfileTestFixtures.catalog
            ),
            getMovieMetadata: CompletionMetadataStub()
        )

        await sut.load()
        #expect(await repository.loadState() == .firstOnboarding(draft))
        #expect(sut.rootState == .onboarding)

        await sut.complete(mode: .firstOnboarding)

        guard case let .completed(profile, recalibrationDraft) = await repository.loadState()
        else {
            Issue.record("Expected a persisted completed profile")
            return
        }
        #expect(recalibrationDraft == nil)
        #expect(sut.activeProfile == profile)
        #expect(sut.firstDraft == nil)
        #expect(sut.rootState == .main)
    }

    private func makeSUT(
        manage: CompletionManageSpy
    ) -> ViewerProfileViewModel {
        ViewerProfileViewModel(
            manageProfile: manage,
            getMovieMetadata: CompletionMetadataStub()
        )
    }

    private func waitUntil(
        _ condition: @escaping @MainActor () async -> Bool
    ) async {
        for _ in 0 ..< 200 {
            if await condition() { return }
            await Task.yield()
        }
        #expect(await condition())
    }
}

private enum CompletionTestError: Error {
    case failed
    case unexpectedCall
}

private struct CompletionMetadataStub: GetCalibrationMovieMetadataUseCase {
    func execute(movieID _: Int) async throws -> CalibrationMovieMetadata {
        throw CompletionTestError.unexpectedCall
    }
}

private actor CompletionGate {
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

private actor CompletionManageSpy: ManageViewerProfileUseCase {
    nonisolated let catalog = ViewerProfileTestFixtures.catalog

    private let persistedLoadState: ViewerProfileLoadState
    private let firstCompletionGate: CompletionGate?
    private var firstCompletionFailures: Int
    private var recalibrationCompletionFailures: Int
    private(set) var firstCompletionCallCount = 0
    private(set) var recalibrationCompletionCallCount = 0
    private(set) var didPersistFirstCompletion = false
    private(set) var didPersistRecalibrationCompletion = false

    init(
        loadState: ViewerProfileLoadState,
        firstCompletionFailures: Int = 0,
        firstCompletionGate: CompletionGate? = nil,
        recalibrationCompletionFailures: Int = 0
    ) {
        persistedLoadState = loadState
        self.firstCompletionFailures = firstCompletionFailures
        self.firstCompletionGate = firstCompletionGate
        self.recalibrationCompletionFailures = recalibrationCompletionFailures
    }

    func loadState() async -> ViewerProfileLoadState {
        persistedLoadState
    }

    func continueWithLowSignals(
        in draft: FirstOnboardingDraft
    ) async throws -> FirstOnboardingDraft {
        FirstOnboardingDraft(
            catalogID: draft.catalogID,
            step: .completion,
            selectedServices: draft.selectedServices,
            reactions: draft.reactions,
            currentCatalogPosition: draft.currentCatalogPosition,
            optionalExtensionAccepted: draft.optionalExtensionAccepted
        )
    }

    func completeFirstOnboarding() async throws -> ViewerProfile {
        firstCompletionCallCount += 1
        if let firstCompletionGate {
            await firstCompletionGate.wait()
            try Task.checkCancellation()
        }
        if firstCompletionFailures > 0 {
            firstCompletionFailures -= 1
            throw CompletionTestError.failed
        }
        didPersistFirstCompletion = true
        return completedProfile()
    }

    func completeRecalibration() async throws -> ViewerProfile {
        recalibrationCompletionCallCount += 1
        if recalibrationCompletionFailures > 0 {
            recalibrationCompletionFailures -= 1
            throw CompletionTestError.failed
        }
        didPersistRecalibrationCompletion = true
        return completedProfile()
    }

    func beginFirstOnboarding() async throws -> FirstOnboardingDraft {
        throw CompletionTestError.unexpectedCall
    }

    func selectServices(
        _: [PilotStreamingService],
        in _: FirstOnboardingDraft
    ) async throws -> FirstOnboardingDraft {
        throw CompletionTestError.unexpectedCall
    }

    func beginCalibration(
        from _: FirstOnboardingDraft
    ) async throws -> FirstOnboardingDraft {
        throw CompletionTestError.unexpectedCall
    }

    func react(
        _: CalibrationReaction,
        in _: FirstOnboardingDraft
    ) async throws -> FirstOnboardingDraft {
        throw CompletionTestError.unexpectedCall
    }

    func react(
        _: CalibrationReaction,
        in _: RecalibrationDraft
    ) async throws -> RecalibrationDraft {
        throw CompletionTestError.unexpectedCall
    }

    func goBack(
        in _: FirstOnboardingDraft
    ) async throws -> FirstOnboardingDraft {
        throw CompletionTestError.unexpectedCall
    }

    func goBack(
        in _: RecalibrationDraft
    ) async throws -> RecalibrationDraft {
        throw CompletionTestError.unexpectedCall
    }

    func acceptOptionalExtension(
        in _: FirstOnboardingDraft
    ) async throws -> FirstOnboardingDraft {
        throw CompletionTestError.unexpectedCall
    }

    func acceptOptionalExtension(
        in _: RecalibrationDraft
    ) async throws -> RecalibrationDraft {
        throw CompletionTestError.unexpectedCall
    }

    func beginRecalibration() async throws -> RecalibrationDraft {
        throw CompletionTestError.unexpectedCall
    }

    func updateServices(
        _: [PilotStreamingService]
    ) async throws -> ViewerProfile {
        throw CompletionTestError.unexpectedCall
    }

    func resetDraft() async throws {
        throw CompletionTestError.unexpectedCall
    }

    func resetProfileAndDraft() async throws {
        throw CompletionTestError.unexpectedCall
    }
}

private func firstCompletionDraft() -> FirstOnboardingDraft {
    FirstOnboardingDraft(
        catalogID: ViewerProfileTestFixtures.catalog.id,
        step: .completion,
        selectedServices: [.netflix],
        reactions: ViewerProfileTestFixtures.reactions(count: 8),
        currentCatalogPosition: 8,
        optionalExtensionAccepted: false
    )
}

private func lowSignalFirstDraft() -> FirstOnboardingDraft {
    FirstOnboardingDraft(
        catalogID: ViewerProfileTestFixtures.catalog.id,
        step: .lowSignalDecision,
        selectedServices: [.netflix],
        reactions: ViewerProfileTestFixtures.reactions(
            count: 15,
            reaction: .doNotKnowIt
        ),
        currentCatalogPosition: 15,
        optionalExtensionAccepted: false
    )
}

private func lowSignalRecalibrationDraft() -> RecalibrationDraft {
    RecalibrationDraft(
        catalogID: ViewerProfileTestFixtures.catalog.id,
        reactions: ViewerProfileTestFixtures.reactions(
            count: 15,
            reaction: .doNotKnowIt
        ),
        currentCatalogPosition: 15,
        optionalExtensionAccepted: false
    )
}

private func completedProfile() -> ViewerProfile {
    ViewerProfile(
        profileSchemaVersion: ViewerProfile.currentSchemaVersion,
        catalogID: ViewerProfileTestFixtures.catalog.id,
        region: .spain,
        selectedServices: [.netflix],
        reactions: ViewerProfileTestFixtures.reactions(count: 8)
    )
}

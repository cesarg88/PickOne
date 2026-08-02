@testable import PickOne
import Testing

@Suite("Manage viewer profile tests")
struct ManageViewerProfileTests {
    @Test("service selection validates allowlist and requires one before calibration")
    func serviceValidation() async throws {
        let (repository, sut) = makeSUT()
        let draft = try await sut.beginFirstOnboarding()

        await #expect(throws: ViewerProfileRepositoryError.validation(.emptyServiceSelection)) {
            _ = try await sut.beginCalibration(from: draft)
        }

        let unsupported = PilotStreamingService(
            providerID: 999,
            name: "Unsupported",
            productOrder: 0
        )
        await #expect(throws: ViewerProfileRepositoryError.validation(.unsupportedService)) {
            _ = try await sut.selectServices([unsupported], in: draft)
        }
        #expect(await repository.loadState() == .firstOnboarding(draft))
    }

    @Test("Back preserves answers and replacing a reaction recalculates raw signals")
    func backRevision() async throws {
        let (_, sut) = makeSUT()
        var draft = try await sut.beginFirstOnboarding()
        draft = try await sut.selectServices([.netflix], in: draft)
        draft = try await sut.beginCalibration(from: draft)
        draft = try await sut.react(.loveIt, in: draft)
        #expect(draft.currentCatalogPosition == 1)
        #expect(draft.informativeSignalCount == 1)

        draft = try await sut.goBack(in: draft)
        #expect(draft.currentCatalogPosition == 0)
        #expect(draft.reactions[238] == .loveIt)

        draft = try await sut.react(.haveNotSeenIt, in: draft)
        #expect(draft.currentCatalogPosition == 1)
        #expect(draft.reactions[238] == .haveNotSeenIt)
        #expect(draft.informativeSignalCount == 0)
    }

    @Test("zero-signal normal flow can explicitly continue and complete")
    func lowSignalContinue() async throws {
        let (_, sut) = makeSUT()
        var draft = try await sut.beginFirstOnboarding()
        draft = try await sut.selectServices([.netflix], in: draft)
        draft = try await sut.beginCalibration(from: draft)

        for _ in 0 ..< CalibrationFlow.normalLimit {
            draft = try await sut.react(.doNotKnowIt, in: draft)
        }
        #expect(draft.step == .lowSignalDecision)
        #expect(draft.informativeSignalCount == 0)

        draft = try await sut.continueWithLowSignals(in: draft)
        #expect(draft.step == .completion)
        let profile = try await sut.completeFirstOnboarding()
        #expect(profile.informativeSignalCount == 0)
    }

    @Test("optional extension answers remain bounded and can complete at exhaustion")
    func optionalExtensionExhaustion() async throws {
        let (_, sut) = makeSUT()
        var draft = try await sut.beginFirstOnboarding()
        draft = try await sut.selectServices([.netflix], in: draft)
        draft = try await sut.beginCalibration(from: draft)
        for _ in 0 ..< CalibrationFlow.normalLimit {
            draft = try await sut.react(.doNotKnowIt, in: draft)
        }
        draft = try await sut.acceptOptionalExtension(in: draft)
        for _ in 0 ..< 6 {
            draft = try await sut.react(.doNotKnowIt, in: draft)
        }

        #expect(draft.step == .completion)
        #expect(draft.currentCatalogPosition == 21)
        #expect(draft.reactions.count == 21)
    }

    private func makeSUT() -> (
        repository: DefaultViewerProfileRepository,
        useCase: ManageViewerProfile
    ) {
        let repository = DefaultViewerProfileRepository(
            store: InMemoryViewerProfileDataStore()
        )
        return (
            repository,
            ManageViewerProfile(
                repository: repository,
                catalog: ViewerProfileTestFixtures.catalog
            )
        )
    }
}

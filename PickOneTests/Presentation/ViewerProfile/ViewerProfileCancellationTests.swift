@testable import PickOne
import Testing

@MainActor
@Suite("Viewer profile cancellation")
struct ViewerProfileCancellationTests {
    @Test("late resolver success after Close cannot create a recalibration draft")
    func lateResolverSuccessAfterDismissalIsIgnored() async {
        let resolver = LateSuccessCatalogResolver()
        let manage = ViewerProfileManageSpy(
            loadStates: [
                .completed(profile: makeCompletedProfile(), recalibrationDraft: nil),
            ]
        )
        let sut = ViewerProfileViewModel(
            manageProfile: manage,
            getMovieMetadata: FailingCalibrationMetadata(),
            resolveCalibrationCatalog: resolver
        )
        await sut.load()

        let start = Task { await sut.startRecalibration() }
        await waitUntil { await resolver.didStartResolving }
        sut.dismissRecalibration()
        await resolver.succeed()
        await start.value

        #expect(await manage.recalibrationBeginCallCount == 0)
        #expect(sut.recalibrationDraft == nil)
        #expect(sut.presentedCalibration == nil)
        #expect(!sut.isResolvingCalibrationCatalog)
        #expect(sut.saveErrorMessage == nil)
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

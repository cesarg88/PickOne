@testable import PickOne
import Testing

@MainActor
@Suite("Viewer profile recovery availability")
struct ViewerProfileRecoveryAvailabilityTests {
    @Test("recovery displays destructive reset only when Domain authorizes total-source recovery")
    func recoveryDisplaysResetOnlyForTotalSourceFailure() async {
        let unavailable = makeSUT(
            reason: .loadFailed,
            availability: .unavailable
        )
        let available = makeSUT(
            reason: .corruptData,
            availability: .available
        )

        await unavailable.load()
        await available.load()

        #expect(!unavailable.canDestructivelyResetViewerState)
        #expect(available.canDestructivelyResetViewerState)
    }

    private func makeSUT(
        reason: ViewerProfileRecoveryReason,
        availability: DestructiveRecoveryAvailability
    ) -> ViewerProfileViewModel {
        ViewerProfileViewModel(
            manageProfile: ViewerProfileManageSpy(loadStates: [.recovery(reason)]),
            getMovieMetadata: FailingCalibrationMetadata(),
            resolveCalibrationCatalog: ImmediateCalibrationCatalogResolver(),
            resetUnrecoverableViewerState: DestructiveViewerStateRecoverySpy(
                availability: availability
            )
        )
    }
}

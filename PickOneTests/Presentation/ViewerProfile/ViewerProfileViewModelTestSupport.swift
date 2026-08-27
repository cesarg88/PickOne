@testable import PickOne

enum ViewerProfileViewModelTestError: Error {
    case failed
}

struct ConstantViewerStateRecoveryNotice: GetViewerStateRecoveryNoticeUseCase {
    let notice: ViewerStateRecoveryNotice?

    init(_ notice: ViewerStateRecoveryNotice?) {
        self.notice = notice
    }

    func execute() async -> ViewerStateRecoveryNotice? {
        notice
    }
}

actor DestructiveViewerStateRecoverySpy: ResetUnrecoverableViewerStateUseCase {
    let configuredAvailability: DestructiveRecoveryAvailability
    private(set) var callCount = 0

    init(availability: DestructiveRecoveryAvailability) {
        configuredAvailability = availability
    }

    func availability() -> DestructiveRecoveryAvailability {
        configuredAvailability
    }

    func execute() async throws {
        callCount += 1
    }
}

struct FailingCalibrationMetadata: GetCalibrationMovieMetadataUseCase {
    func execute(movieID _: Int) async throws -> CalibrationMovieMetadata {
        throw ViewerProfileViewModelTestError.failed
    }
}

func metadataValue(title: String) -> CalibrationMovieMetadata {
    CalibrationMovieMetadata(
        title: title,
        originalTitle: "Original title",
        releaseYear: 2026,
        posterPath: nil
    )
}

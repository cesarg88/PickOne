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
    private(set) var callCount = 0

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

protocol GetViewerStateRecoveryNoticeUseCase: Sendable {
    func execute() async -> ViewerStateRecoveryNotice?
}

struct GetViewerStateRecoveryNotice: GetViewerStateRecoveryNoticeUseCase {
    private let repository: any ViewerStateRecoveryNoticeRepository

    init(repository: any ViewerStateRecoveryNoticeRepository) {
        self.repository = repository
    }

    func execute() async -> ViewerStateRecoveryNotice? {
        await repository.recoveryNotice()
    }
}

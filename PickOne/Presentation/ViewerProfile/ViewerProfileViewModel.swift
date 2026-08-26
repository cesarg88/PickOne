import Foundation
import Observation

@MainActor
@Observable
final class ViewerProfileViewModel {
    private enum OperationResult: Equatable {
        case success
        case cancelled
        case failed
    }

    private enum RetryAction {
        case load
        case selectServices
        case beginCalibration
        case firstReaction(CalibrationReaction)
        case recalibrationReaction(CalibrationReaction)
        case firstBack
        case recalibrationBack
        case firstExtension
        case recalibrationExtension
        case lowSignalContinue
        case firstCompletion
        case recalibrationCompletion
        case startRecalibration
        case updateServices([PilotStreamingService])
        case resetDraft
        case resetProfile
        case destructiveRecovery
    }

    private let manageProfile: ManageViewerProfileUseCase
    private let getMovieMetadata: GetCalibrationMovieMetadataUseCase
    private let getRecoveryNotice: (any GetViewerStateRecoveryNoticeUseCase)?
    private let resetUnrecoverableViewerState: (any ResetUnrecoverableViewerStateUseCase)?
    private let resetsProfileForUITests: Bool
    private var retryAction: RetryAction?
    private var metadataLoadID = UUID()
    @ObservationIgnored private var metadataTask: Task<Void, Never>?
    private var didApplyUITestReset = false

    var rootState: AppRootViewState = .loading
    var firstDraft: FirstOnboardingDraft?
    var activeProfile: ViewerProfile?
    var recalibrationDraft: RecalibrationDraft?
    var presentedCalibration: CalibrationPresentationMode?
    var currentMovie: CalibrationMovieCardPresentationModel?
    var pendingReaction: CalibrationReaction?
    var saveErrorMessage: String?
    var isSaving = false
    var recoveryNotice: ViewerStateRecoveryNotice?

    var hasPendingCompletionRetry: Bool {
        switch retryAction {
            case .firstCompletion, .recalibrationCompletion:
                true
            default:
                false
        }
    }

    var catalog: CalibrationCatalog {
        manageProfile.catalog
    }

    init(
        manageProfile: ManageViewerProfileUseCase,
        getMovieMetadata: GetCalibrationMovieMetadataUseCase,
        getRecoveryNotice: (any GetViewerStateRecoveryNoticeUseCase)? = nil,
        resetUnrecoverableViewerState: (any ResetUnrecoverableViewerStateUseCase)? = nil,
        resetsProfileForUITests: Bool = false
    ) {
        self.manageProfile = manageProfile
        self.getMovieMetadata = getMovieMetadata
        self.getRecoveryNotice = getRecoveryNotice
        self.resetUnrecoverableViewerState = resetUnrecoverableViewerState
        self.resetsProfileForUITests = resetsProfileForUITests
    }

    func load() async {
        cancelMetadataHydration()
        rootState = .loading
        if resetsProfileForUITests, !didApplyUITestReset {
            didApplyUITestReset = true
            do {
                try await manageProfile.resetProfileAndDraft()
            } catch {
                showError(for: .load)
                return
            }
        }
        await apply(loadState: manageProfile.loadState())
        if case .recovery = rootState {
            recoveryNotice = nil
        } else {
            recoveryNotice = await getRecoveryNotice?.execute()
        }
    }

    func dismissRecoveryNotice() {
        recoveryNotice = nil
    }

    func toggleFirstOnboardingService(_ service: PilotStreamingService) async {
        guard !isSaving, let draft = firstDraft else { return }
        var services = draft.selectedServices
        if let index = services.firstIndex(where: { $0.providerID == service.providerID }) {
            services.remove(at: index)
        } else {
            services.append(service)
        }
        services = ordered(services)
        firstDraft = replacingServices(in: draft, with: services)
        await saveFirstServices()
    }

    func continueFromServices() async {
        guard let draft = firstDraft, !draft.selectedServices.isEmpty else { return }
        await perform(.beginCalibration) {
            self.firstDraft = try await self.manageProfile.beginCalibration(from: draft)
            self.presentCurrentMovie(mode: .firstOnboarding)
        }
    }

    func react(_ reaction: CalibrationReaction, mode: CalibrationPresentationMode) async {
        switch mode {
            case .firstOnboarding:
                guard let draft = firstDraft else { return }
                pendingReaction = reaction
                let result = await perform(.firstReaction(reaction)) {
                    self.firstDraft = try await self.manageProfile.react(reaction, in: draft)
                    self.pendingReaction = nil
                }
                if result == .cancelled {
                    pendingReaction = nil
                } else if result == .success {
                    await advanceAfterPersistedCalibration(mode: mode)
                }
            case .recalibration:
                guard let draft = recalibrationDraft else { return }
                pendingReaction = reaction
                let result = await perform(.recalibrationReaction(reaction)) {
                    self.recalibrationDraft = try await self.manageProfile.react(reaction, in: draft)
                    self.pendingReaction = nil
                }
                if result == .cancelled {
                    pendingReaction = nil
                } else if result == .success {
                    await advanceAfterPersistedCalibration(mode: mode)
                }
        }
    }

    func goBack(mode: CalibrationPresentationMode) async {
        switch mode {
            case .firstOnboarding:
                guard let draft = firstDraft else { return }
                await perform(.firstBack) {
                    self.firstDraft = try await self.manageProfile.goBack(in: draft)
                    self.presentCurrentMovieIfNeeded(mode: mode)
                }
            case .recalibration:
                guard let draft = recalibrationDraft else { return }
                if draft.currentCatalogPosition == 0 {
                    presentedCalibration = nil
                    return
                }
                await perform(.recalibrationBack) {
                    self.recalibrationDraft = try await self.manageProfile.goBack(in: draft)
                    self.presentCurrentMovie(mode: mode)
                }
        }
    }

    func acceptOptionalExtension(mode: CalibrationPresentationMode) async {
        switch mode {
            case .firstOnboarding:
                guard let draft = firstDraft else { return }
                await perform(.firstExtension) {
                    self.firstDraft = try await self.manageProfile.acceptOptionalExtension(in: draft)
                    self.presentCurrentMovie(mode: mode)
                }
            case .recalibration:
                guard let draft = recalibrationDraft else { return }
                await perform(.recalibrationExtension) {
                    self.recalibrationDraft = try await self.manageProfile.acceptOptionalExtension(in: draft)
                    self.presentCurrentMovie(mode: mode)
                }
        }
    }

    func continueWithLowSignals() async {
        guard let draft = firstDraft else { return }
        let result = await perform(.lowSignalContinue) {
            self.firstDraft = try await self.manageProfile.continueWithLowSignals(in: draft)
            self.clearCurrentMovie()
        }
        if result == .success {
            await complete(mode: .firstOnboarding)
        }
    }

    func complete(mode: CalibrationPresentationMode) async {
        switch mode {
            case .firstOnboarding:
                await perform(.firstCompletion) {
                    let profile = try await self.manageProfile.completeFirstOnboarding()
                    self.enterMain(profile: profile, recalibrationDraft: nil)
                }
            case .recalibration:
                await perform(.recalibrationCompletion) {
                    let profile = try await self.manageProfile.completeRecalibration()
                    self.enterMain(profile: profile, recalibrationDraft: nil)
                    self.presentedCalibration = nil
                }
        }
    }

    func startRecalibration() async {
        if recalibrationDraft != nil {
            presentedCalibration = .recalibration
            await advanceAfterPersistedCalibration(mode: .recalibration)
            return
        }
        await perform(.startRecalibration) {
            self.recalibrationDraft = try await self.manageProfile.beginRecalibration()
            self.presentedCalibration = .recalibration
            self.presentCurrentMovie(mode: .recalibration)
        }
    }

    func dismissRecalibration() {
        presentedCalibration = nil
        clearCurrentMovie()
    }

    func updateServices(_ services: [PilotStreamingService]) async -> Bool {
        guard !services.isEmpty else { return false }
        var succeeded = false
        await perform(.updateServices(services)) {
            self.activeProfile = try await self.manageProfile.updateServices(services)
            succeeded = true
        }
        return succeeded
    }

    func resetDraft() async {
        let resetsFirstOnboarding = activeProfile == nil
        let result = await perform(.resetDraft) {
            try await self.manageProfile.resetDraft()
            if !resetsFirstOnboarding {
                self.recalibrationDraft = nil
                self.presentedCalibration = nil
            }
            self.clearCurrentMovie()
        }
        if resetsFirstOnboarding, result == .success {
            firstDraft = nil
            rootState = .loading
            await load()
        }
    }

    func resetProfile() async {
        let result = await perform(.resetProfile) {
            try await self.manageProfile.resetProfileAndDraft()
        }
        guard result == .success else { return }
        activeProfile = nil
        recalibrationDraft = nil
        presentedCalibration = nil
        firstDraft = nil
        clearCurrentMovie()
        rootState = .loading
        await load()
    }

    func destructivelyResetUnrecoverableViewerState() async {
        guard let resetUnrecoverableViewerState else { return }
        let result = await perform(.destructiveRecovery) {
            try await resetUnrecoverableViewerState.execute()
        }
        guard result == .success else { return }
        recoveryNotice = nil
        activeProfile = nil
        recalibrationDraft = nil
        presentedCalibration = nil
        firstDraft = nil
        clearCurrentMovie()
        rootState = .loading
        await load()
    }

    func retryLastAction() async {
        saveErrorMessage = nil
        guard let retryAction else {
            await load()
            return
        }
        switch retryAction {
            case .load:
                await load()
            case .selectServices:
                await saveFirstServices()
            case .beginCalibration:
                await continueFromServices()
            case let .firstReaction(reaction):
                await react(reaction, mode: .firstOnboarding)
            case let .recalibrationReaction(reaction):
                await react(reaction, mode: .recalibration)
            case .firstBack:
                await goBack(mode: .firstOnboarding)
            case .recalibrationBack:
                await goBack(mode: .recalibration)
            case .firstExtension:
                await acceptOptionalExtension(mode: .firstOnboarding)
            case .recalibrationExtension:
                await acceptOptionalExtension(mode: .recalibration)
            case .lowSignalContinue:
                await continueWithLowSignals()
            case .firstCompletion:
                await complete(mode: .firstOnboarding)
            case .recalibrationCompletion:
                await complete(mode: .recalibration)
            case .startRecalibration:
                await startRecalibration()
            case let .updateServices(services):
                _ = await updateServices(services)
            case .resetDraft:
                await resetDraft()
            case .resetProfile:
                await resetProfile()
            case .destructiveRecovery:
                await destructivelyResetUnrecoverableViewerState()
        }
    }

    func currentDestination(for mode: CalibrationPresentationMode) -> CalibrationDestination? {
        switch mode {
            case .firstOnboarding:
                guard let draft = firstDraft else { return nil }
                if draft.step == .completion {
                    return .completion
                }
                return CalibrationFlow.destination(
                    position: draft.currentCatalogPosition,
                    reactions: draft.reactions,
                    optionalExtensionAccepted: draft.optionalExtensionAccepted,
                    catalog: catalog
                )
            case .recalibration:
                guard let draft = recalibrationDraft else { return nil }
                return CalibrationFlow.destination(
                    position: draft.currentCatalogPosition,
                    reactions: draft.reactions,
                    optionalExtensionAccepted: draft.optionalExtensionAccepted,
                    catalog: catalog
                )
        }
    }

    func draftPosition(for mode: CalibrationPresentationMode) -> Int {
        switch mode {
            case .firstOnboarding: firstDraft?.currentCatalogPosition ?? 0
            case .recalibration: recalibrationDraft?.currentCatalogPosition ?? 0
        }
    }

    func reactionForCurrentMovie(mode: CalibrationPresentationMode) -> CalibrationReaction? {
        let position = draftPosition(for: mode)
        guard catalog.movies.indices.contains(position) else { return nil }
        let movieID = catalog.movies[position].id
        switch mode {
            case .firstOnboarding: return firstDraft?.reactions[movieID]
            case .recalibration: return recalibrationDraft?.reactions[movieID]
        }
    }
}

private extension ViewerProfileViewModel {
    private func apply(loadState: ViewerProfileLoadState) async {
        saveErrorMessage = nil
        switch loadState {
            case .absent:
                do {
                    firstDraft = try await manageProfile.beginFirstOnboarding()
                    rootState = .onboarding
                } catch {
                    showError(for: .load)
                }
            case let .firstOnboarding(draft):
                firstDraft = draft
                rootState = .onboarding
                await advanceAfterPersistedCalibration(mode: .firstOnboarding)
            case let .completed(profile, draft):
                enterMain(profile: profile, recalibrationDraft: draft)
            case let .recovery(reason):
                clearCurrentMovie()
                rootState = .recovery(reason)
                retryAction = .load
        }
    }

    private func saveFirstServices() async {
        guard let draft = firstDraft else { return }
        await perform(.selectServices) {
            self.firstDraft = try await self.manageProfile.selectServices(
                draft.selectedServices,
                in: draft
            )
        }
    }

    private func presentCurrentMovieIfNeeded(mode: CalibrationPresentationMode) {
        guard case .movie = currentDestination(for: mode) else {
            clearCurrentMovie()
            return
        }
        presentCurrentMovie(mode: mode)
    }

    private func advanceAfterPersistedCalibration(
        mode: CalibrationPresentationMode
    ) async {
        if currentDestination(for: mode) == .completion {
            clearCurrentMovie()
            await complete(mode: mode)
        } else {
            presentCurrentMovieIfNeeded(mode: mode)
        }
    }

    private func presentCurrentMovie(mode: CalibrationPresentationMode) {
        let position = draftPosition(for: mode)
        guard catalog.movies.indices.contains(position) else {
            clearCurrentMovie()
            return
        }
        let movie = catalog.movies[position]
        cancelMetadataHydration()
        currentMovie = CalibrationMoviePresentationMapper.map(
            catalogMovie: movie,
            metadata: nil
        )
        guard !AppConfiguration.isUITesting else { return }

        let loadID = UUID()
        metadataLoadID = loadID
        let metadataProvider = getMovieMetadata
        metadataTask = Task { [weak self, metadataProvider] in
            do {
                let metadata = try await metadataProvider.execute(movieID: movie.id)
                try Task.checkCancellation()
                guard let self,
                      metadataLoadID == loadID,
                      draftPosition(for: mode) == position,
                      currentMovie?.id == movie.id
                else { return }
                currentMovie = CalibrationMoviePresentationMapper.map(
                    catalogMovie: movie,
                    metadata: metadata
                )
                metadataTask = nil
            } catch {
                // The bundled recognition metadata is the stable fallback.
                if self?.metadataLoadID == loadID {
                    self?.metadataTask = nil
                }
            }
        }
    }

    private func clearCurrentMovie() {
        cancelMetadataHydration()
        currentMovie = nil
    }

    private func cancelMetadataHydration() {
        metadataTask?.cancel()
        metadataTask = nil
        metadataLoadID = UUID()
    }

    private func enterMain(
        profile: ViewerProfile,
        recalibrationDraft: RecalibrationDraft?
    ) {
        clearCurrentMovie()
        activeProfile = profile
        self.recalibrationDraft = recalibrationDraft
        firstDraft = nil
        rootState = .main
    }

    private func replacingServices(
        in draft: FirstOnboardingDraft,
        with services: [PilotStreamingService]
    ) -> FirstOnboardingDraft {
        FirstOnboardingDraft(
            catalogID: draft.catalogID,
            step: draft.step,
            selectedServices: services,
            reactions: draft.reactions,
            currentCatalogPosition: draft.currentCatalogPosition,
            optionalExtensionAccepted: draft.optionalExtensionAccepted
        )
    }

    private func ordered(_ services: [PilotStreamingService]) -> [PilotStreamingService] {
        let ids = Set(services.map(\.providerID))
        return PilotStreamingService.allowlist.filter { ids.contains($0.providerID) }
    }

    @discardableResult
    private func perform(
        _ action: RetryAction,
        operation: () async throws -> Void
    ) async -> OperationResult {
        guard !isSaving else { return .failed }
        isSaving = true
        defer { isSaving = false }
        do {
            try await operation()
            retryAction = nil
            saveErrorMessage = nil
            return .success
        } catch is CancellationError {
            return .cancelled
        } catch {
            showError(for: action)
            return .failed
        }
    }

    private func showError(for action: RetryAction) {
        retryAction = action
        saveErrorMessage = "Your preferences couldn't be saved. Please try again."
        if case .load = action {
            rootState = .recovery(.loadFailed)
        }
    }
}

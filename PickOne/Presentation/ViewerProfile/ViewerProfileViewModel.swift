import Foundation
import Observation

@MainActor
@Observable
final class ViewerProfileViewModel {
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
    }

    private let manageProfile: ManageViewerProfileUseCase
    private let getMovieMetadata: GetCalibrationMovieMetadataUseCase
    private let resetsProfileForUITests: Bool
    private var retryAction: RetryAction?
    private var metadataLoadID = UUID()
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

    var catalog: CalibrationCatalog {
        manageProfile.catalog
    }

    init(
        manageProfile: ManageViewerProfileUseCase,
        getMovieMetadata: GetCalibrationMovieMetadataUseCase,
        resetsProfileForUITests: Bool = false
    ) {
        self.manageProfile = manageProfile
        self.getMovieMetadata = getMovieMetadata
        self.resetsProfileForUITests = resetsProfileForUITests
    }

    func load() async {
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
            await self.loadCurrentMovie(mode: .firstOnboarding)
        }
    }

    func react(_ reaction: CalibrationReaction, mode: CalibrationPresentationMode) async {
        pendingReaction = reaction
        switch mode {
            case .firstOnboarding:
                guard let draft = firstDraft else { return }
                await perform(.firstReaction(reaction)) {
                    self.firstDraft = try await self.manageProfile.react(reaction, in: draft)
                    self.pendingReaction = nil
                    await self.loadCurrentMovieIfNeeded(mode: mode)
                }
            case .recalibration:
                guard let draft = recalibrationDraft else { return }
                await perform(.recalibrationReaction(reaction)) {
                    self.recalibrationDraft = try await self.manageProfile.react(reaction, in: draft)
                    self.pendingReaction = nil
                    await self.loadCurrentMovieIfNeeded(mode: mode)
                }
        }
    }

    func goBack(mode: CalibrationPresentationMode) async {
        switch mode {
            case .firstOnboarding:
                guard let draft = firstDraft else { return }
                await perform(.firstBack) {
                    self.firstDraft = try await self.manageProfile.goBack(in: draft)
                    await self.loadCurrentMovieIfNeeded(mode: mode)
                }
            case .recalibration:
                guard let draft = recalibrationDraft else { return }
                if draft.currentCatalogPosition == 0 {
                    presentedCalibration = nil
                    return
                }
                await perform(.recalibrationBack) {
                    self.recalibrationDraft = try await self.manageProfile.goBack(in: draft)
                    await self.loadCurrentMovie(mode: mode)
                }
        }
    }

    func acceptOptionalExtension(mode: CalibrationPresentationMode) async {
        switch mode {
            case .firstOnboarding:
                guard let draft = firstDraft else { return }
                await perform(.firstExtension) {
                    self.firstDraft = try await self.manageProfile.acceptOptionalExtension(in: draft)
                    await self.loadCurrentMovie(mode: mode)
                }
            case .recalibration:
                guard let draft = recalibrationDraft else { return }
                await perform(.recalibrationExtension) {
                    self.recalibrationDraft = try await self.manageProfile.acceptOptionalExtension(in: draft)
                    await self.loadCurrentMovie(mode: mode)
                }
        }
    }

    func continueWithLowSignals() async {
        guard let draft = firstDraft else { return }
        await perform(.lowSignalContinue) {
            self.firstDraft = try await self.manageProfile.continueWithLowSignals(in: draft)
            self.currentMovie = nil
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
            await loadCurrentMovieIfNeeded(mode: .recalibration)
            return
        }
        await perform(.startRecalibration) {
            self.recalibrationDraft = try await self.manageProfile.beginRecalibration()
            self.presentedCalibration = .recalibration
            await self.loadCurrentMovie(mode: .recalibration)
        }
    }

    func dismissRecalibration() {
        presentedCalibration = nil
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
        await perform(.resetDraft) {
            try await self.manageProfile.resetDraft()
            if self.activeProfile == nil {
                self.firstDraft = try await self.manageProfile.beginFirstOnboarding()
                self.rootState = .onboarding
            } else {
                self.recalibrationDraft = nil
                self.presentedCalibration = nil
            }
            self.currentMovie = nil
        }
    }

    func resetProfile() async {
        await perform(.resetProfile) {
            try await self.manageProfile.resetProfileAndDraft()
            self.activeProfile = nil
            self.recalibrationDraft = nil
            self.presentedCalibration = nil
            self.firstDraft = try await self.manageProfile.beginFirstOnboarding()
            self.rootState = .onboarding
            self.currentMovie = nil
        }
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
        }
    }

    func currentDestination(for mode: CalibrationPresentationMode) -> CalibrationDestination? {
        switch mode {
            case .firstOnboarding:
                guard let draft = firstDraft else { return nil }
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
                await loadCurrentMovieIfNeeded(mode: .firstOnboarding)
            case let .completed(profile, draft):
                enterMain(profile: profile, recalibrationDraft: draft)
            case let .recovery(reason):
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

    private func loadCurrentMovieIfNeeded(mode: CalibrationPresentationMode) async {
        guard case .movie = currentDestination(for: mode) else {
            currentMovie = nil
            return
        }
        await loadCurrentMovie(mode: mode)
    }

    private func loadCurrentMovie(mode: CalibrationPresentationMode) async {
        let position = draftPosition(for: mode)
        guard catalog.movies.indices.contains(position) else {
            currentMovie = nil
            return
        }
        let movie = catalog.movies[position]
        currentMovie = CalibrationMoviePresentationMapper.map(
            catalogMovie: movie,
            metadata: nil
        )
        guard !AppConfiguration.isUITesting else { return }

        let loadID = UUID()
        metadataLoadID = loadID
        do {
            let metadata = try await getMovieMetadata.execute(movieID: movie.id)
            try Task.checkCancellation()
            guard metadataLoadID == loadID, draftPosition(for: mode) == position else { return }
            currentMovie = CalibrationMoviePresentationMapper.map(
                catalogMovie: movie,
                metadata: metadata
            )
        } catch {
            // The bundled recognition metadata is the stable fallback.
        }
    }

    private func enterMain(
        profile: ViewerProfile,
        recalibrationDraft: RecalibrationDraft?
    ) {
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

    private func perform(
        _ action: RetryAction,
        operation: () async throws -> Void
    ) async {
        guard !isSaving else { return }
        isSaving = true
        defer { isSaving = false }
        do {
            try await operation()
            retryAction = nil
            saveErrorMessage = nil
        } catch is CancellationError {
            return
        } catch {
            showError(for: action)
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

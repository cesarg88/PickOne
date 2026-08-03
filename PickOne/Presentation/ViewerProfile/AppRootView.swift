import SwiftUI

@MainActor
struct AppRootView: View {
    let container: AppContainer
    @Bindable var profileModel: ViewerProfileViewModel

    var body: some View {
        Group {
            switch profileModel.rootState {
                case .loading:
                    ProgressView("Loading preferences...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                case .onboarding:
                    FirstOnboardingView(
                        model: profileModel,
                        imagePipeline: container.imagePipeline
                    )
                case .main:
                    MainTabView(
                        container: container,
                        profileModel: profileModel
                    )
                case let .recovery(reason):
                    ViewerProfileRecoveryView(
                        reason: reason,
                        tryAgain: { Task { await profileModel.load() } },
                        reset: { Task { await profileModel.resetProfile() } }
                    )
            }
        }
        .task {
            guard profileModel.rootState == .loading else { return }
            await profileModel.load()
        }
        .alert(
            "Couldn't save preferences",
            isPresented: Binding(
                get: { profileModel.saveErrorMessage != nil },
                set: { if !$0 { profileModel.saveErrorMessage = nil } }
            )
        ) {
            Button("Try again") {
                Task { await profileModel.retryLastAction() }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text(profileModel.saveErrorMessage ?? "Please try again.")
        }
    }
}

@MainActor
private struct ViewerProfileRecoveryView: View {
    let reason: ViewerProfileRecoveryReason
    let tryAgain: () -> Void
    let reset: () -> Void

    private var title: String {
        switch reason {
            case .unsupportedVersion: ViewerProfileCopy.unsupportedTitle
            case .corruptData: ViewerProfileCopy.corruptTitle
            case .loadFailed: "Preferences couldn't be loaded"
        }
    }

    private var message: String {
        switch reason {
            case .unsupportedVersion:
                ViewerProfileCopy.unsupportedBody
            case .corruptData:
                ViewerProfileCopy.corruptBody
            case .loadFailed:
                "Your saved preferences couldn't be loaded. Your data was preserved."
        }
    }

    var body: some View {
        ContentUnavailableView {
            Label(title, systemImage: "exclamationmark.triangle")
        } description: {
            Text(message)
        } actions: {
            Button("Try again", action: tryAgain)
            if reason != .loadFailed {
                Button("Reset preferences", role: .destructive, action: reset)
            }
        }
    }
}

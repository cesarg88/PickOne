import SwiftUI

@MainActor
struct AppRootView: View {
    let container: AppContainer
    @Bindable var profileModel: ViewerProfileViewModel
    @State private var showsDestructiveResetConfirmation = false

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
                        reset: profileModel.canDestructivelyResetViewerState
                            ? { showsDestructiveResetConfirmation = true }
                            : nil
                    )
            }
        }
        .safeAreaInset(edge: .top) {
            if showsRecoveryNotice {
                ViewerStateRecoveryNoticeView(
                    dismiss: profileModel.dismissRecoveryNotice
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
        .confirmationDialog(
            "Reset all movie data?",
            isPresented: $showsDestructiveResetConfirmation,
            titleVisibility: .visible
        ) {
            Button("Reset all movie data", role: .destructive) {
                Task { await profileModel.destructivelyResetUnrecoverableViewerState() }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text(
                "This will delete your preferences, watched history, Watchlist, " +
                    "and movie feedback. Search History will not be deleted."
            )
        }
    }

    private var showsRecoveryNotice: Bool {
        guard profileModel.recoveryNotice == .olderSnapshot else { return false }
        return switch profileModel.rootState {
            case .onboarding, .main: true
            case .loading, .recovery: false
        }
    }
}

@MainActor
private struct ViewerStateRecoveryNoticeView: View {
    let dismiss: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "arrow.counterclockwise.circle.fill")
                .foregroundStyle(.orange)
                .accessibilityHidden(true)
            Text("We recovered an earlier saved version of your movie data. Please review it in Settings.")
                .font(.footnote)
                .frame(maxWidth: .infinity, alignment: .leading)
            Button("Dismiss", systemImage: "xmark", action: dismiss)
                .labelStyle(.iconOnly)
        }
        .padding()
        .background(.regularMaterial)
        .accessibilityElement(children: .combine)
    }
}

@MainActor
private struct ViewerProfileRecoveryView: View {
    let reason: ViewerProfileRecoveryReason
    let tryAgain: () -> Void
    let reset: (() -> Void)?

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
                "Your saved movie data couldn't be loaded. Your data was preserved."
        }
    }

    var body: some View {
        ContentUnavailableView {
            Label(title, systemImage: "exclamationmark.triangle")
        } description: {
            Text(message)
        } actions: {
            Button("Try again", action: tryAgain)
            if let reset {
                Button("Reset all movie data", role: .destructive, action: reset)
            }
        }
    }
}

import SwiftUI

@MainActor
struct HomePickControl: View {
    let model: HomePickViewModel
    let movieID: Int
    let title: String

    private var isPicked: Bool {
        model.activeDecision?.recommendation.movieID == movieID
    }

    private var isSaving: Bool {
        model.savingMovieIDs.contains(movieID)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button {
                if isPicked { model.cancel() } else { model.pick(movieID: movieID, title: title) }
            } label: {
                HStack(spacing: 8) {
                    if isSaving {
                        ProgressView()
                            .controlSize(.small)
                            .accessibilityHidden(true)
                        Text("Saving...")
                    } else if isPicked {
                        Label("Picked", systemImage: "checkmark")
                    } else {
                        Text("Pick")
                    }
                }
                .frame(minWidth: 124, minHeight: 44)
            }
            .buttonStyle(.glass)
            .disabled(isSaving)
            .accessibilityLabel(isSaving
                ? (isPicked ? Text("Saving cancellation of \(title)") : savingPickLabel)
                : (isPicked ? Text("Picked: \(title)") : Text("Pick \(title)")))
            .accessibilityHint(isPicked
                ? Text("Cancels this choice without changing watched status.")
                : Text("Records your choice without marking the movie watched."))
            .accessibilityIdentifier("home-pick-\(movieID)")
            .onAppear { model.rememberVisibleTitle(title, movieID: movieID) }
            .onChange(of: title) { model.rememberVisibleTitle(title, movieID: movieID) }
            .onChange(of: isPicked) { model.rememberVisibleTitle(title, movieID: movieID) }

            if model.failedMovieIDs.contains(movieID) {
                Text(isPicked
                    ? "Your choice couldn't be cancelled. Please try again."
                    : "Your choice couldn't be saved. Please try again.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                Button("Try again") { model.retry(movieID: movieID) }
                    .disabled(isSaving)
                    .accessibilityLabel(isPicked
                        ? Text("Retry cancelling your choice of \(title)")
                        : Text("Retry saving your choice of \(title)"))
                    .accessibilityIdentifier("home-pick-retry-\(movieID)")
            }
        }
    }

    private var savingPickLabel: Text {
        if let replacedTitle = model.activePickTitle {
            Text("Saving \(title) as your choice instead of \(replacedTitle)")
        } else {
            Text("Saving your choice of \(title)")
        }
    }
}

@MainActor
struct HomePickSuccessNotice: View {
    let feedback: HomePickAcknowledgement

    var body: some View {
        Label {
            switch feedback {
                case let .picked(title?, replacedTitle?):
                    Text("You picked \(title) instead of \(replacedTitle).")
                case let .picked(title?, nil):
                    Text("You picked \(title).")
                case .picked(nil, _):
                    Text("You have a Pick")
                case .cancelled:
                    Text("Choice cancelled.")
            }
        } icon: {
            Image(systemName: "checkmark.circle.fill")
                .accessibilityHidden(true)
        }
        .font(.subheadline)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 12)
        .frame(minHeight: 44)
        .accessibilityAddTraits(.updatesFrequently)
    }
}

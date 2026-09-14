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
                if isPicked { model.cancel() } else { model.pick(movieID: movieID) }
            } label: {
                HStack {
                    if isSaving { ProgressView().controlSize(.small).accessibilityHidden(true) }
                    Label(
                        isPicked ? "Picked" : "Pick",
                        systemImage: isPicked ? "checkmark.circle.fill" : "checkmark.circle"
                    )
                }
            }
            .buttonStyle(.bordered)
            .disabled(isSaving)
            .accessibilityLabel(isPicked ? Text("Picked: \(title)") : Text("Pick \(title)"))
            .accessibilityHint(isPicked
                ? Text("Cancels this choice without changing watched status.")
                : Text("Records your choice without marking the movie watched."))
            .accessibilityIdentifier("home-pick-\(movieID)")

            if model.failedMovieIDs.contains(movieID) {
                Text("Your choice couldn't be saved. Please try again.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                Button("Try again") { model.retry(movieID: movieID) }
                    .accessibilityIdentifier("home-pick-retry-\(movieID)")
            }
        }
    }
}

@MainActor
struct HomeActivePickControl: View {
    let model: HomePickViewModel
    let decision: ViewingDecision

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("You have a Pick", systemImage: "checkmark.circle.fill")
                .font(.subheadline)
            Button("Cancel Pick") { model.cancel() }
                .disabled(model.savingMovieIDs.contains(decision.recommendation.movieID))
                .accessibilityIdentifier("home-cancel-pick")
            if model.failedMovieIDs.contains(decision.recommendation.movieID) {
                Text("Your choice couldn't be saved. Please try again.").font(.footnote)
                Button("Try again") { model.retry(movieID: decision.recommendation.movieID) }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(.thinMaterial)
    }
}

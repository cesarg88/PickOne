import SwiftUI

@MainActor
struct ViewingConfirmationView: View {
    let model: ViewingConfirmationViewModel
    var showsManual = false

    private var decisions: [ViewingDecision] {
        showsManual ? model.manual : [model.automatic].compactMap { $0 }
    }

    var body: some View {
        if model.satisfaction != nil || !decisions.isEmpty || model.failure {
            ScrollView {
                VStack(alignment: .leading, spacing: 10) {
                    if let decision = model.satisfaction {
                        Text("What did you think?").font(.headline)
                        movieTitle(decision)
                        ForEach(MovieReaction.allCases, id: \.rawValue) { reaction in
                            Button(reaction.confirmationLabel) { model.react(reaction, to: decision) }
                                .accessibilityIdentifier("confirmation-reaction-\(reaction.rawValue)")
                                .disabled(model.failure)
                        }
                        Button("Not now") { model.skipSatisfaction() }
                            .accessibilityIdentifier("confirmation-not-now")
                            .disabled(model.failure)
                    } else {
                        if showsManual { Text("Pending confirmations").font(.headline) }
                        ForEach(decisions, id: \.id) { decision in
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Did you watch it?").font(.headline)
                                movieTitle(decision)
                                Button("Yes, I watched it") { model.watched(decision) }
                                    .accessibilityIdentifier("confirmation-watched")
                                Button("Not yet") { model.postpone(decision) }
                                    .accessibilityIdentifier("confirmation-not-yet")
                                Button("I didn't watch it after all") { model.notWatched(decision) }
                                    .accessibilityIdentifier("confirmation-not-watched")
                            }
                            .disabled(model.failure)
                        }
                    }
                    if model.failure {
                        Text("Couldn't save your answer. Please try again.")
                            .font(.footnote)
                        Button("Retry") { model.retry() }.accessibilityIdentifier("confirmation-retry")
                    }
                    if model.isSaving { ProgressView().accessibilityLabel("Saving your answer") }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
                .disabled(model.isSaving)
            }
            .frame(maxHeight: 300)
            .background(.thinMaterial)
            .accessibilityIdentifier("viewing-confirmation")
        }
    }

    private func movieTitle(_ decision: ViewingDecision) -> some View {
        Text(model.titles[decision.recommendation.movieID] ?? String(localized: "Your picked movie"))
            .font(.subheadline)
    }
}

extension MovieReaction {
    var confirmationLabel: String {
        switch self {
            case .loveIt: String(localized: "Love it")
            case .likeIt: String(localized: "Like it")
            case .itWasOkay: String(localized: "It was okay")
            case .didNotLikeIt: String(localized: "Didn't like it")
        }
    }
}

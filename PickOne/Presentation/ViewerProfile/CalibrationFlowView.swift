import SwiftUI

@MainActor
struct CalibrationFlowView: View {
    @Bindable var model: ViewerProfileViewModel
    let mode: CalibrationPresentationMode
    let imagePipeline: ImagePipeline
    @State private var confirmsCancelCalibration = false

    var body: some View {
        Group {
            switch model.currentDestination(for: mode) {
                case .movie:
                    movieCard
                case .lowSignalDecision:
                    lowSignalDecision
                case .completion:
                    completion
                case nil:
                    ProgressView()
            }
        }
        .navigationTitle(mode == .firstOnboarding ? "Taste calibration" : "Repeat calibration")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if mode == .recalibration {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") {
                        model.dismissRecalibration()
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Cancel calibration", role: .destructive) {
                        confirmsCancelCalibration = true
                    }
                }
            }
        }
        .confirmationDialog(
            "Cancel this calibration?",
            isPresented: $confirmsCancelCalibration,
            titleVisibility: .visible
        ) {
            Button("Cancel calibration", role: .destructive) {
                Task { await model.resetDraft() }
            }
            Button("Keep calibration", role: .cancel) {}
        } message: {
            Text("Your current saved preferences will stay unchanged.")
        }
    }

    private var movieCard: some View {
        ScrollView {
            VStack(spacing: 18) {
                Text(ViewerProfileCopy.progress)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)

                Text("Movie \(model.draftPosition(for: mode) + 1)")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)

                if let movie = model.currentMovie {
                    RemoteImageView(
                        url: movie.posterURL,
                        loader: imagePipeline,
                        contentMode: .fill,
                        accessibilityLabel: movie.fallbackTitle
                    )
                    .frame(width: 210, height: 315)
                    .clipShape(RoundedRectangle(cornerRadius: 14))

                    VStack(spacing: 4) {
                        Text(movie.primaryText)
                            .font(.title2.bold())
                            .multilineTextAlignment(.center)
                        if let secondary = movie.secondaryText {
                            Text(secondary)
                                .font(.headline)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                        }
                    }
                }

                reactionButtons

                Button("Back") {
                    Task { await model.goBack(mode: mode) }
                }
                .disabled(model.isSaving)
            }
            .padding()
        }
    }

    private var reactionButtons: some View {
        LazyVGrid(
            columns: [GridItem(.flexible()), GridItem(.flexible())],
            spacing: 10
        ) {
            ForEach(CalibrationReaction.allCases, id: \.rawValue) { reaction in
                Button(reaction.title) {
                    Task { await model.react(reaction, mode: mode) }
                }
                .buttonStyle(.borderedProminent)
                .tint(selectedReaction == reaction ? .accentColor : .secondary)
                .disabled(model.isSaving)
            }
        }
    }

    private var selectedReaction: CalibrationReaction? {
        model.pendingReaction ?? model.reactionForCurrentMovie(mode: mode)
    }

    private var lowSignalDecision: some View {
        VStack(spacing: 20) {
            Spacer()
            Text(ViewerProfileCopy.lowSignalTitle)
                .font(.largeTitle.bold())
                .multilineTextAlignment(.center)
            Text(ViewerProfileCopy.lowSignalBody)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Spacer()
            Button("Rate more movies") {
                Task { await model.acceptOptionalExtension(mode: mode) }
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            if mode == .firstOnboarding {
                Button("Continue") {
                    Task { await model.continueWithLowSignals() }
                }
            } else {
                Button("Continue") {
                    Task { await model.complete(mode: mode) }
                }
            }
        }
        .padding()
    }

    private var completion: some View {
        VStack(spacing: 20) {
            Spacer()
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 64))
                .foregroundStyle(.green)
            Text(ViewerProfileCopy.completionTitle)
                .font(.largeTitle.bold())
                .multilineTextAlignment(.center)
            Text(ViewerProfileCopy.completionBody)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Spacer()
            Button("Continue") {
                Task { await model.complete(mode: mode) }
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(model.isSaving)
        }
        .padding()
    }
}

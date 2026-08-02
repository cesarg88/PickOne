import SwiftUI

@MainActor
struct FirstOnboardingView: View {
    @Bindable var model: ViewerProfileViewModel
    let imagePipeline: ImagePipeline
    @State private var confirmsStartOver = false

    var body: some View {
        NavigationStack {
            Group {
                if model.firstDraft?.step == .services {
                    StreamingServiceSelectionView(
                        selectedServices: model.firstDraft?.selectedServices ?? [],
                        isSaving: model.isSaving,
                        toggle: { service in
                            Task { await model.toggleFirstOnboardingService(service) }
                        },
                        continueAction: {
                            Task { await model.continueFromServices() }
                        }
                    )
                } else {
                    CalibrationFlowView(
                        model: model,
                        mode: .firstOnboarding,
                        imagePipeline: imagePipeline
                    )
                }
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Start over") {
                        confirmsStartOver = true
                    }
                }
            }
            .confirmationDialog(
                "Start onboarding over?",
                isPresented: $confirmsStartOver,
                titleVisibility: .visible
            ) {
                Button("Start over", role: .destructive) {
                    Task { await model.resetDraft() }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This clears only your saved onboarding progress.")
            }
        }
    }
}

@MainActor
struct StreamingServiceSelectionView: View {
    let selectedServices: [PilotStreamingService]
    let isSaving: Bool
    let toggle: (PilotStreamingService) -> Void
    let continueAction: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            VStack(alignment: .leading, spacing: 8) {
                Text(ViewerProfileCopy.serviceTitle)
                    .font(.largeTitle.bold())
                Text(ViewerProfileCopy.region)
                    .font(.headline)
                    .foregroundStyle(.secondary)
                Text(ViewerProfileCopy.serviceGuidance)
                    .foregroundStyle(.secondary)
            }

            VStack(spacing: 12) {
                ForEach(PilotStreamingService.allowlist, id: \.providerID) { service in
                    Button {
                        toggle(service)
                    } label: {
                        HStack {
                            Text(service.preferencesName)
                                .foregroundStyle(.primary)
                            Spacer()
                            Image(
                                systemName: isSelected(service)
                                    ? "checkmark.circle.fill"
                                    : "circle"
                            )
                            .font(.title2)
                        }
                        .padding()
                        .background(Color(.secondarySystemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .buttonStyle(.plain)
                    .accessibilityValue(isSelected(service) ? "Selected" : "Not selected")
                    .disabled(isSaving)
                }
            }

            Spacer()

            Button("Continue", action: continueAction)
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .frame(maxWidth: .infinity)
                .disabled(selectedServices.isEmpty || isSaving)
        }
        .padding()
    }

    private func isSelected(_ service: PilotStreamingService) -> Bool {
        selectedServices.contains { $0.providerID == service.providerID }
    }
}

import SwiftUI

@MainActor
struct SettingsView: View {
    @Bindable var model: ViewerProfileViewModel
    @State private var confirmsResetProfile = false

    var body: some View {
        NavigationStack {
            List {
                Section("Preferences") {
                    NavigationLink("Streaming services") {
                        EditStreamingServicesView(model: model)
                    }

                    Button(
                        model.recalibrationDraft == nil
                            ? "Repeat calibration"
                            : "Continue calibration"
                    ) {
                        Task { await model.startRecalibration() }
                    }

                    Button("Reset preferences", role: .destructive) {
                        confirmsResetProfile = true
                    }
                }

                Section {
                    NavigationLink("About") {
                        AboutView(showsDoneButton: false)
                    }
                }
            }
            .navigationTitle("Settings")
            .confirmationDialog(
                ViewerProfileCopy.resetTitle,
                isPresented: $confirmsResetProfile,
                titleVisibility: .visible
            ) {
                Button("Reset preferences", role: .destructive) {
                    Task { await model.resetProfile() }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text(ViewerProfileCopy.resetBody)
            }
        }
    }
}

@MainActor
private struct EditStreamingServicesView: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable var model: ViewerProfileViewModel
    @State private var selectedProviderIDs: Set<Int>

    init(model: ViewerProfileViewModel) {
        self.model = model
        _selectedProviderIDs = State(
            initialValue: Set(model.activeProfile?.selectedServices.map(\.providerID) ?? [])
        )
    }

    var body: some View {
        List {
            Section {
                Text(ViewerProfileCopy.region)
                    .foregroundStyle(.secondary)
            }

            Section("Streaming services") {
                ForEach(PilotStreamingService.allowlist, id: \.providerID) { service in
                    Button {
                        toggle(service)
                    } label: {
                        HStack {
                            Text(service.preferencesName)
                                .foregroundStyle(.primary)
                            Spacer()
                            if selectedProviderIDs.contains(service.providerID) {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle("Streaming services")
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") {
                    Task {
                        let services = PilotStreamingService.allowlist.filter {
                            selectedProviderIDs.contains($0.providerID)
                        }
                        if await model.updateServices(services) {
                            dismiss()
                        }
                    }
                }
                .disabled(selectedProviderIDs.isEmpty || model.isSaving)
            }
        }
    }

    private func toggle(_ service: PilotStreamingService) {
        if selectedProviderIDs.contains(service.providerID) {
            selectedProviderIDs.remove(service.providerID)
        } else {
            selectedProviderIDs.insert(service.providerID)
        }
    }
}

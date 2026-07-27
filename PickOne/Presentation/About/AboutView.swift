import SwiftUI

@MainActor
struct AboutView: View {
    @Environment(\.dismiss) private var dismiss

    private var versionText: String {
        let version = Bundle.main.object(
            forInfoDictionaryKey: "CFBundleShortVersionString"
        ) as? String ?? "—"
        let build = Bundle.main.object(
            forInfoDictionaryKey: "CFBundleVersion"
        ) as? String ?? "—"
        return "Version \(version) (\(build))"
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    Image("PilotIcon")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 96, height: 96)
                        .clipShape(RoundedRectangle(cornerRadius: 22))

                    VStack(spacing: 6) {
                        Text("PickOne")
                            .font(.title.bold())
                        Text(versionText)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }

                    Divider()

                    VStack(spacing: 16) {
                        Image("TMDBLogo")
                            .resizable()
                            .scaledToFit()
                            .frame(maxWidth: 140, maxHeight: 100)
                            .accessibilityLabel("The Movie Database")

                        Text(
                            "This product uses the TMDB API but is not endorsed or certified by TMDB."
                        )
                        .font(.footnote)
                        .multilineTextAlignment(.center)

                        Link(
                            "Visit The Movie Database",
                            destination: URL(string: "https://www.themoviedb.org")!
                        )
                        .font(.footnote.weight(.semibold))
                    }
                }
                .padding(24)
                .frame(maxWidth: .infinity)
            }
            .navigationTitle("About")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

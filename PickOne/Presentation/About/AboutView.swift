import SwiftUI

@MainActor
struct AboutView: View {
    @Environment(\.dismiss) private var dismiss
    let showsDoneButton: Bool

    init(showsDoneButton: Bool = true) {
        self.showsDoneButton = showsDoneButton
    }

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
        Group {
            if showsDoneButton {
                NavigationStack {
                    content
                        .toolbar { doneToolbar }
                }
            } else {
                content
            }
        }
    }

    private var content: some View {
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

                    Text(
                        "Streaming availability data is provided by JustWatch."
                    )
                    .font(.footnote)
                    .multilineTextAlignment(.center)

                    if let tmdbURL = URL(string: "https://www.themoviedb.org") {
                        Link(
                            "Visit The Movie Database",
                            destination: tmdbURL
                        )
                        .font(.footnote.weight(.semibold))
                    }
                }
            }
            .padding(24)
            .frame(maxWidth: .infinity)
        }
        .navigationTitle("About")
        .navigationBarTitleDisplayMode(.inline)
    }

    @ToolbarContentBuilder
    private var doneToolbar: some ToolbarContent {
        ToolbarItem(placement: .confirmationAction) {
            Button("Done") {
                dismiss()
            }
        }
    }
}

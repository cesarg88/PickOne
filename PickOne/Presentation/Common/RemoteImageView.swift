import SwiftUI

struct RemoteImageView: View {
    enum Phase {
        case empty
        case loading
        case success(Image)
        case failure
    }
    
    let url: URL?
    let loader: any ImageLoading
    let contentMode: ContentMode
    let accessibilityLabel: String
    
    @State private var phase: Phase = .empty
    
    var body: some View {
        ZStack {
            switch phase {
            case .empty, .loading:
                ProgressView()
                    .progressViewStyle(.circular)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color(.systemGray6))
            case .success(let image):
                image
                    .resizable()
                    .aspectRatio(contentMode: contentMode)
            case .failure:
                Image(systemName: "photo")
                    .font(.system(size: 24))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color(.systemGray6))
            }
        }
        .accessibilityLabel(accessibilityLabel)
        .task(id: url?.absoluteString ?? "") {
            await load()
        }
    }
    
    private func load() async {
        guard let url else {
            phase = .failure
            return
        }
        if case .success = phase {
            return
        }
        phase = .loading
        do {
            let uiImage = try await loader.loadImage(from: url)
            phase = .success(Image(uiImage: uiImage))
        } catch {
            phase = .failure
        }
    }
}

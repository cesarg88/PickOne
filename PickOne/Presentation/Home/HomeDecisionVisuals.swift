import SwiftUI

enum HomeDecisionLayout {
    /// Two readable columns need room for a full hero and a 400-point alternative.
    static let minimumWideWidth: CGFloat = 1050

    static func usesColumns(availableWidth: CGFloat, dynamicTypeSize: DynamicTypeSize) -> Bool {
        availableWidth >= minimumWideWidth && dynamicTypeSize < .xxxLarge
    }
}

enum HomeDecisionTransition {
    static func animation(reduceMotion: Bool) -> Animation? {
        reduceMotion ? nil : .easeInOut(duration: 0.2)
    }
}

enum HomeDecisionScrim {
    // Even a white photograph remains behind dark enough pixels for white labels.
    static let topOpacity = 0.72
    static let middleOpacity = 0.74
    static let bottomOpacity = 0.86

    static var gradient: LinearGradient {
        LinearGradient(
            stops: [
                .init(color: .black.opacity(topOpacity), location: 0),
                .init(color: .black.opacity(middleOpacity), location: 0.5),
                .init(color: .black.opacity(bottomOpacity), location: 1),
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }
}

enum HomeDecisionArtwork {
    case backdrop(UIImage)
    case poster(UIImage)
    case surface

    var isBackdrop: Bool {
        if case .backdrop = self { return true }
        return false
    }
}

@MainActor
enum HomeDecisionArtworkLoader {
    static func load(
        backdropURL: URL?,
        posterURL: URL?,
        using loader: any ImageLoading
    ) async -> HomeDecisionArtwork {
        if let backdropURL, let image = try? await loader.loadImage(from: backdropURL) {
            return .backdrop(image)
        }
        guard !Task.isCancelled else { return .surface }
        if let posterURL, let image = try? await loader.loadImage(from: posterURL) {
            return .poster(image)
        }
        return .surface
    }
}

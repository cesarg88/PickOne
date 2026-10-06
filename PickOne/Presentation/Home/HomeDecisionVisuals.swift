import SwiftUI

enum HomeDecisionLayout {
    /// Two readable columns need room for a full hero and a 400-point alternative.
    static let minimumWideWidth: CGFloat = 1050

    static func usesColumns(availableWidth: CGFloat, dynamicTypeSize: DynamicTypeSize) -> Bool {
        availableWidth >= minimumWideWidth && dynamicTypeSize < .xxxLarge
    }
}

/// Places availability and Pick on one row only when both intrinsic widths fit.
/// The provider group keeps its horizontal order; only Pick moves below it.
struct HomeDecisionAvailabilityPickLayout: Layout {
    let spacing: CGFloat

    func sizeThatFits(
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache _: inout ()
    ) -> CGSize {
        guard let providers = subviews.first else { return .zero }
        let providerSize = providers.sizeThatFits(.unspecified)
        guard subviews.count > 1 else { return providerSize }
        let pickSize = subviews[1].sizeThatFits(.unspecified)
        let width = proposal.width ?? providerSize.width + spacing + pickSize.width
        if providerSize.width + spacing + pickSize.width <= width {
            return CGSize(width: width, height: max(providerSize.height, pickSize.height))
        }
        let wrappedProviders = providers.sizeThatFits(ProposedViewSize(width: width, height: nil))
        return CGSize(width: width, height: wrappedProviders.height + spacing + pickSize.height)
    }

    func placeSubviews(
        in bounds: CGRect,
        proposal _: ProposedViewSize,
        subviews: Subviews,
        cache _: inout ()
    ) {
        guard let providers = subviews.first else { return }
        let providerSize = providers.sizeThatFits(.unspecified)
        guard subviews.count > 1 else {
            providers.place(at: bounds.origin, proposal: ProposedViewSize(providerSize))
            return
        }
        let pick = subviews[1]
        let pickSize = pick.sizeThatFits(.unspecified)
        if providerSize.width + spacing + pickSize.width <= bounds.width {
            providers.place(
                at: CGPoint(x: bounds.minX, y: bounds.maxY - providerSize.height),
                proposal: ProposedViewSize(providerSize)
            )
            pick.place(
                at: CGPoint(x: bounds.maxX - pickSize.width, y: bounds.maxY - pickSize.height),
                proposal: ProposedViewSize(pickSize)
            )
        } else {
            let wrappedProviders = providers.sizeThatFits(ProposedViewSize(width: bounds.width, height: nil))
            providers.place(
                at: bounds.origin,
                proposal: ProposedViewSize(width: bounds.width, height: wrappedProviders.height)
            )
            pick.place(
                at: CGPoint(x: bounds.maxX - pickSize.width, y: bounds.minY + wrappedProviders.height + spacing),
                proposal: ProposedViewSize(pickSize)
            )
        }
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

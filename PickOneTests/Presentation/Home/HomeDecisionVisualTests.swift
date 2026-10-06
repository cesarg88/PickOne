import Foundation
@testable import PickOne
import SwiftUI
import Testing

@MainActor
struct HomeDecisionVisualTests {
    @Test("wide composition follows offered width and reflows for large text")
    func reflow() {
        #expect(!HomeDecisionLayout.usesColumns(availableWidth: 960, dynamicTypeSize: .large))
        #expect(HomeDecisionLayout.usesColumns(availableWidth: 1130, dynamicTypeSize: .large))
        #expect(!HomeDecisionLayout.usesColumns(availableWidth: 1130, dynamicTypeSize: .xxxLarge))
        #expect(!HomeDecisionLayout.usesColumns(availableWidth: 1130, dynamicTypeSize: .accessibility5))
    }

    @Test("Reduce Motion removes nonessential set transitions without removing content")
    func reducedMotionTransition() {
        #expect(HomeDecisionTransition.animation(reduceMotion: true) == nil)
        #expect(HomeDecisionTransition.animation(reduceMotion: false) != nil)
    }

    @Test("image hierarchy falls through actual loading failures")
    func imageFallback() async {
        let backdropURL = URL(string: "https://example.com/backdrop.jpg")
        let posterURL = URL(string: "https://example.com/poster.jpg")
        let backdrop = await HomeDecisionArtworkLoader.load(
            backdropURL: backdropURL, posterURL: posterURL, using: ArtworkStub(failingPaths: [])
        )
        let poster = await HomeDecisionArtworkLoader.load(
            backdropURL: backdropURL, posterURL: posterURL,
            using: ArtworkStub(failingPaths: ["/backdrop.jpg"])
        )
        let surface = await HomeDecisionArtworkLoader.load(
            backdropURL: backdropURL, posterURL: posterURL,
            using: ArtworkStub(failingPaths: ["/backdrop.jpg", "/poster.jpg"])
        )

        guard case .backdrop = backdrop else {
            Issue.record("The available backdrop must win")
            return
        }
        guard case .poster = poster else {
            Issue.record("A failed backdrop must reveal the complete poster")
            return
        }
        guard case .surface = surface else {
            Issue.record("Two failed photographs must reveal the semantic surface")
            return
        }
    }

    @Test("continuous black scrim clears normal-text contrast on bright and dark images")
    func photographicContrast() {
        let opacities = [
            HomeDecisionScrim.topOpacity,
            HomeDecisionScrim.middleOpacity,
            HomeDecisionScrim.bottomOpacity,
        ]
        #expect(opacities[0] <= opacities[1] && opacities[1] <= opacities[2])
        for sourceChannel in [0.0, 1.0] {
            for opacity in opacities {
                let channel = sourceChannel * (1 - opacity)
                let luminance = channel <= 0.04045
                    ? channel / 12.92
                    : pow((channel + 0.055) / 1.055, 2.4)
                let contrast = 1.05 / (luminance + 0.05)
                #expect(contrast >= 4.5)
            }
        }
    }
}

private struct ArtworkStub: ImageLoading {
    let failingPaths: Set<String>

    func loadImage(from url: URL) async throws -> UIImage {
        if failingPaths.contains(url.path) { throw ArtworkFailure.unavailable }
        return UIImage()
    }
}

private enum ArtworkFailure: Error {
    case unavailable
}

#if DEBUG
    import SwiftUI

    @MainActor
    private enum HomeDecisionCardPreviews {
        static func card(
            isHero: Bool,
            providerCount: Int,
            title: String = "La llegada",
            fallback: Bool = false
        ) -> some View {
            Group {
                if let item = item(
                    isHero: isHero,
                    providerCount: providerCount,
                    title: title,
                    fallback: fallback
                ) {
                    ScrollView {
                        HomeDecisionCard(
                            item: item,
                            isHero: isHero,
                            pickModel: HomePickViewModel(
                                manage: ManageViewingDecision(repository: PreviewPickRepository())
                            ),
                            imagePipeline: imagePipeline(),
                            updateViewerMovieState: PreviewFeedbackUpdate(),
                            viewerStateDidChange: { _ in }
                        )
                        .padding(24)
                    }
                    .background(Color(.systemBackground))
                }
            }
        }

        private static func item(
            isHero: Bool,
            providerCount: Int,
            title: String,
            fallback: Bool
        ) -> HomeDecisionMovieItem? {
            guard let metadata = try? MovieFeedbackMetadata(
                title: title, releaseYear: 2016, posterPath: nil
            ) else { return nil }
            let services = Array(PilotStreamingService.allowlist.prefix(providerCount))
            return HomeDecisionMovieItem(
                id: isHero ? 101 : 202,
                title: title,
                hasCurrentLocaleTitle: true,
                posterURL: nil,
                backdropURL: fallback ? nil : URL(string: "https://preview.invalid/home-backdrop.png"),
                decisionRole: isHero ? .safeChoice : .stretchChoice,
                role: isHero ? "01 · LA APUESTA SEGURA" : "02 · CAMBIA DE REGISTRO",
                reason: "Ciencia ficción y drama, como Interstellar, que te encantó.",
                details: "2016 · 116 min · Ciencia ficción",
                providers: services.enumerated().map { index, service in
                    HomeDecisionProviderItem(
                        id: service.providerID,
                        name: service.name,
                        logoURL: fallback ? nil
                            : URL(string: "https://preview.invalid/logo-\(index).png")
                    )
                },
                isSaved: false,
                feedbackMetadata: metadata
            )
        }

        private static func imagePipeline() -> ImagePipeline {
            let cache = ImageCache()
            let renderer = UIGraphicsImageRenderer(size: CGSize(width: 600, height: 400))
            let artwork = renderer.image { context in
                UIColor.systemIndigo.setFill()
                context.fill(CGRect(x: 0, y: 0, width: 600, height: 400))
                UIColor.systemTeal.setFill()
                context.fill(CGRect(x: 280, y: 0, width: 320, height: 400))
            }
            if let url = URL(string: "https://preview.invalid/home-backdrop.png") {
                cache.insert(artwork, for: url)
            }
            for index in 0 ..< 4 {
                let logo = UIGraphicsImageRenderer(size: CGSize(width: 64, height: 64)).image { context in
                    [UIColor.systemRed, .systemBlue, .systemTeal, .systemPurple][index].setFill()
                    context.fill(CGRect(x: 0, y: 0, width: 64, height: 64))
                }
                if let url = URL(string: "https://preview.invalid/logo-\(index).png") {
                    cache.insert(logo, for: url)
                }
            }
            return ImagePipeline(cache: cache)
        }
    }

    private enum PreviewUnavailable: Error { case offline }

    private struct PreviewPickRepository: ViewingDecisionRepository {
        func snapshot() async throws -> ViewingDecisionState {
            throw PreviewUnavailable.offline
        }

        func apply(_: ViewingDecisionOperation) async throws -> ViewingDecisionReceipt {
            throw PreviewUnavailable.offline
        }
    }

    private struct PreviewFeedbackUpdate: UpdateViewerMovieStateUseCase {
        func execute(
            transition _: ViewerMovieStateTransition,
            metadata _: MovieFeedbackMetadata
        ) async throws -> ViewerMovieStateChange {
            throw PreviewUnavailable.offline
        }
    }

    #Preview("Safe · one service") {
        HomeDecisionCardPreviews.card(isHero: true, providerCount: 1)
    }

    #Preview("Alternative · two services") {
        HomeDecisionCardPreviews.card(isHero: false, providerCount: 2)
    }

    #Preview("Safe · four services") {
        HomeDecisionCardPreviews.card(isHero: true, providerCount: 4)
    }

    #Preview("Safe · long title · XXXL") {
        HomeDecisionCardPreviews.card(
            isHero: true,
            providerCount: 4,
            title: "Una película extraordinariamente larga que debe leerse por completo"
        )
        .environment(\.dynamicTypeSize, .accessibility5)
    }

    #Preview("Safe · no artwork or logos") {
        HomeDecisionCardPreviews.card(isHero: true, providerCount: 4, fallback: true)
    }
#endif

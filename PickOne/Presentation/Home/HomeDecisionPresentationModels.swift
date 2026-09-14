import Foundation

struct HomeDecisionSetPresentationModel: Equatable {
    let items: [HomeDecisionMovieItem]
}

struct HomeDecisionMovieItem: Identifiable, Equatable {
    let id: Int
    let title: String
    let posterURL: URL?
    let role: String
    let reason: String
    let details: String
    let providers: [HomeDecisionProviderItem]
    let isSaved: Bool
    let feedbackMetadata: MovieFeedbackMetadata
}

struct HomeDecisionProviderItem: Identifiable, Equatable, Hashable {
    let id: Int
    let name: String
    let logoURL: URL?
}

@MainActor
enum HomeDecisionPresentationMapper {
    static func map(snapshot: ThreeForTonightSnapshot) -> HomeDecisionSetPresentationModel {
        HomeDecisionSetPresentationModel(
            items: snapshot.decisionSet.recommendations.compactMap { recommendation in
                map(
                    recommendation: recommendation,
                    isSaved: snapshot.savedMovieIDs.contains(recommendation.display.movieID)
                )
            }
        )
    }

    private static func map(
        recommendation: PersistedDecisionRecommendation,
        isSaved: Bool
    ) -> HomeDecisionMovieItem? {
        guard
            let reason = reason(recommendation.evidence.primary),
            let feedbackMetadata = try? MovieFeedbackMetadata(
                title: recommendation.display.localizedTitle,
                releaseYear: recommendation.display.releaseYear,
                posterPath: recommendation.display.posterPath
            )
        else {
            return nil
        }
        return HomeDecisionMovieItem(
            id: recommendation.display.movieID,
            title: recommendation.display.localizedTitle,
            posterURL: ImageURLBuilder.posterURL(
                path: recommendation.display.posterPath,
                size: .posterLarge
            ),
            role: roleTitle(recommendation.role),
            reason: reason,
            details: details(recommendation.display),
            providers: recommendation.availability.matchingProviders.map { provider in
                HomeDecisionProviderItem(
                    id: provider.providerID,
                    name: provider.name,
                    logoURL: ImageURLBuilder.providerLogoURL(path: provider.logoPath)
                )
            },
            isSaved: isSaved,
            feedbackMetadata: feedbackMetadata
        )
    }

    private static func roleTitle(_ role: DecisionRole) -> String {
        switch role {
            case .safeChoice: String(localized: "Safe Choice")
            case .stretchChoice: String(localized: "Stretch Choice")
            case .discoveryChoice: String(localized: "Discovery Choice")
        }
    }

    private static func reason(_ evidence: RecommendationPrimaryEvidence) -> String? {
        switch evidence {
            case let .watchlistIntent(match):
                tasteMatch(match).map { String(localized: "Saved for later, and \($0)") }
            case let .positiveAnchor(anchor):
                positiveAnchorReason(anchor, sentenceStart: true)
            case let .positiveGenreAffinity(affinity):
                affinityReason(affinity, sentenceStart: true)
            case .sparseQuality:
                String(localized: "Backed by strong ratings and broad viewer evidence.")
        }
    }

    private static func tasteMatch(_ evidence: RecommendationTasteEvidence) -> String? {
        switch evidence {
            case let .positiveAnchor(anchor):
                positiveAnchorReason(anchor, sentenceStart: false)
            case let .positiveAffinity(affinity):
                affinityReason(affinity, sentenceStart: false)
        }
    }

    private static func reactionVerb(_ reaction: PositiveAnchorReaction) -> String {
        switch reaction {
            case .loved: String(localized: "loved")
            case .liked: String(localized: "liked")
        }
    }

    private static func positiveAnchorReason(
        _ anchor: PositiveAnchorEvidence,
        sentenceStart: Bool
    ) -> String? {
        let prefix = sentenceStart ? String(localized: "home.reason.similar.sentence", defaultValue: "Similar") :
            String(
                localized: "home.reason.similar.embedded",
                defaultValue: "similar"
            )
        guard var sharedSignals = sharedGenreDescription(anchor.sharedGenres) else {
            return nil
        }
        switch anchor.eraMatch {
            case let .sameDecade(decade):
                sharedSignals = String(localized: "\(sharedSignals); both are from the \(decade.startingYear)s")
            case let .adjacentDecade(candidate, anchor):
                sharedSignals =
                    String(
                        localized: "\(sharedSignals); their release eras are adjacent (\(candidate.startingYear)s and \(anchor.startingYear)s)"
                    )
            case nil:
                break
        }
        return String(
            localized: "\(prefix) to \(anchor.movieTitle), which you \(reactionVerb(anchor.reaction)) — \(sharedSignals)."
        )
    }

    private static func sharedGenreDescription(
        _ genres: [DecisionGenre]
    ) -> String? {
        let genreLabels = genres.compactMap(\.name)
        guard !genreLabels.isEmpty, genreLabels.count == genres.count else {
            return nil
        }
        return String(localized: "shares \(naturalList(genreLabels))")
    }

    private static func affinityReason(
        _ affinity: PositiveAffinityEvidence,
        sentenceStart: Bool
    ) -> String? {
        let prefix = sentenceStart ? String(localized: "home.reason.matches.sentence", defaultValue: "Matches") :
            String(
                localized: "home.reason.matches.embedded",
                defaultValue: "matches"
            )
        let genreNames = affinity.genres.compactMap(\.name)
        if !affinity.genres.isEmpty {
            guard genreNames.count == affinity.genres.count else {
                return nil
            }
            return String(localized: "\(prefix) your taste for \(naturalList(genreNames)).")
        }
        return affinity.era == nil
            ? nil
            : String(localized: "\(prefix) a release era you tend to enjoy.")
    }

    private static func naturalList(_ values: [String]) -> String {
        guard let last = values.last else { return "" }
        guard values.count > 1 else { return last }
        return String(localized: "\(values.dropLast().joined(separator: ", ")) and \(last)")
    }

    private static func details(_ display: DecisionDisplaySnapshot) -> String {
        var values: [String] = []
        if let releaseYear = display.releaseYear {
            values.append(String(releaseYear))
        }
        if let runtime = display.runtimeMinutes {
            values.append(runtimeText(runtime))
        }
        let genreNames = display.genres.compactMap(\.name)
        if !genreNames.isEmpty {
            values.append(genreNames.joined(separator: ", "))
        }
        return values.joined(separator: " · ")
    }

    private static func runtimeText(_ minutes: Int) -> String {
        let hours = minutes / 60
        let remainingMinutes = minutes % 60
        if hours == 0 {
            return "\(remainingMinutes)m"
        }
        if remainingMinutes == 0 {
            return "\(hours)h"
        }
        return "\(hours)h \(remainingMinutes)m"
    }
}

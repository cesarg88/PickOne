import Foundation

struct HomeDecisionSetPresentationModel: Equatable {
    let items: [HomeDecisionMovieItem]
}

struct HomeDecisionMovieItem: Identifiable, Equatable {
    let id: Int
    let title: String
    let posterURL: URL?
    let backdropURL: URL?
    let decisionRole: DecisionRole
    let role: String
    let reason: String
    let details: String
    let providers: [HomeDecisionProviderItem]
    let isSaved: Bool
    let feedbackMetadata: MovieFeedbackMetadata

    var slot: HomeDecisionSlot {
        switch decisionRole {
            case .safeChoice: .safe
            case .stretchChoice: .stretch
            case .discoveryChoice: .discovery
        }
    }
}

enum HomeDecisionSlot: Hashable {
    case safe
    case stretch
    case discovery
}

struct HomeDecisionProviderItem: Identifiable, Equatable, Hashable {
    let id: Int
    let name: String
    let logoURL: URL?
}

struct HomeMovieDisplayProjection: Equatable, Sendable {
    var movies: [Int: MovieDisplayMetadata] = [:]

    func title(for movieID: Int, legacyTitle: String) -> String {
        movies[movieID]?.title ?? legacyTitle
    }

    func genreName(for genreID: Int) -> String? {
        for movieID in movies.keys.sorted() {
            if let name = movies[movieID]?.genreNames[genreID] {
                return name
            }
        }
        return nil
    }
}

@MainActor
enum HomeDecisionPresentationMapper {
    static func map(
        snapshot: ThreeForTonightSnapshot,
        locale: Locale = .current,
        projection: HomeMovieDisplayProjection = .init()
    ) -> HomeDecisionSetPresentationModel {
        let contentLocale = MovieContentLocale(effectiveLocale: locale).locale
        return HomeDecisionSetPresentationModel(
            items: snapshot.decisionSet.recommendations.compactMap { recommendation in
                map(
                    recommendation: recommendation,
                    isSaved: snapshot.savedMovieIDs.contains(recommendation.display.movieID),
                    locale: contentLocale,
                    projection: projection
                )
            }
        )
    }

    private static func map(
        recommendation: PersistedDecisionRecommendation,
        isSaved: Bool,
        locale: Locale,
        projection: HomeMovieDisplayProjection
    ) -> HomeDecisionMovieItem? {
        let title = projection.title(
            for: recommendation.display.movieID,
            legacyTitle: recommendation.display.localizedTitle
        )
        guard
            let reason = reason(recommendation.evidence.primary, locale: locale, projection: projection),
            let feedbackMetadata = try? MovieFeedbackMetadata(
                title: title,
                releaseYear: recommendation.display.releaseYear,
                posterPath: recommendation.display.posterPath
            )
        else {
            return nil
        }
        return HomeDecisionMovieItem(
            id: recommendation.display.movieID,
            title: title,
            posterURL: ImageURLBuilder.posterURL(
                path: recommendation.display.posterPath,
                size: .posterLarge
            ),
            backdropURL: ImageURLBuilder.backdropURL(path: recommendation.display.backdropPath),
            decisionRole: recommendation.role,
            role: roleTitle(recommendation.role, locale: locale),
            reason: reason,
            details: details(recommendation.display, locale: locale, projection: projection),
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

    private static func roleTitle(_ role: DecisionRole, locale: Locale) -> String {
        switch role {
            case .safeChoice: localized("Safe Choice", locale: locale)
            case .stretchChoice: localized("Stretch Choice", locale: locale)
            case .discoveryChoice: localized("Discovery Choice", locale: locale)
        }
    }

    private static func reason(
        _ evidence: RecommendationPrimaryEvidence,
        locale: Locale,
        projection: HomeMovieDisplayProjection
    ) -> String? {
        switch evidence {
            case let .watchlistIntent(match):
                tasteMatch(match, locale: locale, projection: projection).map {
                    localized("Saved for later, and \($0)", locale: locale)
                }
            case let .positiveAnchor(anchor):
                positiveAnchorReason(anchor, sentenceStart: true, locale: locale, projection: projection)
            case let .positiveGenreAffinity(affinity):
                affinityReason(affinity, sentenceStart: true, locale: locale, projection: projection)
            case .sparseQuality:
                localized("Backed by strong ratings and broad viewer evidence.", locale: locale)
        }
    }

    private static func tasteMatch(
        _ evidence: RecommendationTasteEvidence,
        locale: Locale,
        projection: HomeMovieDisplayProjection
    ) -> String? {
        switch evidence {
            case let .positiveAnchor(anchor):
                positiveAnchorReason(anchor, sentenceStart: false, locale: locale, projection: projection)
            case let .positiveAffinity(affinity):
                affinityReason(affinity, sentenceStart: false, locale: locale, projection: projection)
        }
    }

    private static func reactionVerb(_ reaction: PositiveAnchorReaction, locale: Locale) -> String {
        switch reaction {
            case .loved: localized("loved", locale: locale)
            case .liked: localized("liked", locale: locale)
        }
    }

    private static func positiveAnchorReason(
        _ anchor: PositiveAnchorEvidence,
        sentenceStart: Bool,
        locale: Locale,
        projection: HomeMovieDisplayProjection
    ) -> String? {
        let prefix = sentenceStart ? localized(
            "home.reason.similar.sentence", defaultValue: "Similar", locale: locale
        ) :
            localized(
                "home.reason.similar.embedded",
                defaultValue: "similar",
                locale: locale
            )
        guard let anchorTitle = projection.movies[anchor.movieID]?.title,
              var sharedSignals = sharedGenreDescription(anchor.sharedGenres, locale: locale, projection: projection)
        else {
            return genericTasteReason(sentenceStart: sentenceStart, locale: locale)
        }
        switch anchor.eraMatch {
            case let .sameDecade(decade):
                sharedSignals = localized(
                    "\(sharedSignals); both are from the \(String(decade.startingYear))s",
                    locale: locale
                )
            case let .adjacentDecade(candidate, anchor):
                sharedSignals =
                    localized(
                        "\(sharedSignals); their release eras are adjacent (\(String(candidate.startingYear))s and \(String(anchor.startingYear))s)",
                        locale: locale
                    )
            case nil:
                break
        }
        return localized(
            "\(prefix) to \(anchorTitle), which you \(reactionVerb(anchor.reaction, locale: locale)) — \(sharedSignals).",
            locale: locale
        )
    }

    private static func sharedGenreDescription(
        _ genres: [DecisionGenre],
        locale: Locale,
        projection: HomeMovieDisplayProjection
    ) -> String? {
        let genreLabels = genres.compactMap { projection.genreName(for: $0.id) }
        guard !genreLabels.isEmpty, genreLabels.count == genres.count else {
            return nil
        }
        return localized("shares \(naturalList(genreLabels, locale: locale))", locale: locale)
    }

    private static func affinityReason(
        _ affinity: PositiveAffinityEvidence,
        sentenceStart: Bool,
        locale: Locale,
        projection: HomeMovieDisplayProjection
    ) -> String? {
        let prefix = sentenceStart ? localized(
            "home.reason.matches.sentence", defaultValue: "Matches", locale: locale
        ) :
            localized(
                "home.reason.matches.embedded",
                defaultValue: "matches",
                locale: locale
            )
        let genreNames = affinity.genres.compactMap { projection.genreName(for: $0.id) }
        if !affinity.genres.isEmpty {
            guard genreNames.count == affinity.genres.count else {
                return genericTasteReason(sentenceStart: sentenceStart, locale: locale)
            }
            return localized("\(prefix) your taste for \(naturalList(genreNames, locale: locale)).", locale: locale)
        }
        return affinity.era == nil
            ? genericTasteReason(sentenceStart: sentenceStart, locale: locale)
            : localized("\(prefix) a release era you tend to enjoy.", locale: locale)
    }

    private static func genericTasteReason(sentenceStart: Bool, locale: Locale) -> String {
        if sentenceStart {
            return localized("home.reason.generic.sentence", defaultValue: "Based on movies you liked.", locale: locale)
        }
        return localized("home.reason.generic.embedded", defaultValue: "based on movies you liked.", locale: locale)
    }

    private static func localized(_ value: String.LocalizationValue, locale: Locale) -> String {
        String(localized: value, bundle: languageBundle(for: locale), locale: locale)
    }

    private static func localized(
        _ key: StaticString,
        defaultValue: String.LocalizationValue,
        locale: Locale
    ) -> String {
        String(localized: key, defaultValue: defaultValue, bundle: languageBundle(for: locale), locale: locale)
    }

    private static func languageBundle(for locale: Locale) -> Bundle? {
        let language = MovieContentLocale(effectiveLocale: locale) == .spanish ? "es" : "en"
        guard let url = Bundle.main.url(forResource: language, withExtension: "lproj")
            ?? Bundle.main.url(forResource: "en", withExtension: "lproj")
        else {
            return nil
        }
        return Bundle(url: url)
    }

    private static func naturalList(_ values: [String], locale: Locale) -> String {
        let formatter = ListFormatter()
        formatter.locale = locale
        return formatter.string(from: values) ?? values.joined(separator: ", ")
    }

    private static func details(
        _ display: DecisionDisplaySnapshot,
        locale: Locale,
        projection: HomeMovieDisplayProjection
    ) -> String {
        var values: [String] = []
        if let releaseYear = display.releaseYear {
            values.append(String(releaseYear))
        }
        if let runtime = display.runtimeMinutes {
            values.append(runtimeText(runtime, locale: locale))
        }
        let genreNames = display.genres.compactMap { projection.genreName(for: $0.id) }
        if !genreNames.isEmpty {
            values.append(naturalList(genreNames, locale: locale))
        }
        return values.joined(separator: " · ")
    }

    private static func runtimeText(_ minutes: Int, locale: Locale) -> String {
        let formatter = DateComponentsFormatter()
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = locale
        formatter.calendar = calendar
        formatter.unitsStyle = .abbreviated
        formatter.allowedUnits = [.hour, .minute]
        formatter.maximumUnitCount = 2
        return formatter.string(from: TimeInterval(minutes * 60)) ?? ""
    }
}

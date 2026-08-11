@testable import PickOne

enum P1FixtureGenre {
    static let action = DecisionGenre(id: 28)
    static let adventure = DecisionGenre(id: 12)
    static let animation = DecisionGenre(id: 16)
    static let comedy = DecisionGenre(id: 35)
    static let crime = DecisionGenre(id: 80)
    static let drama = DecisionGenre(id: 18)
    static let family = DecisionGenre(id: 10751)
    static let fantasy = DecisionGenre(id: 14)
    static let history = DecisionGenre(id: 36)
    static let horror = DecisionGenre(id: 27)
    static let music = DecisionGenre(id: 10402)
    static let mystery = DecisionGenre(id: 9648)
    static let romance = DecisionGenre(id: 10749)
    static let scienceFiction = DecisionGenre(id: 878)
    static let thriller = DecisionGenre(id: 53)
    static let war = DecisionGenre(id: 10752)
}

struct P1NamedCandidate: Sendable {
    let name: String
    let input: P1CandidateScoreInput
}

enum P1ScoringTestFixtures {
    static let fixtureAProfile = P1TasteProfile(evidence: [
        evidence(1, .loveIt, [.scienceFiction, .drama], 2014),
        evidence(2, .loveIt, [.scienceFiction, .adventure], 2017),
        evidence(3, .likeIt, [.crime, .drama], 2006),
        evidence(4, .didNotLikeIt, [.comedy], 2012),
        evidence(5, .didNotLikeIt, [.romance, .comedy], 2004),
        evidence(6, .itWasOkay, [.action], 2021),
        evidence(7, .likeIt, [.drama], 2022),
        evidence(8, .doNotKnowIt, [.horror], 2018),
    ])

    static let fixtureACandidates = [
        candidate("C1", 101, [.scienceFiction, .drama], 2016, 8.5, 20000),
        candidate("C2", 102, [.scienceFiction, .adventure], 2022, 8.5, 20000),
        candidate("C3", 103, [.crime, .thriller, .drama], 2015, 8.5, 20000),
        candidate("C4", 104, [.comedy, .romance], 2018, 9.0, 20000),
        candidate("C5", 105, [.scienceFiction, .drama], 2014, 7.0, 1000),
    ]

    static let originalProfile = P1TasteProfile(evidence: [
        evidence(157_336, .loveIt, [.adventure, .drama, .scienceFiction], 2014),
        evidence(238, .haveNotSeenIt, [.drama, .crime], 1972),
        evidence(11036, .didNotLikeIt, [.romance, .drama], 2004),
        evidence(155, .itWasOkay, [.action, .crime, .thriller], 2008),
        evidence(1417, .didNotLikeIt, [.fantasy, .drama, .war], 2006),
        evidence(18785, .itWasOkay, [.comedy], 2009),
        evidence(419_430, .likeIt, [.mystery, .thriller, .horror], 2017),
        evidence(496_243, .loveIt, [.comedy, .thriller, .drama], 2019),
        evidence(354_912, .itWasOkay, [.family, .animation, .music, .adventure], 2017),
        evidence(546_554, .haveNotSeenIt, [.comedy, .crime, .mystery], 2019),
        evidence(76341, .haveNotSeenIt, [.action, .adventure, .scienceFiction], 2015),
        evidence(120, .didNotLikeIt, [.adventure, .fantasy, .action], 2001),
        evidence(278, .didNotLikeIt, [.drama, .crime], 1994),
        evidence(98, .itWasOkay, [.action, .drama, .adventure], 2000),
        evidence(447_332, .didNotLikeIt, [.horror, .drama, .scienceFiction], 2018),
    ])

    static let augmentedProfile = P1TasteProfile(evidence: originalProfile.evidence + [
        evidence(286_217, .likeIt, [.scienceFiction, .drama, .adventure], 2015),
        evidence(210_577, .likeIt, [.mystery, .thriller, .drama], 2014),
        evidence(593_643, .likeIt, [.comedy, .horror], 2022),
        evidence(570_670, .likeIt, [.thriller, .scienceFiction, .horror], 2020),
        evidence(414_906, .likeIt, [.crime, .mystery, .thriller], 2022),
        evidence(120_467, .didNotLikeIt, [.comedy, .drama], 2014),
        evidence(933_260, .itWasOkay, [.horror, .scienceFiction, .thriller], 2024),
        evidence(493_922, .likeIt, [.horror, .mystery, .thriller], 2018),
    ])

    static let realCandidates = [
        candidate("The Godfather", 238, [.drama, .crime], 1972, 8.686, 23315),
        candidate("Knives Out", 546_554, [.comedy, .crime, .mystery], 2019, 7.840, 14290),
        candidate("Mad Max: Fury Road", 76341, [.action, .adventure, .scienceFiction], 2015, 7.636, 24380),
        candidate("Arrival", 329_865, [.drama, .scienceFiction, .mystery], 2016, 7.631, 19661),
        candidate("The Martian", 286_217, [.scienceFiction, .drama, .adventure], 2015, 7.706, 21603),
        candidate("Blade Runner 2049", 335_984, [.scienceFiction, .drama], 2017, 7.601, 15446),
        candidate("Gone Girl", 210_577, [.mystery, .thriller, .drama], 2014, 7.890, 20213),
        candidate("Prisoners", 146_233, [.drama, .thriller, .crime], 2013, 8.106, 13319),
        candidate("The Menu", 593_643, [.comedy, .horror], 2022, 7.179, 6463),
        candidate("Us", 458_723, [.horror, .mystery, .thriller], 2019, 6.943, 8201),
        candidate("Nope", 762_504, [.horror, .scienceFiction, .thriller], 2022, 6.825, 5058),
        candidate("The Invisible Man", 570_670, [.thriller, .scienceFiction, .horror], 2020, 7.089, 6378),
        candidate("Nightcrawler", 242_582, [.crime, .drama, .thriller], 2014, 7.708, 11901),
        candidate("The Handmaiden", 290_098, [.thriller, .drama, .romance], 2016, 8.180, 4422),
        candidate("Triangle of Sadness", 497_828, [.comedy, .drama], 2022, 7.011, 2944),
        candidate("The Substance", 933_260, [.horror, .scienceFiction, .thriller], 2024, 7.133, 6285),
        candidate("Anatomy of a Fall", 915_935, [.thriller, .mystery, .crime], 2023, 7.514, 3397),
        candidate("The Batman", 414_906, [.crime, .mystery, .thriller], 2022, 7.700, 12281),
        candidate("Whiplash", 244_786, [.drama, .music, .thriller], 2014, 8.375, 16898),
        candidate("La La Land", 313_369, [.comedy, .drama, .romance], 2016, 7.900, 18316),
        candidate("The Grand Budapest Hotel", 120_467, [.comedy, .drama], 2014, 8.025, 16339),
        candidate("Hereditary", 493_922, [.horror, .mystery, .thriller], 2018, 7.293, 8774),
        candidate("The Prestige", 1124, [.drama, .mystery, .scienceFiction], 2006, 8.211, 17895),
        candidate("Oppenheimer", 872_585, [.drama, .history], 2023, 8.023, 12201),
        candidate("Snowpiercer", 110_415, [.action, .scienceFiction, .drama], 2013, 6.906, 10552),
    ]

    static let augmentedWatchedCandidateIDs: Set<Int> = [
        286_217,
        210_577,
        593_643,
        570_670,
        414_906,
        120_467,
        933_260,
        493_922,
    ]

    static func evidence(
        _ movieID: Int,
        _ reaction: CalibrationReaction,
        _ genres: Set<DecisionGenre>,
        _ releaseYear: Int?
    ) -> TasteReactionEvidence {
        TasteReactionEvidence(
            movieID: movieID,
            reaction: reaction,
            genres: genres,
            releaseYear: releaseYear
        )
    }

    static func candidate(
        _ name: String,
        _ movieID: Int,
        _ genres: Set<DecisionGenre>,
        _ releaseYear: Int?,
        _ voteAverage: Double?,
        _ voteCount: Int?,
        saved: Bool = false
    ) -> P1NamedCandidate {
        P1NamedCandidate(
            name: name,
            input: P1CandidateScoreInput(
                movieID: movieID,
                genres: genres,
                releaseYear: releaseYear,
                voteAverage: voteAverage,
                voteCount: voteCount,
                isSavedAndUnwatched: saved
            )
        )
    }
}

private extension DecisionGenre {
    static let action = P1FixtureGenre.action
    static let adventure = P1FixtureGenre.adventure
    static let animation = P1FixtureGenre.animation
    static let comedy = P1FixtureGenre.comedy
    static let crime = P1FixtureGenre.crime
    static let drama = P1FixtureGenre.drama
    static let family = P1FixtureGenre.family
    static let fantasy = P1FixtureGenre.fantasy
    static let history = P1FixtureGenre.history
    static let horror = P1FixtureGenre.horror
    static let music = P1FixtureGenre.music
    static let mystery = P1FixtureGenre.mystery
    static let romance = P1FixtureGenre.romance
    static let scienceFiction = P1FixtureGenre.scienceFiction
    static let thriller = P1FixtureGenre.thriller
    static let war = P1FixtureGenre.war
}

import Foundation

enum ViewerProfileValidationError: Error, Equatable, Sendable {
    case unsupportedRegion
    case unsupportedService
    case unsupportedProfileVersion
    case emptyServiceSelection
    case unsupportedCatalog
    case unknownMovie
    case invalidCatalogPosition
    case inconsistentProgress
}

struct CalibrationCatalogID: Hashable, Sendable {
    let rawValue: String

    static let spainHouseholdV1 = CalibrationCatalogID(
        rawValue: "es-household-calibration-v1"
    )
}

enum CalibrationCatalogBlock: String, Equatable, Sendable {
    case primary
    case reserve
    case optionalExtension
}

struct CalibrationMovie: Identifiable, Equatable, Sendable {
    let id: Int
    let titleKnownInSpain: String
    let originalOrEnglishTitle: String
    let year: Int
    let originalLanguage: String
    let block: CalibrationCatalogBlock
}

struct CalibrationCatalog: Equatable, Sendable {
    let id: CalibrationCatalogID
    let movies: [CalibrationMovie]

    var primary: [CalibrationMovie] {
        movies.filter { $0.block == .primary }
    }

    var reserve: [CalibrationMovie] {
        movies.filter { $0.block == .reserve }
    }

    var optionalExtension: [CalibrationMovie] {
        movies.filter { $0.block == .optionalExtension }
    }

    func contains(movieID: Int) -> Bool {
        movies.contains { $0.id == movieID }
    }

    static let spainHouseholdV1 = CalibrationCatalog(
        id: .spainHouseholdV1,
        movies: [
            CalibrationMovie(
                id: 238,
                titleKnownInSpain: "El padrino",
                originalOrEnglishTitle: "The Godfather",
                year: 1972,
                originalLanguage: "en",
                block: .primary
            ),
            CalibrationMovie(
                id: 11036,
                titleKnownInSpain: "El diario de Noa",
                originalOrEnglishTitle: "The Notebook",
                year: 2004,
                originalLanguage: "en",
                block: .primary
            ),
            CalibrationMovie(
                id: 155,
                titleKnownInSpain: "El caballero oscuro",
                originalOrEnglishTitle: "The Dark Knight",
                year: 2008,
                originalLanguage: "en",
                block: .primary
            ),
            CalibrationMovie(
                id: 1417,
                titleKnownInSpain: "El laberinto del fauno",
                originalOrEnglishTitle: "Pan's Labyrinth",
                year: 2006,
                originalLanguage: "es",
                block: .primary
            ),
            CalibrationMovie(
                id: 18785,
                titleKnownInSpain: "Resacón en Las Vegas",
                originalOrEnglishTitle: "The Hangover",
                year: 2009,
                originalLanguage: "en",
                block: .primary
            ),
            CalibrationMovie(
                id: 129,
                titleKnownInSpain: "El viaje de Chihiro",
                originalOrEnglishTitle: "Spirited Away",
                year: 2001,
                originalLanguage: "ja",
                block: .primary
            ),
            CalibrationMovie(
                id: 157_336,
                titleKnownInSpain: "Interstellar",
                originalOrEnglishTitle: "Interstellar",
                year: 2014,
                originalLanguage: "en",
                block: .primary
            ),
            CalibrationMovie(
                id: 419_430,
                titleKnownInSpain: "Déjame salir",
                originalOrEnglishTitle: "Get Out",
                year: 2017,
                originalLanguage: "en",
                block: .primary
            ),
            CalibrationMovie(
                id: 496_243,
                titleKnownInSpain: "Parásitos",
                originalOrEnglishTitle: "Parasite",
                year: 2019,
                originalLanguage: "ko",
                block: .primary
            ),
            CalibrationMovie(
                id: 354_912,
                titleKnownInSpain: "Coco",
                originalOrEnglishTitle: "Coco",
                year: 2017,
                originalLanguage: "en",
                block: .primary
            ),
            CalibrationMovie(
                id: 546_554,
                titleKnownInSpain: "Puñales por la espalda",
                originalOrEnglishTitle: "Knives Out",
                year: 2019,
                originalLanguage: "en",
                block: .primary
            ),
            CalibrationMovie(
                id: 76341,
                titleKnownInSpain: "Mad Max: Furia en la carretera",
                originalOrEnglishTitle: "Mad Max: Fury Road",
                year: 2015,
                originalLanguage: "en",
                block: .primary
            ),
            CalibrationMovie(
                id: 120,
                titleKnownInSpain: "El señor de los anillos: La comunidad del anillo",
                originalOrEnglishTitle: "The Lord of the Rings: The Fellowship of the Ring",
                year: 2001,
                originalLanguage: "en",
                block: .reserve
            ),
            CalibrationMovie(
                id: 313_369,
                titleKnownInSpain: "La ciudad de las estrellas (La La Land)",
                originalOrEnglishTitle: "La La Land",
                year: 2016,
                originalLanguage: "en",
                block: .reserve
            ),
            CalibrationMovie(
                id: 77338,
                titleKnownInSpain: "Intocable",
                originalOrEnglishTitle: "The Intouchables",
                year: 2011,
                originalLanguage: "fr",
                block: .reserve
            ),
            CalibrationMovie(
                id: 278,
                titleKnownInSpain: "Cadena perpetua",
                originalOrEnglishTitle: "The Shawshank Redemption",
                year: 1994,
                originalLanguage: "en",
                block: .optionalExtension
            ),
            CalibrationMovie(
                id: 98,
                titleKnownInSpain: "Gladiator",
                originalOrEnglishTitle: "Gladiator",
                year: 2000,
                originalLanguage: "en",
                block: .optionalExtension
            ),
            CalibrationMovie(
                id: 194,
                titleKnownInSpain: "Amelie",
                originalOrEnglishTitle: "Amélie",
                year: 2001,
                originalLanguage: "fr",
                block: .optionalExtension
            ),
            CalibrationMovie(
                id: 120_467,
                titleKnownInSpain: "El gran hotel Budapest",
                originalOrEnglishTitle: "The Grand Budapest Hotel",
                year: 2014,
                originalLanguage: "en",
                block: .optionalExtension
            ),
            CalibrationMovie(
                id: 447_332,
                titleKnownInSpain: "Un lugar tranquilo",
                originalOrEnglishTitle: "A Quiet Place",
                year: 2018,
                originalLanguage: "en",
                block: .optionalExtension
            ),
            CalibrationMovie(
                id: 906_126,
                titleKnownInSpain: "La sociedad de la nieve",
                originalOrEnglishTitle: "Society of the Snow",
                year: 2023,
                originalLanguage: "es",
                block: .optionalExtension
            ),
        ]
    )
}

enum CalibrationReaction: String, CaseIterable, Equatable, Sendable {
    case loveIt
    case likeIt
    case itWasOkay
    case didNotLikeIt
    case haveNotSeenIt
    case doNotKnowIt

    var title: String {
        switch self {
            case .loveIt: "Love it"
            case .likeIt: "Like it"
            case .itWasOkay: "It was okay"
            case .didNotLikeIt: "Didn't like it"
            case .haveNotSeenIt: "Haven't seen it"
            case .doNotKnowIt: "Don't know it"
        }
    }

    var isInformativeSignal: Bool {
        switch self {
            case .loveIt, .likeIt, .itWasOkay, .didNotLikeIt: true
            case .haveNotSeenIt, .doNotKnowIt: false
        }
    }

    var meansWatchedInCalibration: Bool {
        isInformativeSignal
    }
}

enum FirstOnboardingStep: String, Equatable, Sendable {
    case services
    case calibration
    case lowSignalDecision
    case completion
}

struct FirstOnboardingDraft: Equatable, Sendable {
    let catalog: CalibrationCatalog
    let step: FirstOnboardingStep
    let selectedServices: [PilotStreamingService]
    let reactions: [Int: CalibrationReaction]
    let currentCatalogPosition: Int
    let optionalExtensionAccepted: Bool
    let isCatalogFrozen: Bool

    var informativeSignalCount: Int {
        reactions.values.count(where: \.isInformativeSignal)
    }

    var catalogID: CalibrationCatalogID {
        catalog.id
    }

    init(
        catalog: CalibrationCatalog,
        step: FirstOnboardingStep,
        selectedServices: [PilotStreamingService],
        reactions: [Int: CalibrationReaction],
        currentCatalogPosition: Int,
        optionalExtensionAccepted: Bool,
        isCatalogFrozen: Bool? = nil
    ) {
        self.catalog = catalog
        self.step = step
        self.selectedServices = selectedServices
        self.reactions = reactions
        self.currentCatalogPosition = currentCatalogPosition
        self.optionalExtensionAccepted = optionalExtensionAccepted
        self.isCatalogFrozen = isCatalogFrozen ?? (step != .services)
    }

    init(
        catalogID: CalibrationCatalogID,
        step: FirstOnboardingStep,
        selectedServices: [PilotStreamingService],
        reactions: [Int: CalibrationReaction],
        currentCatalogPosition: Int,
        optionalExtensionAccepted: Bool,
        isCatalogFrozen: Bool? = nil
    ) {
        self.init(
            catalog: CalibrationCatalog(
                id: catalogID,
                movies: CalibrationCatalog.spainHouseholdV1.movies
            ),
            step: step,
            selectedServices: selectedServices,
            reactions: reactions,
            currentCatalogPosition: currentCatalogPosition,
            optionalExtensionAccepted: optionalExtensionAccepted,
            isCatalogFrozen: isCatalogFrozen
        )
    }

    static func empty(catalog: CalibrationCatalog) -> FirstOnboardingDraft {
        FirstOnboardingDraft(
            catalog: catalog,
            step: .services,
            selectedServices: [],
            reactions: [:],
            currentCatalogPosition: 0,
            optionalExtensionAccepted: false,
            isCatalogFrozen: false
        )
    }

    static func empty(snapshot: CalibrationCatalogSnapshot) -> FirstOnboardingDraft {
        FirstOnboardingDraft(
            catalog: snapshot.catalog,
            step: .services,
            selectedServices: [],
            reactions: [:],
            currentCatalogPosition: 0,
            optionalExtensionAccepted: false,
            isCatalogFrozen: true
        )
    }
}

struct RecalibrationDraft: Equatable, Sendable {
    let catalog: CalibrationCatalog
    let reactions: [Int: CalibrationReaction]
    let currentCatalogPosition: Int
    let optionalExtensionAccepted: Bool

    var informativeSignalCount: Int {
        reactions.values.count(where: \.isInformativeSignal)
    }

    var catalogID: CalibrationCatalogID {
        catalog.id
    }

    init(
        catalog: CalibrationCatalog,
        reactions: [Int: CalibrationReaction],
        currentCatalogPosition: Int,
        optionalExtensionAccepted: Bool
    ) {
        self.catalog = catalog
        self.reactions = reactions
        self.currentCatalogPosition = currentCatalogPosition
        self.optionalExtensionAccepted = optionalExtensionAccepted
    }

    init(
        catalogID: CalibrationCatalogID,
        reactions: [Int: CalibrationReaction],
        currentCatalogPosition: Int,
        optionalExtensionAccepted: Bool
    ) {
        self.init(
            catalog: CalibrationCatalog(
                id: catalogID,
                movies: CalibrationCatalog.spainHouseholdV1.movies
            ),
            reactions: reactions,
            currentCatalogPosition: currentCatalogPosition,
            optionalExtensionAccepted: optionalExtensionAccepted
        )
    }

    static func empty(catalog: CalibrationCatalog) -> RecalibrationDraft {
        RecalibrationDraft(
            catalog: catalog,
            reactions: [:],
            currentCatalogPosition: 0,
            optionalExtensionAccepted: false
        )
    }

    static func empty(snapshot: CalibrationCatalogSnapshot) -> RecalibrationDraft {
        .empty(catalog: snapshot.catalog)
    }
}

enum ViewerProfileDraft: Equatable, Sendable {
    case firstOnboarding(FirstOnboardingDraft)
    case recalibration(RecalibrationDraft)
}

struct ViewerProfile: Equatable, Sendable {
    static let currentSchemaVersion = 1

    let profileSchemaVersion: Int
    let catalogID: CalibrationCatalogID
    let region: ViewingRegion
    let selectedServices: [PilotStreamingService]
    let reactions: [Int: CalibrationReaction]

    var informativeSignalCount: Int {
        reactions.values.count(where: \.isInformativeSignal)
    }
}

enum ViewerProfileRecoveryReason: Equatable, Sendable {
    case unsupportedVersion
    case corruptData
    case loadFailed
}

enum ViewerProfileLoadState: Equatable, Sendable {
    case absent
    case firstOnboarding(FirstOnboardingDraft)
    case completed(profile: ViewerProfile, recalibrationDraft: RecalibrationDraft?)
    case recovery(ViewerProfileRecoveryReason)
}

enum CalibrationDestination: Equatable, Sendable {
    case movie(position: Int)
    case lowSignalDecision
    case completion
}

enum CalibrationFlow {
    static let confidenceTarget = 8
    static let normalLimit = 15

    static func destination(
        position: Int,
        reactions: [Int: CalibrationReaction],
        optionalExtensionAccepted: Bool,
        catalog: CalibrationCatalog
    ) -> CalibrationDestination {
        let informativeCount = reactions.values.count(where: \.isInformativeSignal)
        if informativeCount >= confidenceTarget {
            return .completion
        }
        if position < normalLimit {
            return .movie(position: position)
        }
        if !optionalExtensionAccepted {
            return informativeCount <= 2 ? .lowSignalDecision : .completion
        }
        if position < catalog.movies.count {
            return .movie(position: position)
        }
        return .completion
    }
}

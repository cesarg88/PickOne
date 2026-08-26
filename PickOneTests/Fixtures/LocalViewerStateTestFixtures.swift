import Foundation
@testable import PickOne

enum LocalViewerStateTestFixtures {
    static let firstID = UUID(uuidString: "10000000-0000-0000-0000-000000000001")
    static let secondID = UUID(uuidString: "20000000-0000-0000-0000-000000000002")
    static let thirdID = UUID(uuidString: "30000000-0000-0000-0000-000000000003")
    static let date = Date(timeIntervalSince1970: 1_700_000_000)
    static let laterDate = Date(timeIntervalSince1970: 1_700_001_000)

    static func emptyEnvelope(
        id: UUID,
        source: LocalViewerStateMigrationRecordV2DTO.Source = .freshInstall
    ) -> LocalViewerStateEnvelopeV2DTO {
        LocalViewerStateEnvelopeV2DTO(
            envelopeSchemaVersion: LocalViewerStateEnvelopeV2DTO.schemaVersion,
            committedStateSnapshotID: id,
            viewerProfileState: LocalViewerProfileStateV2DTO(
                completedProfile: nil,
                profileDraft: nil
            ),
            viewerMovieStates: [],
            migrationRecord: LocalViewerStateMigrationRecordV2DTO(
                source: source,
                resolvedAt: date
            )
        )
    }

    static func envelope(
        id: UUID,
        completedProfile: CompletedViewerProfileV2DTO? = nil,
        profileDraft: ViewerProfileDraftV2DTO? = nil
    ) -> LocalViewerStateEnvelopeV2DTO {
        let base = emptyEnvelope(id: id)
        return LocalViewerStateEnvelopeV2DTO(
            envelopeSchemaVersion: base.envelopeSchemaVersion,
            committedStateSnapshotID: base.committedStateSnapshotID,
            viewerProfileState: LocalViewerProfileStateV2DTO(
                completedProfile: completedProfile,
                profileDraft: profileDraft
            ),
            viewerMovieStates: base.viewerMovieStates,
            migrationRecord: base.migrationRecord
        )
    }

    static func completedProfile(
        catalogReference: CalibrationCatalogReferenceV2DTO
    ) -> CompletedViewerProfileV2DTO {
        CompletedViewerProfileV2DTO(
            profileSchemaVersion: CompletedViewerProfileV2DTO.schemaVersion,
            lastCompletedCatalogReference: catalogReference,
            regionCode: "ES",
            selectedProviderIDs: [8]
        )
    }

    static func profileDraft(
        catalogReference: CalibrationCatalogReferenceV2DTO
    ) -> ViewerProfileDraftV2DTO {
        let catalog = CalibrationCatalog.spainHouseholdV1
        return ViewerProfileDraftV2DTO(
            kind: .firstOnboarding,
            frozenCatalog: FrozenCalibrationCatalogV2DTO(
                reference: catalogReference,
                updatedAt: date,
                movies: catalog.movies.enumerated().map { order, movie in
                    FrozenCalibrationMovieV2DTO(
                        order: order,
                        movieID: movie.id,
                        titleKnownInSpain: movie.titleKnownInSpain,
                        originalOrEnglishTitle: movie.originalOrEnglishTitle,
                        year: movie.year,
                        originalLanguage: movie.originalLanguage,
                        block: movie.block.rawValue
                    )
                }
            ),
            currentStep: FirstOnboardingStep.services.rawValue,
            selectedProviderIDs: [8],
            reactionsByMovieID: [:],
            currentCatalogPosition: 0,
            optionalExtensionAccepted: false
        )
    }

    static func catalogReference(
        schemaVersion: Int = 1,
        catalogID: String = "es-household-calibration"
    ) -> CalibrationCatalogReferenceV2DTO {
        CalibrationCatalogReferenceV2DTO(
            schemaVersion: schemaVersion,
            catalogID: catalogID,
            version: 1,
            regionCode: "ES",
            localeIdentifier: "es-ES"
        )
    }

    static func encoded(_ envelope: LocalViewerStateEnvelopeV2DTO) throws -> Data {
        try JSONLocalViewerStateEnvelopeCoder().encode(envelope)
    }

    static func metadata(title: String = "Arrival") throws -> MovieFeedbackMetadata {
        try MovieFeedbackMetadata(
            title: title,
            releaseYear: 2016,
            posterPath: "/arrival.jpg"
        )
    }

    static func uuid(_ value: UUID?) throws -> UUID {
        guard let value else { throw LocalViewerStateTestError.rejected }
        return value
    }
}

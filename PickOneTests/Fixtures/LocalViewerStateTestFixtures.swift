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

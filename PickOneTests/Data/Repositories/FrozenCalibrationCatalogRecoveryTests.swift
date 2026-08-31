import Foundation
@testable import PickOne
import Testing

@Suite("Frozen calibration catalog recovery")
struct FrozenCalibrationCatalogRecoveryTests {
    enum InvalidCatalog: CaseIterable, Sendable {
        case year
        case whitespaceLanguage
        case blockOrder
    }

    @Test(
        "semantic catalog corruption preserves and quarantines exact bytes",
        arguments: InvalidCatalog.allCases
    )
    func semanticCorruptionIsQuarantined(invalidCatalog: InvalidCatalog) async throws {
        let id = try LocalViewerStateTestFixtures.uuid(LocalViewerStateTestFixtures.firstID)
        let bytes = try corruptedEnvelope(id: id, invalidCatalog: invalidCatalog)
        let files = InMemoryLocalViewerStateFileStore(activeData: bytes)

        let state = await repository(files: files).loadState()

        #expect(state == .recovery(.corruptData))
        #expect(files.activeData == bytes)
        #expect(files.quarantinedItems == [
            LocalViewerStateQuarantineItem(source: .active, data: bytes),
        ])
    }

    private func corruptedEnvelope(
        id: UUID,
        invalidCatalog: InvalidCatalog
    ) throws -> Data {
        let draft = LocalViewerStateTestFixtures.profileDraft(
            catalogReference: LocalViewerStateTestFixtures.catalogReference()
        )
        var movies = draft.frozenCatalog.movies
        switch invalidCatalog {
            case .year:
                movies[0] = replacing(movies[0], year: 1887)
            case .whitespaceLanguage:
                movies[0] = replacing(movies[0], language: "   ")
            case .blockOrder:
                movies[0] = replacing(movies[0], block: CalibrationCatalogBlock.reserve.rawValue)
                movies[12] = replacing(
                    movies[12],
                    block: CalibrationCatalogBlock.primary.rawValue
                )
        }
        let corruptedDraft = ViewerProfileDraftV2DTO(
            kind: draft.kind,
            frozenCatalog: FrozenCalibrationCatalogV2DTO(
                reference: draft.frozenCatalog.reference,
                updatedAt: draft.frozenCatalog.updatedAt,
                movies: movies
            ),
            currentStep: draft.currentStep,
            selectedProviderIDs: draft.selectedProviderIDs,
            reactionsByMovieID: draft.reactionsByMovieID,
            currentCatalogPosition: draft.currentCatalogPosition,
            optionalExtensionAccepted: draft.optionalExtensionAccepted,
            catalogIsFrozen: draft.catalogIsFrozen
        )
        return try LocalViewerStateTestFixtures.encoded(
            LocalViewerStateTestFixtures.envelope(
                id: id,
                profileDraft: corruptedDraft
            )
        )
    }

    private func replacing(
        _ movie: FrozenCalibrationMovieV2DTO,
        year: Int? = nil,
        language: String? = nil,
        block: String? = nil
    ) -> FrozenCalibrationMovieV2DTO {
        FrozenCalibrationMovieV2DTO(
            order: movie.order,
            movieID: movie.movieID,
            titleKnownInSpain: movie.titleKnownInSpain,
            originalOrEnglishTitle: movie.originalOrEnglishTitle,
            year: year ?? movie.year,
            originalLanguage: language ?? movie.originalLanguage,
            block: block ?? movie.block
        )
    }

    private func repository(
        files: InMemoryLocalViewerStateFileStore
    ) -> LocalViewerStateRepository {
        LocalViewerStateRepository(
            fileStore: files,
            legacySource: InMemoryLegacyViewerStateSource(),
            snapshotID: UUID.init,
            now: { LocalViewerStateTestFixtures.date }
        )
    }
}

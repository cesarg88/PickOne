import Foundation
@testable import PickOne
import Testing

@Suite("Calibration catalog document")
struct CalibrationCatalogDocumentTests {
    private let decoder = CalibrationCatalogDocumentDecoder()

    @Test("bundled JSON exactly mirrors the approved household catalog")
    func bundledDocumentMatchesApprovedCatalog() throws {
        let document = try CalibrationCatalogTestFixtures.document()

        #expect(document.snapshot.catalog == .spainHouseholdV1)
        #expect(document.snapshot.reference == CalibrationCatalogReference(
            schemaVersion: 1,
            catalogID: "es-household-calibration",
            version: 1,
            region: "ES",
            locale: "es-ES"
        ))
        #expect(document.snapshot.updatedAt == CalibrationCatalogTestFixtures.updatedAt)
    }

    @Test("unsupported schema is incompatible rather than invalid")
    func unsupportedSchemaIsIncompatible() throws {
        let data = try replacing(
            "\"schemaVersion\": 1",
            with: "\"schemaVersion\": 2"
        )

        #expect(throws: CalibrationCatalogDocumentError.incompatible) {
            try decoder.decode(data, expectedRegion: "ES", expectedLocale: "es-ES")
        }
    }

    @Test("invalid JSON, date, block, and noncontiguous order reject the complete document")
    func invalidDocumentsAreRejected() throws {
        #expect(throws: CalibrationCatalogDocumentError.invalid) {
            try decoder.decode(Data("{".utf8), expectedRegion: "ES", expectedLocale: "es-ES")
        }

        let invalidDate = try replacing(
            "2026-08-19T00:00:00Z",
            with: "not-a-date"
        )
        #expect(throws: CalibrationCatalogDocumentError.invalid) {
            try decoder.decode(invalidDate, expectedRegion: "ES", expectedLocale: "es-ES")
        }

        let invalidBlock = try replacing(
            "\"block\": \"reserve\"",
            with: "\"block\": \"other\""
        )
        #expect(throws: CalibrationCatalogDocumentError.invalid) {
            try decoder.decode(invalidBlock, expectedRegion: "ES", expectedLocale: "es-ES")
        }

        let invalidOrder = try replacing(
            "\"order\": 20",
            with: "\"order\": 19"
        )
        #expect(throws: CalibrationCatalogDocumentError.invalid) {
            try decoder.decode(invalidOrder, expectedRegion: "ES", expectedLocale: "es-ES")
        }
    }

    @Test("response size is rejected before decoding")
    func oversizedResponseIsRejected() {
        let data = Data(
            repeating: 0,
            count: CalibrationCatalogDocumentDecoder.maximumResponseBytes + 1
        )

        #expect(throws: CalibrationCatalogDocumentError.responseTooLarge) {
            try decoder.decode(data, expectedRegion: "ES", expectedLocale: "es-ES")
        }
    }

    private func replacing(_ target: String, with replacement: String) throws -> Data {
        let original = try CalibrationCatalogTestFixtures.documentData()
        let text = try #require(String(data: original, encoding: .utf8))
        let replaced = text.replacingOccurrences(of: target, with: replacement)
        #expect(replaced != text)
        return Data(replaced.utf8)
    }
}

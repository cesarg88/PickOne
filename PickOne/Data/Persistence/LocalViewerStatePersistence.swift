import Foundation

enum LocalViewerStateCodingError: Error, Equatable, Sendable {
    case corruptData
    case unsupportedSchema
}

protocol LocalViewerStateEnvelopeCoding: Sendable {
    func decode(_ data: Data) throws -> LocalViewerStateEnvelopeV2DTO
    func encode(_ envelope: LocalViewerStateEnvelopeV2DTO) throws -> Data
}

struct JSONLocalViewerStateEnvelopeCoder: LocalViewerStateEnvelopeCoding {
    func decode(_ data: Data) throws -> LocalViewerStateEnvelopeV2DTO {
        let header: LocalViewerStateEnvelopeHeaderDTO
        do {
            header = try JSONDecoder().decode(LocalViewerStateEnvelopeHeaderDTO.self, from: data)
        } catch {
            throw LocalViewerStateCodingError.corruptData
        }
        guard header.envelopeSchemaVersion == LocalViewerStateEnvelopeV2DTO.schemaVersion else {
            throw LocalViewerStateCodingError.unsupportedSchema
        }

        do {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .millisecondsSince1970
            return try decoder.decode(LocalViewerStateEnvelopeV2DTO.self, from: data)
        } catch {
            throw LocalViewerStateCodingError.corruptData
        }
    }

    func encode(_ envelope: LocalViewerStateEnvelopeV2DTO) throws -> Data {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .millisecondsSince1970
        encoder.outputFormatting = [.sortedKeys]
        return try encoder.encode(envelope)
    }
}

private struct LocalViewerStateEnvelopeHeaderDTO: Decodable {
    let envelopeSchemaVersion: Int
}

struct LocalViewerStateEnvelopeV2DTO: Codable, Equatable, Sendable {
    static let schemaVersion = 2

    let envelopeSchemaVersion: Int
    let committedStateSnapshotID: UUID
    let viewerProfileState: LocalViewerProfileStateV2DTO
    let viewerMovieStates: [ViewerMovieStateV2DTO]
    let migrationRecord: LocalViewerStateMigrationRecordV2DTO
}

struct LocalViewerProfileStateV2DTO: Codable, Equatable, Sendable {
    let completedProfile: CompletedViewerProfileV2DTO?
    let profileDraft: ViewerProfileDraftV2DTO?
}

struct CompletedViewerProfileV2DTO: Codable, Equatable, Sendable {
    static let schemaVersion = 2

    let profileSchemaVersion: Int
    let lastCompletedCatalogReference: CalibrationCatalogReferenceV2DTO
    let regionCode: String
    let selectedProviderIDs: [Int]
}

struct ViewerProfileDraftV2DTO: Codable, Equatable, Sendable {
    enum Kind: String, Codable, Sendable {
        case firstOnboarding
        case recalibration
    }

    let kind: Kind
    let frozenCatalog: FrozenCalibrationCatalogV2DTO
    let currentStep: String?
    let selectedProviderIDs: [Int]?
    let reactionsByMovieID: [Int: String]
    let currentCatalogPosition: Int
    let optionalExtensionAccepted: Bool
}

struct FrozenCalibrationCatalogV2DTO: Codable, Equatable, Sendable {
    let reference: CalibrationCatalogReferenceV2DTO
    let updatedAt: Date
    let movies: [FrozenCalibrationMovieV2DTO]
}

struct CalibrationCatalogReferenceV2DTO: Codable, Equatable, Sendable {
    let schemaVersion: Int
    let catalogID: String
    let version: Int
    let regionCode: String
    let localeIdentifier: String
}

struct FrozenCalibrationMovieV2DTO: Codable, Equatable, Sendable {
    let order: Int
    let movieID: Int
    let titleKnownInSpain: String
    let originalOrEnglishTitle: String
    let year: Int
    let originalLanguage: String
    let block: String
}

struct ViewerMovieStateV2DTO: Codable, Equatable, Sendable {
    let movieID: Int
    let title: String
    let releaseYear: Int?
    let posterPath: String?
    let watchState: String
    let preference: ViewerMoviePreferenceV2DTO?
    let watchlistAddedAt: Date?
    let stateChangedAt: Date
}

struct ViewerMoviePreferenceV2DTO: Codable, Equatable, Sendable {
    let kind: String
    let reaction: String?
}

struct LocalViewerStateMigrationRecordV2DTO: Codable, Equatable, Sendable {
    enum Source: String, Codable, Sendable {
        case freshInstall
        case legacyMigration
        case previousRecovery
        case legacyRecovery
    }

    let source: Source
    let resolvedAt: Date
}

enum LocalViewerStateQuarantineSource: String, Equatable, Sendable {
    case active
    case previous
}

struct LocalViewerStateQuarantineItem: Equatable, Sendable {
    let source: LocalViewerStateQuarantineSource
    let data: Data
}

protocol LocalViewerStateFileStore: Sendable {
    func readActive() throws -> Data?
    func readPrevious() throws -> Data?
    func replaceActive(with data: Data) throws
    func replacePrevious(with data: Data) throws
    func quarantine(_ data: Data, source: LocalViewerStateQuarantineSource) throws
}

struct ApplicationSupportViewerStateStore: LocalViewerStateFileStore {
    private let directoryURL: URL
    private let quarantineName: @Sendable () -> UUID

    init(
        directoryURL: URL? = nil,
        quarantineName: @escaping @Sendable () -> UUID = UUID.init
    ) throws {
        if let directoryURL {
            self.directoryURL = directoryURL
        } else {
            self.directoryURL = try FileManager.default.url(
                for: .applicationSupportDirectory,
                in: .userDomainMask,
                appropriateFor: nil,
                create: false
            ).appending(path: "PickOne/ViewerState", directoryHint: .isDirectory)
        }
        self.quarantineName = quarantineName
    }

    func readActive() throws -> Data? {
        try read(activeURL)
    }

    func readPrevious() throws -> Data? {
        try read(previousURL)
    }

    func replaceActive(with data: Data) throws {
        try replace(data, at: activeURL)
    }

    func replacePrevious(with data: Data) throws {
        try replace(data, at: previousURL)
    }

    func quarantine(_ data: Data, source: LocalViewerStateQuarantineSource) throws {
        let fileManager = FileManager.default
        try fileManager.createDirectory(
            at: quarantineURL,
            withIntermediateDirectories: true
        )
        let destination = quarantineURL.appending(
            path: "\(quarantineName().uuidString)-\(source.rawValue).json"
        )
        try data.write(to: destination, options: .withoutOverwriting)
    }

    private var activeURL: URL {
        directoryURL.appending(path: "viewer-state-v2.json")
    }

    private var previousURL: URL {
        directoryURL.appending(path: "viewer-state-v2.previous.json")
    }

    private var quarantineURL: URL {
        directoryURL.appending(path: "Quarantine", directoryHint: .isDirectory)
    }

    private func read(_ url: URL) throws -> Data? {
        guard FileManager.default.fileExists(atPath: url.path()) else {
            return nil
        }
        return try Data(contentsOf: url)
    }

    private func replace(_ data: Data, at destination: URL) throws {
        let fileManager = FileManager.default
        try fileManager.createDirectory(
            at: directoryURL,
            withIntermediateDirectories: true
        )
        let staged = directoryURL.appending(
            path: ".\(UUID().uuidString)-staged.json"
        )
        do {
            try data.write(to: staged, options: .withoutOverwriting)
            if fileManager.fileExists(atPath: destination.path()) {
                _ = try fileManager.replaceItemAt(
                    destination,
                    withItemAt: staged,
                    backupItemName: nil,
                    options: .usingNewMetadataOnly
                )
            } else {
                try fileManager.moveItem(at: staged, to: destination)
            }
        } catch {
            try? fileManager.removeItem(at: staged)
            throw error
        }
    }
}

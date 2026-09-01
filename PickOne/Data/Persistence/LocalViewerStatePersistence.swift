import Foundation

enum LocalViewerStateCodingError: Error, Equatable, Sendable {
    case corruptData
    case unsupportedSchema
}

protocol LocalViewerStateEnvelopeCoding: Sendable {
    func decode(_ data: Data) throws -> DecodedLocalViewerStateEnvelopeDTO
    func encode(_ envelope: LocalViewerStateEnvelopeV3DTO) throws -> Data
}

struct JSONLocalViewerStateEnvelopeCoder: LocalViewerStateEnvelopeCoding {
    func decode(_ data: Data) throws -> DecodedLocalViewerStateEnvelopeDTO {
        let header: LocalViewerStateEnvelopeHeaderDTO
        do {
            header = try JSONDecoder().decode(LocalViewerStateEnvelopeHeaderDTO.self, from: data)
        } catch {
            throw LocalViewerStateCodingError.corruptData
        }
        do {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .millisecondsSince1970
            return switch header.envelopeSchemaVersion {
                case LocalViewerStateEnvelopeV2DTO.schemaVersion:
                    try .legacyV2(decoder.decode(LocalViewerStateEnvelopeV2DTO.self, from: data))
                case LocalViewerStateEnvelopeV3DTO.schemaVersion:
                    try .currentV3(decoder.decode(LocalViewerStateEnvelopeV3DTO.self, from: data))
                default:
                    throw LocalViewerStateCodingError.unsupportedSchema
            }
        } catch let error as LocalViewerStateCodingError {
            throw error
        } catch {
            throw LocalViewerStateCodingError.corruptData
        }
    }

    func encode(_ envelope: LocalViewerStateEnvelopeV3DTO) throws -> Data {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .millisecondsSince1970
        encoder.outputFormatting = [.sortedKeys]
        return try encoder.encode(envelope)
    }

    func encodeLegacyV2(_ envelope: LocalViewerStateEnvelopeV2DTO) throws -> Data {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .millisecondsSince1970
        encoder.outputFormatting = [.sortedKeys]
        return try encoder.encode(envelope)
    }
}

private struct LocalViewerStateEnvelopeHeaderDTO: Decodable {
    let envelopeSchemaVersion: Int
}

enum DecodedLocalViewerStateEnvelopeDTO: Equatable, Sendable {
    case legacyV2(LocalViewerStateEnvelopeV2DTO)
    case currentV3(LocalViewerStateEnvelopeV3DTO)
}

struct LocalViewerStateEnvelopeV2DTO: Codable, Equatable, Sendable {
    static let schemaVersion = 2

    let envelopeSchemaVersion: Int
    let committedStateSnapshotID: UUID
    let viewerProfileState: LocalViewerProfileStateV2DTO
    let viewerMovieStates: [ViewerMovieStateV2DTO]
    let migrationRecord: LocalViewerStateMigrationRecordV2DTO
}

struct LocalViewerStateEnvelopeV3DTO: Codable, Equatable, Sendable {
    static let schemaVersion = 3

    let envelopeSchemaVersion: Int
    let committedStateSnapshotID: UUID
    let recommendationSuppressionEpochID: UUID
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
    let catalogIsFrozen: Bool?
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
    func removePrevious() throws
    func quarantine(_ data: Data, source: LocalViewerStateQuarantineSource) throws
    func removeAllViewerState() throws
}

enum LocalViewerStateFileStoreError: Error, Sendable {
    case unavailable
}

struct UnavailableLocalViewerStateFileStore: LocalViewerStateFileStore {
    func readActive() throws -> Data? {
        throw LocalViewerStateFileStoreError.unavailable
    }

    func readPrevious() throws -> Data? {
        throw LocalViewerStateFileStoreError.unavailable
    }

    func replaceActive(with _: Data) throws {
        throw LocalViewerStateFileStoreError.unavailable
    }

    func replacePrevious(with _: Data) throws {
        throw LocalViewerStateFileStoreError.unavailable
    }

    func removePrevious() throws {
        throw LocalViewerStateFileStoreError.unavailable
    }

    func quarantine(_: Data, source _: LocalViewerStateQuarantineSource) throws {
        throw LocalViewerStateFileStoreError.unavailable
    }

    func removeAllViewerState() throws {
        throw LocalViewerStateFileStoreError.unavailable
    }
}

struct ApplicationSupportViewerStateStore: LocalViewerStateFileStore {
    private let directoryURL: URL
    private let quarantineName: @Sendable () -> UUID
    private let removeReplacementBackup: @Sendable (URL) throws -> Void

    init(
        directoryURL: URL? = nil,
        quarantineName: @escaping @Sendable () -> UUID = UUID.init,
        removeReplacementBackup: @escaping @Sendable (URL) throws -> Void = {
            try FileManager.default.removeItem(at: $0)
        }
    ) throws {
        if let directoryURL {
            self.directoryURL = directoryURL
        } else {
            self.directoryURL = try FileManager.default.url(
                for: .applicationSupportDirectory,
                in: .userDomainMask,
                appropriateFor: nil,
                create: true
            ).appending(path: "PickOne/ViewerState", directoryHint: .isDirectory)
        }
        self.quarantineName = quarantineName
        self.removeReplacementBackup = removeReplacementBackup
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

    func removePrevious() throws {
        let fileManager = FileManager.default
        guard fileManager.fileExists(atPath: previousURL.path(percentEncoded: false)) else {
            return
        }
        try fileManager.removeItem(at: previousURL)
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

    func removeAllViewerState() throws {
        let fileManager = FileManager.default
        guard fileManager.fileExists(atPath: directoryURL.path(percentEncoded: false)) else {
            return
        }
        try fileManager.removeItem(at: directoryURL)
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
        guard FileManager.default.fileExists(atPath: url.path(percentEncoded: false)) else {
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
        let stagingDirectory = directoryURL.appending(
            path: ".\(UUID().uuidString)-staging",
            directoryHint: .isDirectory
        )
        let staged = stagingDirectory.appending(path: destination.lastPathComponent)
        let backupName = ".\(UUID().uuidString)-replacement-backup.json"
        let backup = directoryURL.appending(path: backupName)
        do {
            try fileManager.createDirectory(
                at: stagingDirectory,
                withIntermediateDirectories: false
            )
            try data.write(to: staged, options: .withoutOverwriting)
            if fileManager.fileExists(atPath: destination.path(percentEncoded: false)) {
                _ = try fileManager.replaceItemAt(
                    destination,
                    withItemAt: staged,
                    backupItemName: backupName,
                    options: [.usingNewMetadataOnly, .withoutDeletingBackupItem]
                )
                if fileManager.fileExists(atPath: backup.path(percentEncoded: false)) {
                    try? removeReplacementBackup(backup)
                }
            } else {
                try fileManager.moveItem(at: staged, to: destination)
            }
            try? fileManager.removeItem(at: stagingDirectory)
        } catch {
            try? fileManager.removeItem(at: stagingDirectory)
            throw error
        }
    }
}

import CryptoKit
import Foundation
import Synchronization

struct StableDecisionCycleSigner: Sendable {
    func signature(for identity: DecisionCycleIdentity) throws -> DecisionCycleSignature {
        let dto = DecisionCycleIdentityV1DTO(
            engineModelVersion: identity.engineModelVersion.rawValue,
            profileSchemaVersion: identity.profileSchemaVersion,
            calibrationCatalogVersion: identity.calibrationCatalogVersion,
            regionCode: identity.region.code,
            selectedProviderIDs: identity.selectedProviderIDs.sorted(),
            reactions: identity.reactions
                .sorted { $0.movieID < $1.movieID }
                .map {
                    DecisionIdentityReactionV1DTO(
                        movieID: $0.movieID,
                        reaction: $0.reaction.rawValue
                    )
                },
            viewingContext: identity.viewingContext.rawValue
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let digest = try SHA256.hash(data: encoder.encode(dto))
        guard let signature = DecisionCycleSignature(
            rawValue: digest.map { String(format: "%02x", $0) }.joined()
        ) else {
            throw DecisionSetCodingError.corruptData
        }
        return signature
    }
}

private struct DecisionCycleIdentityV1DTO: Encodable {
    let engineModelVersion: String
    let profileSchemaVersion: Int
    let calibrationCatalogVersion: String
    let regionCode: String
    let selectedProviderIDs: [Int]
    let reactions: [DecisionIdentityReactionV1DTO]
    let viewingContext: String
}

private struct DecisionIdentityReactionV1DTO: Encodable {
    let movieID: Int
    let reaction: String
}

protocol DecisionSetDataStore: Sendable {
    func readActive() throws -> Data?
    func replaceActive(with data: Data) throws
    func readQuarantine() throws -> Data?
    func replaceQuarantine(with data: Data) throws
}

final class UserDefaultsDecisionSetDataStore: DecisionSetDataStore {
    static let activeStorageKey = "decision_set_envelope_v1"
    static let quarantineStorageKey = "decision_set_diagnostic_quarantine"

    private enum Backend: Sendable {
        case standard
        case suite(String)

        func makeUserDefaults() -> UserDefaults {
            switch self {
                case .standard:
                    return .standard
                case let .suite(name):
                    guard let defaults = UserDefaults(suiteName: name) else {
                        preconditionFailure("Invalid UserDefaults suite name: \(name)")
                    }
                    return defaults
            }
        }
    }

    private let backend: Mutex<Backend>

    init() {
        backend = Mutex(.standard)
    }

    init(suiteName: String) {
        backend = Mutex(.suite(suiteName))
    }

    func readActive() throws -> Data? {
        backend.withLock { $0.makeUserDefaults().data(forKey: Self.activeStorageKey) }
    }

    func replaceActive(with data: Data) throws {
        backend.withLock { $0.makeUserDefaults().set(data, forKey: Self.activeStorageKey) }
    }

    func readQuarantine() throws -> Data? {
        backend.withLock { $0.makeUserDefaults().data(forKey: Self.quarantineStorageKey) }
    }

    func replaceQuarantine(with data: Data) throws {
        backend.withLock { $0.makeUserDefaults().set(data, forKey: Self.quarantineStorageKey) }
    }
}

protocol DecisionSetEnvelopeCoding: Sendable {
    func decodeEnvelope(from data: Data) throws -> DecisionSetEnvelopeV1DTO
    func encodeEnvelope(_ envelope: DecisionSetEnvelopeV1DTO) throws -> Data
}

enum DecisionSetCodingError: Error {
    case unsupportedVersion
    case corruptData
}

struct JSONDecisionSetEnvelopeCoder: DecisionSetEnvelopeCoding {
    func decodeEnvelope(from data: Data) throws -> DecisionSetEnvelopeV1DTO {
        let header: DecisionSetEnvelopeHeaderDTO
        do {
            header = try JSONDecoder().decode(DecisionSetEnvelopeHeaderDTO.self, from: data)
        } catch {
            throw DecisionSetCodingError.corruptData
        }
        guard header.envelopeSchemaVersion == DecisionSetEnvelopeV1DTO.schemaVersion else {
            throw DecisionSetCodingError.unsupportedVersion
        }
        do {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .millisecondsSince1970
            return try decoder.decode(DecisionSetEnvelopeV1DTO.self, from: data)
        } catch {
            throw DecisionSetCodingError.corruptData
        }
    }

    func encodeEnvelope(_ envelope: DecisionSetEnvelopeV1DTO) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        encoder.dateEncodingStrategy = .millisecondsSince1970
        return try encoder.encode(envelope)
    }
}

private struct DecisionSetEnvelopeHeaderDTO: Decodable {
    let envelopeSchemaVersion: Int
}

struct DecisionSetEnvelopeV1DTO: Codable, Equatable, Sendable {
    static let schemaVersion = 1

    let envelopeSchemaVersion: Int
    let decisionSetID: UUID
    let generatedAt: Date
    let engineModelVersion: String
    let cycle: DecisionCycleV1DTO
    let regionCode: String
    let selectedProviderIDs: [Int]
    let recommendations: [PersistedDecisionRecommendationV1DTO]
}

struct DecisionCycleV1DTO: Codable, Equatable, Sendable {
    let id: UUID
    let identitySignature: String
    let shownMovieIDs: [Int]
}

struct PersistedDecisionRecommendationV1DTO: Codable, Equatable, Sendable {
    let role: String
    let evidence: RecommendationEvidenceV1DTO
    let display: DecisionDisplaySnapshotV1DTO
    let availability: DecisionAvailabilitySnapshotV1DTO
}

struct DecisionDisplaySnapshotV1DTO: Codable, Equatable, Sendable {
    let movieID: Int
    let localizedTitle: String
    let posterPath: String?
    let backdropPath: String?
    let runtimeMinutes: Int?
    let releaseYear: Int?
    let genres: [DecisionGenreV1DTO]
}

struct DecisionGenreV1DTO: Codable, Equatable, Sendable {
    let id: Int
    let name: String?
}

struct DecisionAvailabilitySnapshotV1DTO: Codable, Equatable, Sendable {
    let matchingProviders: [DecisionProviderSnapshotV1DTO]
    let verifiedAt: Date
    let regionalWatchURL: String?
}

struct DecisionProviderSnapshotV1DTO: Codable, Equatable, Sendable {
    let providerID: Int
    let name: String
    let logoPath: String?
    let productOrder: Int
}

struct RecommendationEvidenceV1DTO: Codable, Equatable, Sendable {
    let primaryKind: String
    let tasteKind: String?
    let anchor: PositiveAnchorEvidenceV1DTO?
    let affinity: PositiveAffinityEvidenceV1DTO?
    let diversityKind: String?
}

struct PositiveAnchorEvidenceV1DTO: Codable, Equatable, Sendable {
    let movieID: Int
    let movieTitle: String
    let reaction: String
    let sharedGenres: [DecisionGenreV1DTO]
    let eraMatch: RecommendationEraMatchV1DTO?
}

struct PositiveAffinityEvidenceV1DTO: Codable, Equatable, Sendable {
    let genres: [DecisionGenreV1DTO]
    let eraStartingYear: Int?
}

struct RecommendationEraMatchV1DTO: Codable, Equatable, Sendable {
    let kind: String
    let candidateStartingYear: Int?
    let anchorStartingYear: Int
}

import Foundation
import Synchronization

protocol ViewerProfileDataStore: Sendable {
    func read() throws -> Data?
    func replace(with data: Data) throws
    func remove() throws
}

final class UserDefaultsViewerProfileDataStore: ViewerProfileDataStore {
    static let storageKey = "viewer_state_envelope"

    private enum Backend: Sendable {
        case standard
        case suite(String)

        func makeUserDefaults() -> UserDefaults {
            switch self {
                case .standard:
                    return UserDefaults.standard
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

    func read() throws -> Data? {
        backend.withLock { backend in
            backend.makeUserDefaults().data(forKey: Self.storageKey)
        }
    }

    func replace(with data: Data) throws {
        backend.withLock { backend in
            backend.makeUserDefaults().set(data, forKey: Self.storageKey)
        }
    }

    func remove() throws {
        backend.withLock { backend in
            backend.makeUserDefaults().removeObject(forKey: Self.storageKey)
        }
    }
}

protocol ViewerProfileEnvelopeCoding: Sendable {
    func decodeEnvelope(from data: Data) throws -> ViewerStateEnvelopeV1DTO
    func encodeEnvelope(_ envelope: ViewerStateEnvelopeV1DTO) throws -> Data
}

enum ViewerProfileCodingError: Error {
    case unsupportedVersion
    case corruptData
}

struct JSONViewerProfileEnvelopeCoder: ViewerProfileEnvelopeCoding {
    func decodeEnvelope(from data: Data) throws -> ViewerStateEnvelopeV1DTO {
        let header: ViewerStateEnvelopeHeaderDTO
        do {
            header = try JSONDecoder().decode(ViewerStateEnvelopeHeaderDTO.self, from: data)
        } catch {
            throw ViewerProfileCodingError.corruptData
        }
        guard header.envelopeSchemaVersion == ViewerStateEnvelopeV1DTO.schemaVersion else {
            throw ViewerProfileCodingError.unsupportedVersion
        }
        do {
            return try JSONDecoder().decode(ViewerStateEnvelopeV1DTO.self, from: data)
        } catch {
            throw ViewerProfileCodingError.corruptData
        }
    }

    func encodeEnvelope(_ envelope: ViewerStateEnvelopeV1DTO) throws -> Data {
        try JSONEncoder().encode(envelope)
    }
}

private struct ViewerStateEnvelopeHeaderDTO: Decodable {
    let envelopeSchemaVersion: Int
}

struct ViewerStateEnvelopeV1DTO: Codable, Equatable, Sendable {
    static let schemaVersion = 1

    let envelopeSchemaVersion: Int
    let completedProfile: ViewerProfileV1DTO?
    let profileDraft: ViewerProfileDraftV1DTO?
}

struct ViewerProfileV1DTO: Codable, Equatable, Sendable {
    let profileSchemaVersion: Int
    let calibrationCatalogVersion: String
    let regionCode: String
    let selectedProviderIDs: [Int]
    let reactionsByMovieID: [Int: String]
}

struct ViewerProfileDraftV1DTO: Codable, Equatable, Sendable {
    enum Kind: String, Codable, Sendable {
        case firstOnboarding
        case recalibration
    }

    let kind: Kind
    let firstOnboarding: FirstOnboardingDraftV1DTO?
    let recalibration: RecalibrationDraftV1DTO?
}

struct FirstOnboardingDraftV1DTO: Codable, Equatable, Sendable {
    let calibrationCatalogVersion: String
    let currentStep: String
    let selectedProviderIDs: [Int]
    let reactionsByMovieID: [Int: String]
    let currentCatalogPosition: Int
    let optionalExtensionAccepted: Bool
}

struct RecalibrationDraftV1DTO: Codable, Equatable, Sendable {
    let calibrationCatalogVersion: String
    let reactionsByMovieID: [Int: String]
    let currentCatalogPosition: Int
    let optionalExtensionAccepted: Bool
}

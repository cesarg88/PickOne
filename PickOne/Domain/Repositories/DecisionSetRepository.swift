import Foundation

enum DecisionSetRecoveryReason: Equatable, Sendable {
    case corruptData
    case unsupportedVersion
    case loadFailed
    case quarantineFailed
}

enum DecisionSetLoadResult: Equatable, Sendable {
    case absent
    case available(PersistedDecisionSet)
    case migrationRequired(DecisionSetMigrationSource)
    case recovery(DecisionSetRecoveryReason)
}

struct DecisionSetPublicationTransaction: Hashable, Sendable {
    let id: UUID

    init(id: UUID = UUID()) {
        self.id = id
    }
}

protocol DecisionSetRepository: Sendable {
    func load() async -> DecisionSetLoadResult
    func beginPublicationTransaction() async throws -> DecisionSetPublicationTransaction
    func stage(
        _ envelope: PersistedDecisionSet,
        in transaction: DecisionSetPublicationTransaction
    ) async throws
    func commit(_ transaction: DecisionSetPublicationTransaction) async throws
    func discard(_ transaction: DecisionSetPublicationTransaction) async throws
}

enum DecisionSetRepositoryError: Error, Equatable, Sendable {
    case encodingFailed
    case storageFailed
}

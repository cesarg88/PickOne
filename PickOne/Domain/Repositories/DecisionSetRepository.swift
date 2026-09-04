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

struct DecisionSetPersistenceCheckpoint: Hashable, Sendable {
    let id: UUID

    init(id: UUID = UUID()) {
        self.id = id
    }
}

protocol DecisionSetRepository: Sendable {
    func load() async -> DecisionSetLoadResult
    func makePersistenceCheckpoint() async throws -> DecisionSetPersistenceCheckpoint
    func replace(_ envelope: PersistedDecisionSet) async throws
    func replace(
        _ envelope: PersistedDecisionSet,
        using checkpoint: DecisionSetPersistenceCheckpoint
    ) async throws
    func restorePersistenceCheckpoint(
        _ checkpoint: DecisionSetPersistenceCheckpoint
    ) async throws
}

enum DecisionSetRepositoryError: Error, Equatable, Sendable {
    case encodingFailed
    case storageFailed
}

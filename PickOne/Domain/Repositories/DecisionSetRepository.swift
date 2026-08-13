enum DecisionSetRecoveryReason: Equatable, Sendable {
    case corruptData
    case unsupportedVersion
    case loadFailed
    case quarantineFailed
}

enum DecisionSetLoadResult: Equatable, Sendable {
    case absent
    case available(PersistedDecisionSet)
    case recovery(DecisionSetRecoveryReason)
}

protocol DecisionSetRepository: Sendable {
    func load() async -> DecisionSetLoadResult
    func replace(_ envelope: PersistedDecisionSet) async throws
}

enum DecisionSetRepositoryError: Error, Equatable, Sendable {
    case encodingFailed
    case storageFailed
}

import Foundation

extension DefaultDecisionSetRepository {
    func makePersistenceCheckpoint() async throws -> DecisionSetPersistenceCheckpoint {
        let checkpoint = DecisionSetPersistenceCheckpoint()
        do {
            checkpointSequence += 1
            persistenceCheckpoints[checkpoint] = try StoredPersistenceCheckpoint(
                previousData: store.readActive(),
                previousOwner: activeCheckpoint,
                sequence: checkpointSequence
            )
            return checkpoint
        } catch {
            throw DecisionSetRepositoryError.storageFailed
        }
    }

    func restorePersistenceCheckpoint(
        _ checkpoint: DecisionSetPersistenceCheckpoint
    ) async throws {
        guard var stored = persistenceCheckpoints[checkpoint], stored.status == .open else {
            throw DecisionSetRepositoryError.storageFailed
        }
        guard activeCheckpoint == checkpoint else {
            stored.status = .cancelled
            persistenceCheckpoints[checkpoint] = stored
            return
        }
        let restoration = resolvedRestoration(for: stored)
        do {
            if let data = restoration.data {
                try store.replaceActive(with: data)
            } else {
                try store.removeActive()
            }
            stored.status = .cancelled
            persistenceCheckpoints[checkpoint] = stored
            activeCheckpoint = restoration.owner
        } catch {
            throw DecisionSetRepositoryError.storageFailed
        }
    }

    private func resolvedRestoration(
        for checkpoint: StoredPersistenceCheckpoint
    ) -> (data: Data?, owner: DecisionSetPersistenceCheckpoint?) {
        guard let owner = checkpoint.previousOwner,
              let previous = persistenceCheckpoints[owner]
        else {
            return (checkpoint.previousData, nil)
        }
        switch previous.status {
            case .open:
                return (checkpoint.previousData, owner)
            case .cancelled:
                return resolvedRestoration(for: previous)
        }
    }
}

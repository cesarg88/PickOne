import Foundation

extension DefaultDecisionSetRepository {
    func beginPublicationTransaction() async throws -> DecisionSetPublicationTransaction {
        let transaction = DecisionSetPublicationTransaction()
        do {
            publicationTransactions[transaction] = try StagedDecisionSetPublication(
                committedData: store.readActive(),
                committedRevision: committedRevision,
                replacementData: nil
            )
            return transaction
        } catch {
            throw DecisionSetRepositoryError.storageFailed
        }
    }

    func stage(
        _ envelope: PersistedDecisionSet,
        in transaction: DecisionSetPublicationTransaction
    ) async throws {
        guard var publication = publicationTransactions[transaction] else {
            throw DecisionSetRepositoryError.storageFailed
        }
        publication.replacementData = try encode(envelope)
        publicationTransactions[transaction] = publication
    }

    func commit(_ transaction: DecisionSetPublicationTransaction) async throws {
        guard let publication = publicationTransactions[transaction],
              let replacementData = publication.replacementData
        else {
            throw DecisionSetRepositoryError.storageFailed
        }
        defer { publicationTransactions.removeValue(forKey: transaction) }
        do {
            guard publication.committedRevision == committedRevision,
                  try store.readActive() == publication.committedData
            else {
                throw DecisionSetRepositoryError.storageFailed
            }
            try store.replaceActive(with: replacementData)
            committedRevision += 1
        } catch let error as DecisionSetRepositoryError {
            throw error
        } catch {
            throw DecisionSetRepositoryError.storageFailed
        }
    }

    func discard(_ transaction: DecisionSetPublicationTransaction) async throws {
        guard publicationTransactions.removeValue(forKey: transaction) != nil else {
            throw DecisionSetRepositoryError.storageFailed
        }
    }
}

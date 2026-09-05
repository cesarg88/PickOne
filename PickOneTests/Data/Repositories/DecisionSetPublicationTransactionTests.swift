import Foundation
@testable import PickOne
import Testing

@Suite("Decision Set publication transactions")
struct DecisionSetPublicationTransactionTests {
    @Test("staged bytes stay invisible until commit and across repository recreation")
    func stagedBytesAreInvisibleUntilCommit() async throws {
        let original = try CoordinatorTestFixtures.envelope(currentMovieIDs: [10])
        let replacement = try CoordinatorTestFixtures.envelope(currentMovieIDs: [20])
        let store = InMemoryDecisionSetDataStore()
        let repository = DefaultDecisionSetRepository(store: store)
        try await repository.replace(original)
        let originalBytes = store.activeData

        let transaction = try await repository.beginPublicationTransaction()
        try await repository.stage(replacement, in: transaction)

        #expect(await repository.load() == .available(original))
        #expect(await DefaultDecisionSetRepository(store: store).load() == .available(original))
        #expect(store.activeData == originalBytes)
        #expect(await repository.inFlightPublicationCount == 1)

        try await repository.commit(transaction)

        #expect(await repository.load() == .available(replacement))
        #expect(await repository.inFlightPublicationCount == 0)
    }

    @Test("discard preserves exact committed bytes and releases transaction metadata")
    func discardPreservesCommittedBytes() async throws {
        let original = try CoordinatorTestFixtures.envelope(currentMovieIDs: [10])
        let replacement = try CoordinatorTestFixtures.envelope(currentMovieIDs: [20])
        let store = InMemoryDecisionSetDataStore()
        let repository = DefaultDecisionSetRepository(store: store)
        try await repository.replace(original)
        let originalBytes = store.activeData
        let transaction = try await repository.beginPublicationTransaction()
        try await repository.stage(replacement, in: transaction)

        try await repository.discard(transaction)

        #expect(store.activeData == originalBytes)
        #expect(await repository.load() == .available(original))
        #expect(await repository.inFlightPublicationCount == 0)
    }

    @Test("overlapping operations derive from committed state and cannot leak provisional history")
    func overlappingOperationsRemainIsolated() async throws {
        let original = try CoordinatorTestFixtures.envelope(currentMovieIDs: [10])
        let first = try CoordinatorTestFixtures.envelope(currentMovieIDs: [20])
        let second = try CoordinatorTestFixtures.envelope(currentMovieIDs: [30])
        let repository = DefaultDecisionSetRepository(store: InMemoryDecisionSetDataStore())
        try await repository.replace(original)

        let firstTransaction = try await repository.beginPublicationTransaction()
        try await repository.stage(first, in: firstTransaction)
        #expect(await repository.load() == .available(original))
        let secondTransaction = try await repository.beginPublicationTransaction()
        try await repository.stage(second, in: secondTransaction)

        try await repository.discard(firstTransaction)
        try await repository.commit(secondTransaction)

        #expect(await repository.load() == .available(second))
        #expect(await repository.inFlightPublicationCount == 0)
    }

    @Test("beginning a newer transaction does not invalidate older staged work")
    func newerTransactionDoesNotInvalidateOlderTransaction() async throws {
        let original = try CoordinatorTestFixtures.envelope(currentMovieIDs: [10])
        let first = try CoordinatorTestFixtures.envelope(currentMovieIDs: [20])
        let second = try CoordinatorTestFixtures.envelope(currentMovieIDs: [30])
        let repository = DefaultDecisionSetRepository(
            store: InMemoryDecisionSetDataStore()
        )
        try await repository.replace(original)
        let firstTransaction = try await repository.beginPublicationTransaction()
        try await repository.stage(first, in: firstTransaction)

        let secondTransaction = try await repository.beginPublicationTransaction()
        try await repository.stage(second, in: secondTransaction)
        try await repository.discard(secondTransaction)
        try await repository.commit(firstTransaction)

        #expect(await repository.load() == .available(first))
        #expect(await repository.inFlightPublicationCount == 0)
    }

    @Test("failed commit preserves prior bytes and finalizes transaction ownership")
    func failedCommitPreservesCommittedBytes() async throws {
        let original = try CoordinatorTestFixtures.envelope(currentMovieIDs: [10])
        let replacement = try CoordinatorTestFixtures.envelope(currentMovieIDs: [20])
        let store = InMemoryDecisionSetDataStore()
        let repository = DefaultDecisionSetRepository(store: store)
        try await repository.replace(original)
        let originalBytes = store.activeData
        let transaction = try await repository.beginPublicationTransaction()
        try await repository.stage(replacement, in: transaction)
        store.rejectActiveReplacements = true

        await #expect(throws: DecisionSetRepositoryError.storageFailed) {
            try await repository.commit(transaction)
        }

        #expect(store.activeData == originalBytes)
        #expect(await repository.inFlightPublicationCount == 0)
    }
}

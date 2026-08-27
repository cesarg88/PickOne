import Foundation
@testable import PickOne
import Synchronization
import Testing

@Suite("Decision Set persistence")
struct DecisionSetRepositoryTests {
    @Test("cycle signature is canonical and frozen")
    func stableCycleSignature() throws {
        let signer = StableDecisionCycleSigner()
        let first = DecisionCycleIdentity(
            engineModelVersion: .p1Model,
            profile: profile(
                services: [.disneyPlus, .netflix],
                reactions: [155: .loveIt, 238: .didNotLikeIt]
            )
        )
        let reordered = DecisionCycleIdentity(
            engineModelVersion: .p1Model,
            profile: profile(
                services: [.netflix, .disneyPlus],
                reactions: [238: .didNotLikeIt, 155: .loveIt]
            )
        )

        let signature = try signer.signature(for: first)
        let reorderedSignature = try signer.signature(for: reordered)

        #expect(signature == reorderedSignature)
        #expect(signature.rawValue == "9e12e6ef19d6cfcdc5ceccc9121d0b83512aae33417d32607e058cedde596f28")
    }

    @Test("every immutable cycle input changes the signature")
    func cycleResetInputs() throws {
        let signer = StableDecisionCycleSigner()
        let baselineProfile = profile(
            services: [.netflix],
            reactions: [155: .loveIt]
        )
        let baseline = try signer.signature(
            for: DecisionCycleIdentity(engineModelVersion: .p1Model, profile: baselineProfile)
        )
        let changedProfileVersion = ViewerProfile(
            profileSchemaVersion: 2,
            catalogID: baselineProfile.catalogID,
            region: baselineProfile.region,
            selectedServices: baselineProfile.selectedServices,
            reactions: baselineProfile.reactions
        )
        let changedCatalog = ViewerProfile(
            profileSchemaVersion: 1,
            catalogID: CalibrationCatalogID(rawValue: "other-catalog"),
            region: baselineProfile.region,
            selectedServices: baselineProfile.selectedServices,
            reactions: baselineProfile.reactions
        )
        let changedRegion = ViewerProfile(
            profileSchemaVersion: 1,
            catalogID: baselineProfile.catalogID,
            region: ViewingRegion(code: "PT"),
            selectedServices: baselineProfile.selectedServices,
            reactions: baselineProfile.reactions
        )

        #expect(try signer
            .signature(for: .init(engineModelVersion: .p1Model, profile: changedProfileVersion)) != baseline)
        #expect(try signer.signature(for: .init(engineModelVersion: .p1Model, profile: changedCatalog)) != baseline)
        #expect(try signer.signature(for: .init(engineModelVersion: .p1Model, profile: changedRegion)) != baseline)
        #expect(
            try signer.signature(
                for: .init(
                    engineModelVersion: .p1Model,
                    profile: profile(services: [.disneyPlus], reactions: baselineProfile.reactions)
                )
            ) != baseline
        )
        #expect(
            try signer.signature(
                for: .init(
                    engineModelVersion: .p1Model,
                    profile: profile(services: [.netflix], reactions: [155: .likeIt])
                )
            ) != baseline
        )
    }

    @Test("presenting and repairing append shown history without resetting the cycle")
    func shownHistory() throws {
        let signature = try #require(DecisionCycleSignature(rawValue: String(repeating: "a", count: 64)))
        let id = UUID()
        let initial = try DecisionCycle(id: id, identitySignature: signature)
        let firstSet = try initial.presenting(movieIDs: [10, 20, 30])
        let repaired = try firstSet.presenting(movieIDs: [40])

        #expect(repaired.id == id)
        #expect(repaired.identitySignature == signature)
        #expect(repaired.shownMovieIDs == [10, 20, 30, 40])
    }

    @Test("a current recommendation must already be recorded as shown")
    func recommendationRequiresShownHistory() throws {
        let cycle = try DecisionCycle(
            id: UUID(),
            identitySignature: signature(),
            shownMovieIDs: []
        )

        #expect(throws: DecisionSetValidationError.invalidShownHistory) {
            _ = try PersistedDecisionSet(
                id: UUID(),
                generatedAt: Date(),
                engineModelVersion: .p1Model,
                cycle: cycle,
                sourceViewerStateSnapshotID: ViewerStateSnapshotID(rawValue: UUID()),
                region: .spain,
                selectedProviderIDs: [8],
                recommendations: [recommendation(movieID: 10, role: .safeChoice)]
            )
        }
    }

    @Test("persisted Domain recommendations reject semantically invalid evidence")
    func domainEvidenceValidation() {
        let drama = DecisionGenre(id: 18, name: "Drama")
        let invalidEvidence: [(DecisionRole, RecommendationEvidence)] = [
            (
                .stretchChoice,
                RecommendationEvidence(
                    primary: .positiveAnchor(
                        PositiveAnchorEvidence(
                            movieID: 155,
                            movieTitle: "Anchor",
                            reaction: .loved,
                            anchorGenres: [],
                            sharedGenres: [],
                            eraMatch: nil
                        )
                    ),
                    diversity: nil
                )
            ),
            (
                .stretchChoice,
                RecommendationEvidence(
                    primary: .positiveGenreAffinity(
                        PositiveAffinityEvidence(genres: [], era: DecisionDecade(year: 2020))
                    ),
                    diversity: nil
                )
            ),
            (
                .safeChoice,
                RecommendationEvidence(primary: .sparseQuality, diversity: .diverseDirection)
            ),
            (
                .stretchChoice,
                RecommendationEvidence(
                    primary: .positiveAnchor(
                        PositiveAnchorEvidence(
                            movieID: 155,
                            movieTitle: "Anchor",
                            reaction: .liked,
                            anchorGenres: [drama],
                            sharedGenres: [drama],
                            eraMatch: .adjacentDecade(
                                candidate: DecisionDecade(year: 2020),
                                anchor: DecisionDecade(year: 1990)
                            )
                        )
                    ),
                    diversity: nil
                )
            ),
            (
                .stretchChoice,
                RecommendationEvidence(
                    primary: .positiveAnchor(
                        PositiveAnchorEvidence(
                            movieID: 155,
                            movieTitle: "Anchor",
                            reaction: .liked,
                            anchorGenres: [],
                            sharedGenres: [],
                            eraMatch: .sameDecade(DecisionDecade(year: -1))
                        )
                    ),
                    diversity: nil
                )
            ),
            (
                .stretchChoice,
                RecommendationEvidence(
                    primary: .watchlistIntent(
                        match: .positiveAffinity(PositiveAffinityEvidence(genres: [], era: nil))
                    ),
                    diversity: nil
                )
            ),
        ]

        for (role, evidence) in invalidEvidence {
            #expect(throws: DecisionSetValidationError.invalidEvidence) {
                _ = try recommendation(movieID: 10, role: role, evidence: evidence)
            }
        }
    }

    @Test("versioned envelope survives repository recreation")
    func relaunchRoundTrip() async throws {
        let store = InMemoryDecisionSetDataStore()
        let expected = try decisionSet()
        try await DefaultDecisionSetRepository(store: store).replace(expected)

        let decoded = try JSONDecisionSetEnvelopeCoder().decodeEnvelope(
            from: #require(store.activeData)
        )
        guard case let .currentV2(dto) = decoded else {
            Issue.record("Expected production persistence to use Decision Set v2")
            return
        }

        let relaunched = DefaultDecisionSetRepository(store: store)

        #expect(await relaunched.load() == .available(expected))
        #expect(dto.sourceViewerStateSnapshotID == expected.sourceViewerStateSnapshotID.rawValue)
        #expect(store.activeReplacementCount == 1)
    }

    @Test("an honest empty Decision Set round-trips")
    func emptyRoundTrip() async throws {
        let store = InMemoryDecisionSetDataStore()
        let empty = try decisionSet(recommendations: [])
        let repository = DefaultDecisionSetRepository(store: store)

        try await repository.replace(empty)

        #expect(await repository.load() == .available(empty))
    }

    @Test("encoding failure preserves the previous active envelope")
    func encodingFailurePreservesPreviousEnvelope() async throws {
        let store = InMemoryDecisionSetDataStore()
        let repository = DefaultDecisionSetRepository(store: store)
        try await repository.replace(decisionSet())
        let previous = store.activeData
        let failing = DefaultDecisionSetRepository(
            store: store,
            coder: FailingDecisionSetEncoder()
        )

        await #expect(throws: DecisionSetRepositoryError.encodingFailed) {
            try await failing.replace(decisionSet(recommendations: []))
        }
        #expect(store.activeData == previous)
        #expect(store.activeReplacementCount == 1)
    }

    @Test("storage failure preserves the previous active envelope")
    func storageFailurePreservesPreviousEnvelope() async throws {
        let store = InMemoryDecisionSetDataStore()
        let repository = DefaultDecisionSetRepository(store: store)
        try await repository.replace(decisionSet())
        let previous = store.activeData
        store.rejectActiveReplacements = true

        await #expect(throws: DecisionSetRepositoryError.storageFailed) {
            try await repository.replace(decisionSet(recommendations: []))
        }
        #expect(store.activeData == previous)
    }

    @Test("corrupt bytes are quarantined and retained after recovery replacement")
    func corruptRecovery() async throws {
        let corrupt = Data("not-json".utf8)
        let store = InMemoryDecisionSetDataStore(activeData: corrupt)
        let repository = DefaultDecisionSetRepository(store: store)

        #expect(await repository.load() == .recovery(.corruptData))
        #expect(store.activeData == corrupt)
        #expect(store.quarantineData == corrupt)

        let replacement = try decisionSet()
        try await repository.replace(replacement)

        #expect(await repository.load() == .available(replacement))
        #expect(store.quarantineData == corrupt)
    }

    @Test("failed active replacement preserves corrupt and quarantined recovery bytes")
    func recoveryReplacementFailure() async throws {
        let corrupt = Data("not-json".utf8)
        let store = InMemoryDecisionSetDataStore(activeData: corrupt)
        let repository = DefaultDecisionSetRepository(store: store)

        #expect(await repository.load() == .recovery(.corruptData))
        #expect(store.quarantineData == corrupt)
        store.rejectActiveReplacements = true

        await #expect(throws: DecisionSetRepositoryError.storageFailed) {
            try await repository.replace(decisionSet())
        }
        #expect(store.activeData == corrupt)
        #expect(store.quarantineData == corrupt)
    }

    @Test("unsupported schema bytes are quarantined without migration guesses")
    func unsupportedRecovery() async {
        for version in [0, 3] {
            let bytes = Data(#"{"envelopeSchemaVersion":\#(version)}"#.utf8)
            let store = InMemoryDecisionSetDataStore(activeData: bytes)
            let repository = DefaultDecisionSetRepository(store: store)

            #expect(await repository.load() == .recovery(.unsupportedVersion))
            #expect(store.activeData == bytes)
            #expect(store.quarantineData == bytes)
        }
    }

    @Test("recovery cannot proceed when diagnostic quarantine fails")
    func quarantineFailure() async {
        let bytes = Data("not-json".utf8)
        let store = InMemoryDecisionSetDataStore(activeData: bytes)
        store.rejectQuarantineReplacements = true

        #expect(
            await DefaultDecisionSetRepository(store: store).load()
                == .recovery(.quarantineFailed)
        )
        #expect(store.activeData == bytes)
        #expect(store.quarantineData == nil)
    }

    @Test("active read failure remains distinct from absent storage")
    func readFailure() async {
        let store = InMemoryDecisionSetDataStore(activeData: Data("preserve".utf8))
        store.rejectReads = true

        #expect(
            await DefaultDecisionSetRepository(store: store).load()
                == .recovery(.loadFailed)
        )
    }
}

private extension DecisionSetRepositoryTests {
    func profile(
        services: [PilotStreamingService],
        reactions: [Int: CalibrationReaction]
    ) -> ViewerProfile {
        ViewerProfile(
            profileSchemaVersion: 1,
            catalogID: .spainHouseholdV1,
            region: .spain,
            selectedServices: services,
            reactions: reactions
        )
    }

    func signature() throws -> DecisionCycleSignature {
        try #require(DecisionCycleSignature(rawValue: String(repeating: "a", count: 64)))
    }

    func decisionSet(
        recommendations: [PersistedDecisionRecommendation]? = nil
    ) throws -> PersistedDecisionSet {
        let items = try recommendations ?? [
            recommendation(movieID: 10, role: .safeChoice),
            recommendation(movieID: 20, role: .stretchChoice),
            recommendation(movieID: 30, role: .discoveryChoice),
        ]
        let cycle = try DecisionCycle(
            id: #require(UUID(uuidString: "10000000-0000-0000-0000-000000000001")),
            identitySignature: signature(),
            shownMovieIDs: [10, 20, 30, 99]
        )
        return try PersistedDecisionSet(
            id: #require(UUID(uuidString: "20000000-0000-0000-0000-000000000002")),
            generatedAt: Date(timeIntervalSince1970: 1_700_000_000.125),
            engineModelVersion: .p1Model,
            cycle: cycle,
            sourceViewerStateSnapshotID: ViewerStateSnapshotID(
                rawValue: #require(UUID(uuidString: "30000000-0000-0000-0000-000000000003"))
            ),
            region: .spain,
            selectedProviderIDs: [337, 8],
            recommendations: items
        )
    }

    func recommendation(
        movieID: Int,
        role: DecisionRole,
        evidence suppliedEvidence: RecommendationEvidence? = nil
    ) throws -> PersistedDecisionRecommendation {
        let genre = switch role {
            case .safeChoice: DecisionGenre(id: 18, name: "Drama")
            case .stretchChoice: DecisionGenre(id: 35, name: "Comedy")
            case .discoveryChoice: DecisionGenre(id: 53, name: "Thriller")
        }
        let defaultEvidence: RecommendationEvidence = switch role {
            case .safeChoice:
                RecommendationEvidence(
                    primary: .watchlistIntent(
                        match: .positiveAnchor(
                            PositiveAnchorEvidence(
                                movieID: 155,
                                movieTitle: "El caballero oscuro",
                                reaction: .loved,
                                anchorGenres: [genre],
                                sharedGenres: [genre],
                                eraMatch: .adjacentDecade(
                                    candidate: DecisionDecade(year: 2020),
                                    anchor: DecisionDecade(year: 2010)
                                )
                            )
                        )
                    ),
                    diversity: nil
                )
            case .stretchChoice:
                RecommendationEvidence(
                    primary: .positiveGenreAffinity(
                        PositiveAffinityEvidence(
                            genres: [genre],
                            era: DecisionDecade(year: 2020)
                        )
                    ),
                    diversity: .diverseDirection
                )
            case .discoveryChoice:
                RecommendationEvidence(primary: .sparseQuality, diversity: nil)
        }
        return try PersistedDecisionRecommendation(
            role: role,
            evidence: suppliedEvidence ?? defaultEvidence,
            display: DecisionDisplaySnapshot(
                movieID: movieID,
                localizedTitle: "Movie \(movieID)",
                posterPath: "/poster.jpg",
                backdropPath: "/backdrop.jpg",
                runtimeMinutes: 120,
                releaseYear: 2024,
                genres: [genre]
            ),
            availability: DecisionAvailabilitySnapshot(
                matchingProviders: [
                    DecisionProviderSnapshot(
                        providerID: 8,
                        name: "Netflix",
                        logoPath: "/netflix.jpg",
                        productOrder: 1
                    ),
                ],
                verifiedAt: Date(timeIntervalSince1970: 1_699_999_000.5),
                regionalWatchURL: URL(string: "https://www.themoviedb.org/movie/\(movieID)/watch")
            )
        )
    }
}

final class InMemoryDecisionSetDataStore: DecisionSetDataStore {
    private struct State: Sendable {
        var activeData: Data?
        var quarantineData: Data?
        var activeReplacementCount = 0
        var rejectReads = false
        var rejectActiveReplacements = false
        var rejectQuarantineReplacements = false
    }

    private let state: Mutex<State>

    init(activeData: Data? = nil) {
        state = Mutex(State(activeData: activeData))
    }

    var activeData: Data? {
        state.withLock { $0.activeData }
    }

    var quarantineData: Data? {
        state.withLock { $0.quarantineData }
    }

    var activeReplacementCount: Int {
        state.withLock { $0.activeReplacementCount }
    }

    var rejectReads: Bool {
        get { state.withLock { $0.rejectReads } }
        set { state.withLock { $0.rejectReads = newValue } }
    }

    var rejectActiveReplacements: Bool {
        get { state.withLock { $0.rejectActiveReplacements } }
        set { state.withLock { $0.rejectActiveReplacements = newValue } }
    }

    var rejectQuarantineReplacements: Bool {
        get { state.withLock { $0.rejectQuarantineReplacements } }
        set { state.withLock { $0.rejectQuarantineReplacements = newValue } }
    }

    func readActive() throws -> Data? {
        try state.withLock {
            if $0.rejectReads { throw TestStoreError.rejected }
            return $0.activeData
        }
    }

    func replaceActive(with data: Data) throws {
        try state.withLock {
            if $0.rejectActiveReplacements { throw TestStoreError.rejected }
            $0.activeData = data
            $0.activeReplacementCount += 1
        }
    }

    func readQuarantine() throws -> Data? {
        state.withLock { $0.quarantineData }
    }

    func replaceQuarantine(with data: Data) throws {
        try state.withLock {
            if $0.rejectQuarantineReplacements { throw TestStoreError.rejected }
            $0.quarantineData = data
        }
    }
}

private struct FailingDecisionSetEncoder: DecisionSetEnvelopeCoding {
    func decodeEnvelope(from data: Data) throws -> DecodedDecisionSetEnvelopeDTO {
        try JSONDecisionSetEnvelopeCoder().decodeEnvelope(from: data)
    }

    func encodeEnvelope(_: DecisionSetEnvelopeV2DTO) throws -> Data {
        throw TestStoreError.rejected
    }
}

private enum TestStoreError: Error {
    case rejected
}

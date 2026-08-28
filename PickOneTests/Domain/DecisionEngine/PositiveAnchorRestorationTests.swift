import Foundation
@testable import PickOne
import Testing

@Suite("Positive anchor restoration")
struct PositiveAnchorRestorationTests {
    @Test("load regenerates unreadable labels without clearing shown history")
    func loadRepairsUnreadableLabelsAndPreservesHistory() async throws {
        let profile = profile(reaction: .loveIt)
        let envelope = try legacyUnnamedEnvelope(profile: profile)
        let decisionSets = CoordinatorDecisionSetRepository(loadResult: .available(envelope))
        let sut = try CoordinatorTestFixtures.makeCoordinator(
            profile: profile,
            candidateRepository: CoordinatorCandidateRepository(),
            availabilityRepository: CoordinatorAvailabilityRepository(
                evidenceByMovieID: [10: CoordinatorTestFixtures.evidence(10)]
            ),
            decisionSetRepository: decisionSets,
            movieRepository: CoordinatorMovieRepository(movies: [
                10: CoordinatorTestFixtures.movie(10),
                155: CoordinatorTestFixtures.movie(155),
            ]),
            viewerMovieStates: [reactionState(.loveIt)]
        )

        let result = try await sut.load()
        guard case let .usable(snapshot) = result,
              case let .positiveAnchor(anchor) = snapshot.decisionSet
              .recommendations.first?.evidence.primary
        else {
            Issue.record("Expected repaired readable anchor evidence")
            return
        }

        #expect(anchor.sharedGenres.map(\.name) == ["Drama"])
        #expect(snapshot.decisionSet.cycle.id == envelope.cycle.id)
        #expect(snapshot.decisionSet.cycle.shownMovieIDs == [10, 99])
        #expect(await decisionSets.replacements == [snapshot.decisionSet])
    }

    @Test("load repairs legacy anchor evidence before restoring it")
    func loadRepairsLegacyAnchorEvidence() async throws {
        let profile = profile(reaction: .loveIt)
        let envelope = try envelope(
            profile: profile,
            capturedReaction: .loved,
            anchorGenres: nil
        )
        let decisionSets = CoordinatorDecisionSetRepository(loadResult: .available(envelope))
        let sut = try CoordinatorTestFixtures.makeCoordinator(
            profile: profile,
            candidateRepository: CoordinatorCandidateRepository(),
            availabilityRepository: CoordinatorAvailabilityRepository(
                evidenceByMovieID: [10: CoordinatorTestFixtures.evidence(10)]
            ),
            decisionSetRepository: decisionSets,
            movieRepository: CoordinatorMovieRepository(movies: [
                10: CoordinatorTestFixtures.movie(10),
                155: CoordinatorTestFixtures.movie(155),
            ]),
            viewerMovieStates: [reactionState(.loveIt)]
        )

        #expect(try ThreeForTonightSnapshotFactory.safeRetainedSnapshot(
            envelope,
            trustedState: trustedState(profile: profile, reaction: .loveIt)
        )?.decisionSet.recommendations.isEmpty == true)

        let result = try await sut.load()
        guard case let .usable(snapshot) = result,
              case let .positiveAnchor(anchor) = snapshot.decisionSet
              .recommendations.first?.evidence.primary
        else {
            Issue.record("Expected repaired, requalified anchor evidence")
            return
        }

        #expect(snapshot.decisionSet.recommendations.map(\.display.movieID) == [10])
        #expect(anchor.movieID == 155)
        #expect(anchor.anchorGenres?.map(\.id) == [18])
        #expect(anchor.sharedGenres.map(\.id) == [18])
        #expect(await decisionSets.replacements == [snapshot.decisionSet])
    }

    @Test("a changed current reaction makes persisted anchor evidence unsafe")
    func changedAnchorReactionRequiresRepair() throws {
        let profile = profile(reaction: .likeIt)
        let envelope = try envelope(
            profile: profile,
            capturedReaction: .loved,
            anchorGenres: [DecisionGenre(id: 18, name: "Drama")]
        )

        #expect(try ThreeForTonightSnapshotFactory.localRepairMovieIDs(
            envelope: envelope,
            trustedState: trustedState(profile: profile, reaction: .likeIt)
        ) == [10])
        #expect(try ThreeForTonightSnapshotFactory.safeRetainedSnapshot(
            envelope,
            trustedState: trustedState(profile: profile, reaction: .likeIt)
        )?.decisionSet.recommendations.isEmpty == true)
    }

    private func profile(reaction: CalibrationReaction) -> ViewerProfile {
        ViewerProfile(
            profileSchemaVersion: ViewerProfile.currentSchemaVersion,
            catalogID: .spainHouseholdV1,
            region: .spain,
            selectedServices: [.netflix],
            reactions: [155: reaction]
        )
    }

    private func trustedState(
        profile: ViewerProfile,
        reaction: MovieReaction
    ) throws -> TrustedDecisionState {
        try TrustedDecisionState(
            profile: profile,
            viewerMovieState: ViewerMovieStateSnapshot(
                id: CoordinatorViewerMovieStateRepository.defaultSnapshotID,
                states: [reactionState(reaction)]
            )
        )
    }

    private func reactionState(_ reaction: MovieReaction) throws -> ViewerMovieState {
        try ViewerMovieState(
            movieID: 155,
            displayMetadata: MovieFeedbackMetadata(
                title: "Movie 155",
                releaseYear: 2024,
                posterPath: nil
            ),
            watchState: .watched,
            preference: .reaction(reaction),
            watchlistIntent: nil,
            stateChangedAt: .distantPast
        )
    }

    private func envelope(
        profile: ViewerProfile,
        capturedReaction: PositiveAnchorReaction,
        anchorGenres: [DecisionGenre]?
    ) throws -> PersistedDecisionSet {
        let signature = try StableDecisionCycleSigner().signature(for: DecisionCycleIdentity(
            engineModelVersion: .p1Model,
            profile: profile
        ))
        let drama = DecisionGenre(id: 18, name: "Drama")
        let recommendation = try PersistedDecisionRecommendation(
            role: .safeChoice,
            evidence: RecommendationEvidence(
                primary: .positiveAnchor(PositiveAnchorEvidence(
                    movieID: 155,
                    movieTitle: "Movie 155",
                    reaction: capturedReaction,
                    anchorGenres: anchorGenres,
                    sharedGenres: [drama],
                    eraMatch: nil
                )),
                diversity: nil
            ),
            display: DecisionDisplaySnapshot(
                movieID: 10,
                localizedTitle: "Movie 10",
                posterPath: nil,
                backdropPath: nil,
                runtimeMinutes: 100,
                releaseYear: 2024,
                genres: [drama]
            ),
            availability: DecisionAvailabilitySnapshot(
                matchingProviders: [DecisionProviderSnapshot(
                    providerID: PilotStreamingService.netflix.providerID,
                    name: PilotStreamingService.netflix.name,
                    logoPath: "/netflix.jpg",
                    productOrder: PilotStreamingService.netflix.productOrder
                )],
                verifiedAt: Date(timeIntervalSince1970: 2000),
                regionalWatchURL: URL(string: "https://www.themoviedb.org/movie/10/watch")
            )
        )
        return try PersistedDecisionSet(
            id: UUID(),
            generatedAt: Date(timeIntervalSince1970: 1000),
            engineModelVersion: .p1Model,
            cycle: DecisionCycle(
                id: UUID(),
                identitySignature: signature,
                shownMovieIDs: [10]
            ),
            sourceViewerStateSnapshotID: CoordinatorViewerMovieStateRepository.defaultSnapshotID,
            region: profile.region,
            selectedProviderIDs: profile.selectedServices.map(\.providerID),
            recommendations: [recommendation]
        )
    }

    private func legacyUnnamedEnvelope(
        profile: ViewerProfile
    ) throws -> PersistedDecisionSet {
        let signature = try StableDecisionCycleSigner().signature(for: DecisionCycleIdentity(
            engineModelVersion: .p1Model,
            profile: profile
        ))
        let unnamedDrama = DecisionGenre(id: 18)
        let recommendation = try PersistedDecisionRecommendation.restoringLegacyEvidence(
            role: .safeChoice,
            evidence: RecommendationEvidence(
                primary: .positiveAnchor(PositiveAnchorEvidence(
                    movieID: 155,
                    movieTitle: "Movie 155",
                    reaction: .loved,
                    anchorGenres: [unnamedDrama],
                    sharedGenres: [unnamedDrama],
                    eraMatch: nil
                )),
                diversity: nil
            ),
            display: DecisionDisplaySnapshot(
                movieID: 10,
                localizedTitle: "Movie 10",
                posterPath: nil,
                backdropPath: nil,
                runtimeMinutes: 100,
                releaseYear: 2024,
                genres: [unnamedDrama]
            ),
            availability: DecisionAvailabilitySnapshot(
                matchingProviders: [DecisionProviderSnapshot(
                    providerID: PilotStreamingService.netflix.providerID,
                    name: PilotStreamingService.netflix.name,
                    logoPath: "/netflix.jpg",
                    productOrder: PilotStreamingService.netflix.productOrder
                )],
                verifiedAt: Date(timeIntervalSince1970: 2000),
                regionalWatchURL: URL(string: "https://www.themoviedb.org/movie/10/watch")
            )
        )
        return try PersistedDecisionSet(
            id: UUID(),
            generatedAt: Date(timeIntervalSince1970: 1000),
            engineModelVersion: .p1Model,
            cycle: DecisionCycle(
                id: UUID(),
                identitySignature: signature,
                shownMovieIDs: [10, 99]
            ),
            sourceViewerStateSnapshotID: CoordinatorViewerMovieStateRepository.defaultSnapshotID,
            region: profile.region,
            selectedProviderIDs: profile.selectedServices.map(\.providerID),
            recommendations: [recommendation]
        )
    }
}

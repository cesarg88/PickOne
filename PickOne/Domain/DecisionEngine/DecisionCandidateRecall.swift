import Foundation

struct DecisionCandidateContext: Equatable, Sendable {
    let region: ViewingRegion
    let selectedProviderIDs: [Int]

    init?(region: ViewingRegion, selectedProviderIDs: [Int]) {
        let normalizedProviderIDs = Array(Set(selectedProviderIDs)).sorted()
        let allowlistedProviderIDs = Set(
            PilotStreamingService.allowlist.map(\.providerID)
        )
        guard
            region == .spain,
            !normalizedProviderIDs.isEmpty,
            normalizedProviderIDs.allSatisfy(allowlistedProviderIDs.contains)
        else {
            return nil
        }

        self.region = region
        self.selectedProviderIDs = normalizedProviderIDs
    }
}

struct DecisionCandidateSeed: Equatable, Sendable {
    let movieID: Int
    let localizedTitle: String
    let posterPath: String?
    let backdropPath: String?
    let genres: Set<DecisionGenre>
    let releaseYear: Int?
    let voteAverage: Double?
    let voteCount: Int?

    init?(
        movieID: Int,
        localizedTitle: String,
        posterPath: String?,
        backdropPath: String?,
        genres: Set<DecisionGenre>,
        releaseYear: Int?,
        voteAverage: Double?,
        voteCount: Int?
    ) {
        let normalizedTitle = localizedTitle.trimmingCharacters(
            in: .whitespacesAndNewlines
        )
        guard movieID > 0, !normalizedTitle.isEmpty else {
            return nil
        }

        self.movieID = movieID
        self.localizedTitle = normalizedTitle
        self.posterPath = Self.normalizedPath(posterPath)
        self.backdropPath = Self.normalizedPath(backdropPath)
        self.genres = genres
        self.releaseYear = releaseYear.flatMap { $0 > 0 ? $0 : nil }
        self.voteAverage = voteAverage.flatMap {
            $0.isFinite && (0 ... 10).contains($0) ? $0 : nil
        }
        self.voteCount = voteCount.flatMap { $0 >= 0 ? $0 : nil }
    }

    private static func normalizedPath(_ path: String?) -> String? {
        let normalized = path?.trimmingCharacters(in: .whitespacesAndNewlines)
        return normalized?.isEmpty == false ? normalized : nil
    }
}

protocol DecisionCandidateRepository: Sendable {
    func discoverPage(
        _ page: Int,
        context: DecisionCandidateContext
    ) async throws -> [DecisionCandidateSeed]
}

struct RecallDecisionCandidates: Sendable {
    private static let candidatesPerPageLimit = 20
    private let repository: any DecisionCandidateRepository

    init(repository: any DecisionCandidateRepository) {
        self.repository = repository
    }

    func execute(context: DecisionCandidateContext) async throws -> [DecisionCandidateSeed] {
        try await execute(
            pages: RecommendationSearchPolicy.accepted.normalPageRange,
            context: context
        )
    }

    func execute(
        pages: ClosedRange<Int>,
        context: DecisionCandidateContext
    ) async throws -> [DecisionCandidateSeed] {
        try await executeBatch(pages: pages, context: context).candidates
    }

    func executeBatch(
        pages: ClosedRange<Int>,
        context: DecisionCandidateContext
    ) async throws -> RecalledDecisionCandidateBatch {
        var seenMovieIDs = Set<Int>()
        var candidates: [DecisionCandidateSeed] = []
        var requestedPageCount = 0

        for page in pages {
            try Task.checkCancellation()
            RecommendationDiagnosticsContext.operation?.recordDiscoverRequest()
            let pageCandidates = try await repository.discoverPage(
                page,
                context: context
            )
            RecommendationDiagnosticsContext.operation?.recordRecalledCandidates(
                pageCandidates.map(\.movieID)
            )
            requestedPageCount += 1
            try Task.checkCancellation()
            guard !pageCandidates.isEmpty else {
                return RecalledDecisionCandidateBatch(
                    candidates: candidates,
                    requestedPageCount: requestedPageCount,
                    reachedEmptyPage: true
                )
            }

            for candidate in pageCandidates.prefix(Self.candidatesPerPageLimit)
                where seenMovieIDs.insert(candidate.movieID).inserted
            {
                candidates.append(candidate)
            }
        }

        return RecalledDecisionCandidateBatch(
            candidates: candidates,
            requestedPageCount: requestedPageCount,
            reachedEmptyPage: false
        )
    }
}

struct RecalledDecisionCandidateBatch: Equatable, Sendable {
    let candidates: [DecisionCandidateSeed]
    let requestedPageCount: Int
    let reachedEmptyPage: Bool
}

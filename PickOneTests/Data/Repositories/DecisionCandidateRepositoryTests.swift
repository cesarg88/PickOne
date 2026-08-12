@testable import PickOne
import Testing

@Suite("Decision candidate repository tests")
struct DecisionCandidateRepositoryTests {
    @Test("mapping keeps only accepted P1 and display metadata")
    func mapsAcceptedMetadataWithoutPopularity() async throws {
        let first = item(id: 42, popularity: 999)
        let second = item(id: 42, popularity: 1)
        let context = try testContext()

        let highPopularity = try await DefaultDecisionCandidateRepository(
            client: CandidateClientStub(results: [first])
        ).discoverPage(1, context: context)
        let lowPopularity = try await DefaultDecisionCandidateRepository(
            client: CandidateClientStub(results: [second])
        ).discoverPage(1, context: context)

        #expect(highPopularity == lowPopularity)
        let candidate = try #require(highPopularity.first)
        #expect(candidate.movieID == 42)
        #expect(candidate.localizedTitle == "Título localizado")
        #expect(candidate.posterPath == "/poster.jpg")
        #expect(candidate.backdropPath == "/backdrop.jpg")
        #expect(candidate.genres == [DecisionGenre(id: 18), DecisionGenre(id: 53)])
        #expect(candidate.releaseYear == 2024)
        #expect(candidate.voteAverage == 7.8)
        #expect(candidate.voteCount == 1200)
    }

    @Test("malformed identity is omitted while missing optional metadata stays valid")
    func rejectsMalformedIdentity() async throws {
        let client = CandidateClientStub(results: [
            item(id: 0),
            item(id: 2, title: "   "),
            item(
                id: 3,
                title: "Válida",
                genreIds: nil,
                releaseDate: nil,
                voteAverage: nil,
                voteCount: nil
            ),
        ])
        let sut = DefaultDecisionCandidateRepository(client: client)

        let candidates = try await sut.discoverPage(1, context: testContext())

        #expect(candidates.map(\.movieID) == [3])
        #expect(candidates.first?.genres.isEmpty == true)
        #expect(candidates.first?.releaseYear == nil)
    }

    @Test("a mismatched response page fails instead of corrupting stable ordering")
    func rejectsMismatchedPage() async throws {
        let sut = DefaultDecisionCandidateRepository(
            client: CandidateClientStub(responsePage: 2, results: [])
        )

        await #expect(throws: DecisionCandidateRepositoryError.unexpectedPage(
            expected: 1,
            actual: 2
        )) {
            try await sut.discoverPage(1, context: testContext())
        }
    }

    private func item(
        id: Int,
        title: String = "Título localizado",
        genreIds: [Int]? = [18, 53],
        releaseDate: String? = "2024-06-10",
        voteAverage: Double? = 7.8,
        voteCount: Int? = 1200,
        popularity: Double? = 50
    ) -> DecisionCandidateItemDTO {
        DecisionCandidateItemDTO(
            backdropPath: "/backdrop.jpg",
            genreIds: genreIds,
            id: id,
            popularity: popularity,
            posterPath: "/poster.jpg",
            releaseDate: releaseDate,
            title: title,
            voteAverage: voteAverage,
            voteCount: voteCount
        )
    }
}

private struct CandidateClientStub: DecisionCandidateClient {
    let responsePage: Int?
    let results: [DecisionCandidateItemDTO]

    init(
        responsePage: Int? = nil,
        results: [DecisionCandidateItemDTO]
    ) {
        self.responsePage = responsePage
        self.results = results
    }

    func discoverPage(
        _ page: Int,
        context: DecisionCandidateContext
    ) async throws -> DecisionCandidatePageDTO {
        DecisionCandidatePageDTO(page: responsePage ?? page, results: results)
    }
}

private func testContext() throws -> DecisionCandidateContext {
    try #require(DecisionCandidateContext(
        region: .spain,
        selectedProviderIDs: [8]
    ))
}

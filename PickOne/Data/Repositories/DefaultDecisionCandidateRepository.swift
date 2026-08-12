enum DecisionCandidateRepositoryError: Error, Equatable, Sendable {
    case unexpectedPage(expected: Int, actual: Int)
}

struct DefaultDecisionCandidateRepository: DecisionCandidateRepository {
    private let client: any DecisionCandidateClient

    init(client: any DecisionCandidateClient) {
        self.client = client
    }

    func discoverPage(
        _ page: Int,
        context: DecisionCandidateContext
    ) async throws -> [DecisionCandidateSeed] {
        try Task.checkCancellation()
        let response = try await client.discoverPage(page, context: context)
        try Task.checkCancellation()
        guard response.page == page else {
            throw DecisionCandidateRepositoryError.unexpectedPage(
                expected: page,
                actual: response.page
            )
        }
        return response.results.compactMap(DecisionCandidateMapper.map)
    }
}

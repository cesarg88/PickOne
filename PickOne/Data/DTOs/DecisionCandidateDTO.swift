struct DecisionCandidatePageDTO: Decodable, Sendable {
    let page: Int
    let results: [DecisionCandidateItemDTO]
}

struct DecisionCandidateItemDTO: Decodable, Sendable {
    let backdropPath: String?
    let genreIds: [Int]?
    let id: Int
    let popularity: Double?
    let posterPath: String?
    let releaseDate: String?
    let title: String
    let voteAverage: Double?
    let voteCount: Int?
}

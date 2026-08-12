enum DecisionCandidateMapper {
    static func map(_ dto: DecisionCandidateItemDTO) -> DecisionCandidateSeed? {
        DecisionCandidateSeed(
            movieID: dto.id,
            localizedTitle: dto.title,
            posterPath: dto.posterPath,
            backdropPath: dto.backdropPath,
            genres: Set(
                (dto.genreIds ?? [])
                    .filter { $0 > 0 }
                    .map { DecisionGenre(id: $0) }
            ),
            releaseYear: releaseYear(from: dto.releaseDate),
            voteAverage: dto.voteAverage,
            voteCount: dto.voteCount
        )
    }

    private static func releaseYear(from releaseDate: String?) -> Int? {
        guard
            let releaseDate,
            let year = Int(releaseDate.prefix(4)),
            year > 0
        else {
            return nil
        }
        return year
    }
}

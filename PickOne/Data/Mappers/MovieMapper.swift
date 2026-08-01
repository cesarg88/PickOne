import Foundation

enum MovieMapper {
    static func mapSummary(from dto: MovieListItemDTO) -> MovieSummary {
        MovieSummary(
            id: dto.id,
            title: dto.title,
            posterPath: dto.posterPath,
            releaseYear: year(from: dto.releaseDate),
            rating: dto.voteAverage ?? 0
        )
    }

    static func mapDetail(from dto: MovieDetailDTO) -> Movie {
        Movie(
            id: dto.id,
            title: dto.title,
            originalTitle: dto.originalTitle ?? dto.title,
            overview: dto.overview ?? "",
            releaseDate: date(from: dto.releaseDate),
            runtime: dto.runtime,
            rating: dto.voteAverage ?? 0,
            voteCount: dto.voteCount ?? 0,
            posterPath: dto.posterPath,
            backdropPath: dto.backdropPath,
            genres: (dto.genres ?? []).map { Genre(id: $0.id, name: $0.name) },
            tagline: dto.tagline
        )
    }

    static func mapCredits(from dto: CreditsResponseDTO) -> Credits {
        let director = dto.crew.first { $0.job?.lowercased() == "director" }
        let directorPerson = director.map {
            Person(
                id: $0.id,
                name: $0.name,
                profilePath: $0.profilePath,
                role: .director
            )
        }

        let topCast = dto.cast
            .sorted { ($0.order ?? 999) < ($1.order ?? 999) }
            .prefix(5)
            .map { cast in
                Person(
                    id: cast.id,
                    name: cast.name,
                    profilePath: cast.profilePath,
                    role: .cast(character: cast.character ?? "")
                )
            }

        return Credits(director: directorPerson, topCast: topCast)
    }

    private static func date(from value: String?) -> Date? {
        guard let value, !value.isEmpty else { return nil }
        return dateFormatter.date(from: value)
    }

    private static func year(from value: String?) -> Int? {
        guard let value, let date = dateFormatter.date(from: value) else { return nil }
        return Calendar.current.component(.year, from: date)
    }

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()
}

import Foundation

struct RecommendationPresentationModel: Equatable {
    let query: String
    let explanation: String
    let items: [RecommendationMovieItem]
}

struct RecommendationMovieItem: Identifiable, Equatable {
    let id: Int
    let title: String
    let posterURL: URL?
    let releaseYearText: String?
    let ratingText: String
    let reason: String?
    let movieSummary: MovieSummary
}

@MainActor
enum RecommendationPresentationMapper {
    static func map(snapshot: ChatRecommendationSnapshot) -> RecommendationPresentationModel {
        RecommendationPresentationModel(
            query: snapshot.query,
            explanation: snapshot.explanation,
            items: snapshot.recommendations.map(mapItem)
        )
    }
    
    private static func mapItem(_ recommendation: Recommendation) -> RecommendationMovieItem {
        let movie = recommendation.movie
        
        return RecommendationMovieItem(
            id: recommendation.id,
            title: movie.title,
            posterURL: ImageURLBuilder.posterURL(path: movie.posterPath, size: .posterMedium),
            releaseYearText: movie.releaseYear.map(String.init),
            ratingText: formatRating(movie.rating),
            reason: recommendation.reason,
            movieSummary: movie
        )
    }
    
    private static func formatRating(_ rating: Double) -> String {
        guard rating > 0 else {
            return "—"
        }
        
        return String(format: "%.1f", rating)
    }
}

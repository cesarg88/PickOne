import Foundation

enum ImageURLBuilder {
    static func posterURL(path: String?, size: AppConfiguration.ImageSize = .posterMedium) -> URL? {
        buildURL(path: path, size: size)
    }

    static func backdropURL(path: String?, size: AppConfiguration.ImageSize = .backdropLarge) -> URL? {
        buildURL(path: path, size: size)
    }

    static func providerLogoURL(path: String?) -> URL? {
        buildURL(path: path, size: .providerLogo)
    }

    private static func buildURL(path: String?, size: AppConfiguration.ImageSize) -> URL? {
        guard let path, !path.isEmpty else { return nil }
        let trimmed = path.hasPrefix("/") ? String(path.dropFirst()) : path
        return URL(string: "\(AppConfiguration.tmdbImageBaseURL)/\(size.rawValue)/\(trimmed)")
    }
}

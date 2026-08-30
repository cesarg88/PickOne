import Foundation

protocol CalibrationCatalogCacheStore: Sendable {
    func read(region: String, locale: String) throws -> Data?
    func replace(_ data: Data, region: String, locale: String) throws
}

struct CachesCalibrationCatalogStore: CalibrationCatalogCacheStore {
    private let directoryURL: URL

    init(directoryURL: URL? = nil) throws {
        if let directoryURL {
            self.directoryURL = directoryURL
        } else {
            self.directoryURL = try FileManager.default.url(
                for: .cachesDirectory,
                in: .userDomainMask,
                appropriateFor: nil,
                create: true
            ).appending(path: "PickOne/CalibrationCatalog", directoryHint: .isDirectory)
        }
    }

    func read(region: String, locale: String) throws -> Data? {
        let url = fileURL(region: region, locale: locale)
        guard FileManager.default.fileExists(atPath: url.path(percentEncoded: false)) else {
            return nil
        }
        return try Data(contentsOf: url)
    }

    func replace(_ data: Data, region: String, locale: String) throws {
        try FileManager.default.createDirectory(
            at: directoryURL,
            withIntermediateDirectories: true
        )
        try data.write(
            to: fileURL(region: region, locale: locale),
            options: .atomic
        )
    }

    private func fileURL(region: String, locale: String) -> URL {
        let name = [region, locale]
            .map(sanitizedFileComponent)
            .joined(separator: "-")
        return directoryURL.appending(path: "calibration-catalog-\(name)-v1.json")
    }

    private func sanitizedFileComponent(_ value: String) -> String {
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-_"))
        return String(value.unicodeScalars.map { allowed.contains($0) ? Character($0) : "_" })
    }
}

struct UnavailableCalibrationCatalogCacheStore: CalibrationCatalogCacheStore {
    func read(region _: String, locale _: String) throws -> Data? {
        nil
    }

    func replace(_ data: Data, region _: String, locale _: String) throws {
        throw CocoaError(.fileWriteUnknown)
    }
}

protocol BundledCalibrationCatalogSource: Sendable {
    func load() throws -> Data
}

enum BundledCalibrationCatalogSourceError: Error, Equatable, Sendable {
    case missingResource
}

struct FileBundledCalibrationCatalogSource: BundledCalibrationCatalogSource {
    private let resourceURL: URL

    init(resourceURL: URL?) throws {
        guard let resourceURL else {
            throw BundledCalibrationCatalogSourceError.missingResource
        }
        self.resourceURL = resourceURL
    }

    func load() throws -> Data {
        try Data(contentsOf: resourceURL)
    }
}

struct UnavailableBundledCatalogSource: BundledCalibrationCatalogSource {
    func load() throws -> Data {
        throw BundledCalibrationCatalogSourceError.missingResource
    }
}

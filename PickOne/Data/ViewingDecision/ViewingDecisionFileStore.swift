import Foundation

protocol ViewingDecisionFileStore: Sendable {
    func readActive() throws -> Data?
    func readPrevious() throws -> Data?
    func replaceActive(_ data: Data) throws
    func replacePrevious(_ data: Data) throws
    func quarantine(_ data: Data, source: String) throws
}

struct ApplicationSupportViewingDecisionStore: ViewingDecisionFileStore {
    private let directory: URL
    init(directory: URL? = nil) throws {
        self.directory = try directory ?? FileManager.default.url(
            for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true
        ).appending(path: "PickOne/ViewingDecisions", directoryHint: .isDirectory)
    }

    func readActive() throws -> Data? {
        try read("decisions.json")
    }

    func readPrevious() throws -> Data? {
        try read("decisions.previous.json")
    }

    func replaceActive(_ data: Data) throws {
        try replace(data, name: "decisions.json")
    }

    func replacePrevious(_ data: Data) throws {
        try replace(data, name: "decisions.previous.json")
    }

    func quarantine(_ data: Data, source: String) throws {
        let target = directory.appending(path: "Quarantine", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: target, withIntermediateDirectories: true)
        try data.write(to: target.appending(path: "\(UUID().uuidString)-\(source).json"), options: .withoutOverwriting)
    }

    private func read(_ name: String) throws -> Data? {
        let url = directory.appending(path: name)
        guard FileManager.default.fileExists(atPath: url.path()) else { return nil }
        return try Data(contentsOf: url)
    }

    private func replace(_ data: Data, name: String) throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try data.write(to: directory.appending(path: name), options: .atomic)
    }
}

struct UnavailableViewingDecisionStore: ViewingDecisionFileStore {
    func readActive() throws -> Data? {
        throw ViewingDecisionError.unavailable
    }

    func readPrevious() throws -> Data? {
        throw ViewingDecisionError.unavailable
    }

    func replaceActive(_: Data) throws {
        throw ViewingDecisionError.unavailable
    }

    func replacePrevious(_: Data) throws {
        throw ViewingDecisionError.unavailable
    }

    func quarantine(_: Data, source _: String) throws {
        throw ViewingDecisionError.unavailable
    }
}

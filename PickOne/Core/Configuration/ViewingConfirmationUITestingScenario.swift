import Foundation

/// Deterministic dates and metadata for isolated UI-test storage only.
enum ViewingConfirmationUITestingScenario {
    static var isEnabled: Bool {
        AppConfiguration.isUITesting && ProcessInfo.processInfo.arguments.contains("-ui-testing-confirmation")
    }

    static var now: Date {
        let arguments = ProcessInfo.processInfo.arguments
        let days: Double = if arguments.contains("-ui-testing-confirmation-day-3") {
            3
        } else if arguments.contains("-ui-testing-confirmation-day-2") {
            2
        } else if arguments.contains("-ui-testing-confirmation-day-1") {
            1
        } else {
            0
        }
        return Date().addingTimeInterval(12 * 3600 + days * 24 * 3600 + 60)
    }

    static func metadata(movieID: Int) throws -> MovieFeedbackMetadata {
        try MovieFeedbackMetadata(
            title: movieID == 101 ? "Tonight's Movie" : "Another Movie",
            releaseYear: 2020,
            posterPath: nil
        )
    }
}

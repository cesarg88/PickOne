import Foundation

struct PilotSearchEvidence: Equatable, Sendable {
    let id: UUID
    let recordedAt: Date
    let duration: TimeInterval
    let stage: RecommendationRecallStageKind
    let outcome: RecommendationDiagnosticOutcome
}

struct PilotMeasurementSummary: Equatable, Sendable, Codable {
    let sessions: Int
    let sessionsWithPick: Int
    let sessionsConfirmedWatched: Int
    let picks: Int
    let confirmedWatched: Int
    let superseded: Int
    let cancelled: Int
    let notWatched: Int
    let pending: Int
    let postponements: Int
    let loveIt: Int
    let likeIt: Int
    let itWasOkay: Int
    let didNotLikeIt: Int
    let satisfactionUnavailable: Int
    let firstPickSamples: Int
    let finalPickSamples: Int
    let firstPickMeanSeconds: Double?
    let finalPickMeanSeconds: Double?
    let observedSets: Int
    let refreshes: Int
    let observedMovies: Int
    let alreadyWatched: Int
    let sessionsWithObservationEvidence: Int
    let searches: Int
    let expandedSearches: Int
    let usableSearches: Int
    let exhaustedSearches: Int
    let failedSearches: Int
    let searchMeanSeconds: Double?

    let confirmationRate: Double?
    let pickRate: Double?
    let alreadyWatchedRate: Double?

    init(state: ViewingDecisionState) {
        sessions = state.sessions.count
        let decisions = state.decisions
        sessionsWithPick = Set(decisions.compactMap(\.sessionID)).count
        let confirmed = decisions.filter { $0.status == .confirmedWatched }
        sessionsConfirmedWatched = Set(confirmed.compactMap(\.sessionID)).count
        picks = decisions.count
        confirmedWatched = confirmed.count
        superseded = decisions.count { $0.status == .superseded }
        cancelled = decisions.count { $0.status == .cancelled }
        notWatched = decisions.count { $0.status == .notWatched }
        pending = decisions.count { $0.status == .active }
        postponements = decisions.reduce(0) { $0 + $1.postponementCount }
        loveIt = confirmed.count { $0.satisfaction == .loveIt }
        likeIt = confirmed.count { $0.satisfaction == .likeIt }
        itWasOkay = confirmed.count { $0.satisfaction == .itWasOkay }
        didNotLikeIt = confirmed.count { $0.satisfaction == .didNotLikeIt }
        satisfactionUnavailable = confirmed.count { $0.satisfaction == nil }
        let first = state.sessions.compactMap { Self.seconds($0.firstPickTiming) }
        let final = state.sessions.compactMap { session in
            decisions.first { $0.id == session.finalDecisionID }.flatMap { Self.seconds($0.timing) }
        }
        firstPickSamples = first.count
        finalPickSamples = final.count
        firstPickMeanSeconds = Self.mean(first)
        finalPickMeanSeconds = Self.mean(final)
        observedSets = state.sessions.reduce(0) { $0 + $1.observedSetIDs.count }
        refreshes = state.sessions.reduce(0) { $0 + $1.refreshCount }
        let measured = state.sessions.filter { $0.observedMovieIDs != nil }
        sessionsWithObservationEvidence = measured.count
        observedMovies = measured.reduce(0) { $0 + ($1.observedMovieIDs?.count ?? 0) }
        alreadyWatched = measured.reduce(0) { $0 + $1.alreadyWatchedMovieIDs.count }
        searches = state.searchEvidence.count
        expandedSearches = state.searchEvidence.count { $0.stage != .normal }
        usableSearches = state.searchEvidence.count { $0.outcome == .usable }
        exhaustedSearches = state.searchEvidence.count { $0.outcome == .exhausted }
        failedSearches = state.searchEvidence.count { $0.outcome == .retryableFailure }
        searchMeanSeconds = Self.mean(state.searchEvidence.map(\.duration))
        confirmationRate = Self.ratio(confirmedWatched, picks)
        pickRate = Self.ratio(sessionsWithPick, sessions)
        alreadyWatchedRate = Self.ratio(alreadyWatched, observedMovies)
    }

    private static func ratio(_ numerator: Int, _ denominator: Int) -> Double? {
        denominator == 0 ? nil : Double(numerator) / Double(denominator)
    }

    private static func seconds(_ timing: DecisionTiming?) -> Double? {
        if case let .available(value) = timing { value } else { nil }
    }

    private static func mean(_ values: [Double]) -> Double? {
        values.isEmpty ? nil : values.reduce(0, +) / Double(values.count)
    }
}

protocol PilotMeasurementRepository: Sendable {
    func measurementSummary(at date: Date) async throws -> PilotMeasurementSummary
    func exportMeasurement(at date: Date) async throws -> Data
    func deleteMeasurement(operationID: UUID, at date: Date) async throws
}

extension ViewingDecisionState {
    mutating func recordMeasurement(_ action: ViewingDecisionAction) throws -> Bool {
        if case let .search(evidence) = action {
            guard evidence.duration.isFinite, evidence.duration >= 0 else { throw ViewingDecisionError.invalidData }
            if !searchEvidence.contains(where: { $0.id == evidence.id }) {
                searchEvidence.append(evidence)
                searchEvidence = Array(searchEvidence.suffix(1000))
            }
            return true
        }
        if case let .alreadyWatched(id, movieID) = action {
            guard let index = sessions.firstIndex(where: { $0.id == id }),
                  sessions[index].observedMovieIDs?.contains(movieID) == true else { return true }
            if !sessions[index].alreadyWatchedMovieIDs.contains(movieID) {
                sessions[index].alreadyWatchedMovieIDs.append(movieID)
            }
            return true
        }
        return false
    }
}

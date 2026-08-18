struct P1DecisionRepairComposer: Sendable {
    private let engine: P1DecisionEngine

    init(engine: P1DecisionEngine = P1DecisionEngine()) {
        self.engine = engine
    }

    func compose(
        input: DecisionEngineInput,
        mandatoryRetainedMovieIDs: Set<Int>,
        maximumCount: Int = 3
    ) -> DecisionSelection {
        guard maximumCount > 0 else {
            return DecisionSelection(recommendations: [])
        }

        let ranked = engine.rankedCandidates(
            from: input,
            allowingShownMovieIDs: mandatoryRetainedMovieIDs
        )
        var selected = ranked.filter {
            mandatoryRetainedMovieIDs.contains($0.candidate.movieID)
        }
        selected.sort { $0.candidate.movieID < $1.candidate.movieID }
        selected = Array(selected.prefix(maximumCount))

        var remaining = ranked.filter {
            !mandatoryRetainedMovieIDs.contains($0.candidate.movieID)
        }
        while selected.count < maximumCount, !remaining.isEmpty {
            remaining.sort {
                engine.isPreferred($0, over: $1, selected: selected)
            }
            selected.append(remaining.removeFirst())
        }

        let selectedMovieIDs = Set(selected.map(\.candidate.movieID))
        return engine.select(from: ranked.filter {
            selectedMovieIDs.contains($0.candidate.movieID)
        })
    }
}

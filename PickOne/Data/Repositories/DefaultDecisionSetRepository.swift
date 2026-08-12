import Foundation

actor DefaultDecisionSetRepository: DecisionSetRepository {
    private let store: any DecisionSetDataStore
    private let coder: any DecisionSetEnvelopeCoding

    init(
        store: any DecisionSetDataStore,
        coder: any DecisionSetEnvelopeCoding = JSONDecisionSetEnvelopeCoder()
    ) {
        self.store = store
        self.coder = coder
    }

    func load() -> DecisionSetLoadResult {
        let data: Data
        do {
            guard let storedData = try store.readActive() else {
                return .absent
            }
            data = storedData
        } catch {
            return .recovery(.loadFailed)
        }

        do {
            return try .available(map(coder.decodeEnvelope(from: data)))
        } catch DecisionSetCodingError.unsupportedVersion {
            return quarantine(data, reason: .unsupportedVersion)
        } catch {
            return quarantine(data, reason: .corruptData)
        }
    }

    func replace(_ envelope: PersistedDecisionSet) throws {
        let data: Data
        do {
            data = try coder.encodeEnvelope(map(envelope))
        } catch {
            throw DecisionSetRepositoryError.encodingFailed
        }
        do {
            try store.replaceActive(with: data)
        } catch {
            throw DecisionSetRepositoryError.storageFailed
        }
    }

    private func quarantine(
        _ data: Data,
        reason: DecisionSetRecoveryReason
    ) -> DecisionSetLoadResult {
        do {
            try store.replaceQuarantine(with: data)
            return .recovery(reason)
        } catch {
            return .recovery(.quarantineFailed)
        }
    }

    private func map(_ envelope: PersistedDecisionSet) -> DecisionSetEnvelopeV1DTO {
        DecisionSetEnvelopeV1DTO(
            envelopeSchemaVersion: DecisionSetEnvelopeV1DTO.schemaVersion,
            decisionSetID: envelope.id,
            generatedAt: envelope.generatedAt,
            engineModelVersion: envelope.engineModelVersion.rawValue,
            cycle: DecisionCycleV1DTO(
                id: envelope.cycle.id,
                identitySignature: envelope.cycle.identitySignature.rawValue,
                shownMovieIDs: envelope.cycle.shownMovieIDs.sorted()
            ),
            regionCode: envelope.region.code,
            selectedProviderIDs: envelope.selectedProviderIDs.sorted(),
            recommendations: envelope.recommendations.map(map)
        )
    }

    private func map(
        _ recommendation: PersistedDecisionRecommendation
    ) -> PersistedDecisionRecommendationV1DTO {
        PersistedDecisionRecommendationV1DTO(
            role: map(recommendation.role),
            evidence: map(recommendation.evidence),
            display: DecisionDisplaySnapshotV1DTO(
                movieID: recommendation.display.movieID,
                localizedTitle: recommendation.display.localizedTitle,
                posterPath: recommendation.display.posterPath,
                backdropPath: recommendation.display.backdropPath,
                runtimeMinutes: recommendation.display.runtimeMinutes,
                releaseYear: recommendation.display.releaseYear,
                genres: recommendation.display.genres.map(map)
            ),
            availability: DecisionAvailabilitySnapshotV1DTO(
                matchingProviders: recommendation.availability.matchingProviders.map {
                    DecisionProviderSnapshotV1DTO(
                        providerID: $0.providerID,
                        name: $0.name,
                        logoPath: $0.logoPath,
                        productOrder: $0.productOrder
                    )
                },
                verifiedAt: recommendation.availability.verifiedAt,
                regionalWatchURL: recommendation.availability.regionalWatchURL?.absoluteString
            )
        )
    }

    private func map(_ evidence: RecommendationEvidence) -> RecommendationEvidenceV1DTO {
        let diversityKind = evidence.diversity.map { _ in "diverseDirection" }
        switch evidence.primary {
            case let .watchlistIntent(match):
                switch match {
                    case let .positiveAnchor(anchor):
                        return RecommendationEvidenceV1DTO(
                            primaryKind: "watchlistIntent",
                            tasteKind: "positiveAnchor",
                            anchor: map(anchor),
                            affinity: nil,
                            diversityKind: diversityKind
                        )
                    case let .positiveAffinity(affinity):
                        return RecommendationEvidenceV1DTO(
                            primaryKind: "watchlistIntent",
                            tasteKind: "positiveAffinity",
                            anchor: nil,
                            affinity: map(affinity),
                            diversityKind: diversityKind
                        )
                }
            case let .positiveAnchor(anchor):
                return RecommendationEvidenceV1DTO(
                    primaryKind: "positiveAnchor",
                    tasteKind: nil,
                    anchor: map(anchor),
                    affinity: nil,
                    diversityKind: diversityKind
                )
            case let .positiveGenreAffinity(affinity):
                return RecommendationEvidenceV1DTO(
                    primaryKind: "positiveGenreAffinity",
                    tasteKind: nil,
                    anchor: nil,
                    affinity: map(affinity),
                    diversityKind: diversityKind
                )
            case .sparseQuality:
                return RecommendationEvidenceV1DTO(
                    primaryKind: "sparseQuality",
                    tasteKind: nil,
                    anchor: nil,
                    affinity: nil,
                    diversityKind: diversityKind
                )
        }
    }

    private func map(_ anchor: PositiveAnchorEvidence) -> PositiveAnchorEvidenceV1DTO {
        let eraMatch: RecommendationEraMatchV1DTO? = switch anchor.eraMatch {
            case let .sameDecade(decade):
                RecommendationEraMatchV1DTO(
                    kind: "sameDecade",
                    candidateStartingYear: nil,
                    anchorStartingYear: decade.startingYear
                )
            case let .adjacentDecade(candidate, anchor):
                RecommendationEraMatchV1DTO(
                    kind: "adjacentDecade",
                    candidateStartingYear: candidate.startingYear,
                    anchorStartingYear: anchor.startingYear
                )
            case nil:
                nil
        }
        let reaction: String = switch anchor.reaction {
            case .loved: "loved"
            case .liked: "liked"
        }
        return PositiveAnchorEvidenceV1DTO(
            movieID: anchor.movieID,
            movieTitle: anchor.movieTitle,
            reaction: reaction,
            sharedGenres: anchor.sharedGenres.map(map),
            eraMatch: eraMatch
        )
    }

    private func map(_ affinity: PositiveAffinityEvidence) -> PositiveAffinityEvidenceV1DTO {
        PositiveAffinityEvidenceV1DTO(
            genres: affinity.genres.map(map),
            eraStartingYear: affinity.era?.startingYear
        )
    }

    private func map(_ genre: DecisionGenre) -> DecisionGenreV1DTO {
        DecisionGenreV1DTO(id: genre.id, name: genre.name)
    }

    private func map(_ dto: DecisionSetEnvelopeV1DTO) throws -> PersistedDecisionSet {
        guard let engineVersion = DecisionEngineModelVersion(rawValue: dto.engineModelVersion) else {
            throw DecisionSetCodingError.unsupportedVersion
        }
        guard let signature = DecisionCycleSignature(rawValue: dto.cycle.identitySignature) else {
            throw DecisionSetCodingError.corruptData
        }
        let cycle = try DecisionCycle(
            id: dto.cycle.id,
            identitySignature: signature,
            shownMovieIDs: Set(dto.cycle.shownMovieIDs)
        )
        return try PersistedDecisionSet(
            id: dto.decisionSetID,
            generatedAt: dto.generatedAt,
            engineModelVersion: engineVersion,
            cycle: cycle,
            region: ViewingRegion(code: dto.regionCode),
            selectedProviderIDs: dto.selectedProviderIDs,
            recommendations: dto.recommendations.map(map)
        )
    }

    private func map(
        _ dto: PersistedDecisionRecommendationV1DTO
    ) throws -> PersistedDecisionRecommendation {
        let display = try DecisionDisplaySnapshot(
            movieID: dto.display.movieID,
            localizedTitle: dto.display.localizedTitle,
            posterPath: dto.display.posterPath,
            backdropPath: dto.display.backdropPath,
            runtimeMinutes: dto.display.runtimeMinutes,
            releaseYear: dto.display.releaseYear,
            genres: dto.display.genres.map(map)
        )
        let providers = try dto.availability.matchingProviders.map {
            try DecisionProviderSnapshot(
                providerID: $0.providerID,
                name: $0.name,
                logoPath: $0.logoPath,
                productOrder: $0.productOrder
            )
        }
        let url: URL?
        if let rawURL = dto.availability.regionalWatchURL {
            guard let parsedURL = URL(string: rawURL) else {
                throw DecisionSetCodingError.corruptData
            }
            url = parsedURL
        } else {
            url = nil
        }
        return try PersistedDecisionRecommendation(
            role: mapRole(dto.role),
            evidence: map(dto.evidence),
            display: display,
            availability: DecisionAvailabilitySnapshot(
                matchingProviders: providers,
                verifiedAt: dto.availability.verifiedAt,
                regionalWatchURL: url
            )
        )
    }

    private func map(_ dto: RecommendationEvidenceV1DTO) throws -> RecommendationEvidence {
        let diversity: RecommendationDiversityEvidence?
        switch dto.diversityKind {
            case nil:
                diversity = nil
            case "diverseDirection":
                diversity = .diverseDirection
            default:
                throw DecisionSetCodingError.corruptData
        }

        let primary: RecommendationPrimaryEvidence
        switch dto.primaryKind {
            case "watchlistIntent":
                guard let tasteKind = dto.tasteKind else {
                    throw DecisionSetCodingError.corruptData
                }
                switch tasteKind {
                    case "positiveAnchor":
                        guard let anchor = dto.anchor, dto.affinity == nil else {
                            throw DecisionSetCodingError.corruptData
                        }
                        primary = try .watchlistIntent(match: .positiveAnchor(map(anchor)))
                    case "positiveAffinity":
                        guard let affinity = dto.affinity, dto.anchor == nil else {
                            throw DecisionSetCodingError.corruptData
                        }
                        primary = try .watchlistIntent(match: .positiveAffinity(map(affinity)))
                    default:
                        throw DecisionSetCodingError.corruptData
                }
            case "positiveAnchor":
                guard dto.tasteKind == nil, let anchor = dto.anchor, dto.affinity == nil else {
                    throw DecisionSetCodingError.corruptData
                }
                primary = try .positiveAnchor(map(anchor))
            case "positiveGenreAffinity":
                guard dto.tasteKind == nil, let affinity = dto.affinity, dto.anchor == nil else {
                    throw DecisionSetCodingError.corruptData
                }
                primary = try .positiveGenreAffinity(map(affinity))
            case "sparseQuality":
                guard dto.tasteKind == nil, dto.anchor == nil, dto.affinity == nil else {
                    throw DecisionSetCodingError.corruptData
                }
                primary = .sparseQuality
            default:
                throw DecisionSetCodingError.corruptData
        }
        return RecommendationEvidence(primary: primary, diversity: diversity)
    }

    private func map(_ dto: PositiveAnchorEvidenceV1DTO) throws -> PositiveAnchorEvidence {
        let title = dto.movieTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard dto.movieID > 0, !title.isEmpty else {
            throw DecisionSetCodingError.corruptData
        }
        let reaction: PositiveAnchorReaction = switch dto.reaction {
            case "loved": .loved
            case "liked": .liked
            default: throw DecisionSetCodingError.corruptData
        }
        let genres = dto.sharedGenres.map(map)
        guard
            genres.allSatisfy({ $0.id > 0 }),
            Set(genres.map(\.id)).count == genres.count
        else {
            throw DecisionSetCodingError.corruptData
        }
        let eraMatch: RecommendationEraMatch?
        switch dto.eraMatch?.kind {
            case nil:
                eraMatch = nil
            case "sameDecade":
                guard let match = dto.eraMatch, match.candidateStartingYear == nil else {
                    throw DecisionSetCodingError.corruptData
                }
                eraMatch = .sameDecade(DecisionDecade(year: match.anchorStartingYear))
            case "adjacentDecade":
                guard let match = dto.eraMatch, let candidate = match.candidateStartingYear else {
                    throw DecisionSetCodingError.corruptData
                }
                eraMatch = .adjacentDecade(
                    candidate: DecisionDecade(year: candidate),
                    anchor: DecisionDecade(year: match.anchorStartingYear)
                )
            default:
                throw DecisionSetCodingError.corruptData
        }
        return PositiveAnchorEvidence(
            movieID: dto.movieID,
            movieTitle: title,
            reaction: reaction,
            sharedGenres: genres,
            eraMatch: eraMatch
        )
    }

    private func map(_ dto: PositiveAffinityEvidenceV1DTO) throws -> PositiveAffinityEvidence {
        let genres = dto.genres.map(map)
        guard
            genres.allSatisfy({ $0.id > 0 }),
            Set(genres.map(\.id)).count == genres.count,
            !genres.isEmpty || dto.eraStartingYear != nil
        else {
            throw DecisionSetCodingError.corruptData
        }
        return PositiveAffinityEvidence(
            genres: genres,
            era: dto.eraStartingYear.map(DecisionDecade.init(year:))
        )
    }

    private func map(_ dto: DecisionGenreV1DTO) -> DecisionGenre {
        DecisionGenre(id: dto.id, name: dto.name)
    }

    private func map(_ role: DecisionRole) -> String {
        switch role {
            case .safeChoice: "safeChoice"
            case .stretchChoice: "stretchChoice"
            case .discoveryChoice: "discoveryChoice"
        }
    }

    private func mapRole(_ value: String) throws -> DecisionRole {
        switch value {
            case "safeChoice": .safeChoice
            case "stretchChoice": .stretchChoice
            case "discoveryChoice": .discoveryChoice
            default: throw DecisionSetCodingError.corruptData
        }
    }
}

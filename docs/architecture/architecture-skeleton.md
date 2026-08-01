# PickOne Architecture Skeleton

## Status
Active

## Core Structure

PickOne uses a strict 3-layer architecture.

Compile-time dependency direction:

`Presentation -> Domain <- Data`

Runtime control flow may proceed as:

`Presentation -> Domain -> Data`

Domain owns the contracts implemented by Data. Presentation and Data may depend
on Domain, but Domain does not depend on either layer.

## Presentation

Contains:

- SwiftUI views
- view models
- presentation models
- explicit view state enums

Rules:

- Presentation talks only to use cases.
- Presentation does not talk directly to repositories.
- Presentation does not depend on DTOs, API clients, or persistence details.
- View models map domain entities and snapshots into presentation state.

## Domain

Contains:

- entities
- immutable snapshots
- use cases
- repository protocols

Rules:

- Domain owns orchestration and business rules.
- Domain must not know about SwiftUI, UserDefaults, HTTP clients, or DTOs.
- Use cases coordinate repository calls and enforce product behavior.

## Data

Contains:

- repository implementations
- API clients
- DTOs
- persistence
- mappers

Rules:

- Data adapts external and stored representations into domain models.
- DTOs never enter Domain.
- Persistence details never enter Presentation.

## Snapshots vs View State

Snapshots are immutable domain payloads returned by use cases when a screen needs coordinated state.

Examples:

- `DiscoverySnapshot`
- `MovieDetailSnapshot`
- `WatchlistSnapshot`
- `SearchSnapshot`
- `ChatRecommendationSnapshot`

Snapshots are not UI state.

Views render explicit view state owned by view models.
View models are responsible for transforming snapshots into presentation models and state transitions.

## Recommendation Boundary

Recommendation source output is not treated as final UI-ready movie data.

Current rule:

- recommendation sources return candidates
- Domain orchestrates enrichment
- final recommendations are produced only after candidate resolution through `MovieRepository`

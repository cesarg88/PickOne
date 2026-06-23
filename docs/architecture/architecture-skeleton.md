# PickOne Architecture Skeleton

## Layers

The app uses a strict layered architecture:

Presentation -> Domain -> Data

## Presentation

Contains:

- SwiftUI views
- view models
- presentation models
- view state enums

Presentation depends only on domain use cases.

Presentation must not depend directly on:

- repositories
- data sources
- DTOs
- persistence

## Domain

Contains:

- entities
- immutable snapshots
- use cases
- repository protocols

Domain owns business rules and app behavior.

Domain must not know about:

- SwiftUI
- networking implementations
- persistence implementations
- DTOs

## Data

Contains:

- repository implementations
- API clients
- DTOs
- persistence
- mappers

Data adapts external and stored data into domain models.

## Core Patterns

### Snapshots

Snapshots are immutable domain-state payloads returned by use cases.

Examples:

- `DiscoverySnapshot`
- `MovieDetailSnapshot`
- `WatchlistSnapshot`
- `SearchSnapshot`
- `ChatRecommendationSnapshot`

### View State

Views render explicit state owned by view models.

View models transform domain snapshots into presentation state and presentation models.

### Repositories

Repositories return domain entities and domain state.

Repositories do not return:

- SwiftUI models
- view state
- UI-specific snapshots

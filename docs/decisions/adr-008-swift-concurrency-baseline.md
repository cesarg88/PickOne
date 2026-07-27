# ADR-008 — Swift Concurrency Baseline

## Status

Accepted

## Context

The pilot baseline compiled with Xcode 26 in Swift 5 language mode,
approachable concurrency, and `MainActor` as the default isolation. That hid
ownership decisions in Domain and Data and required several
`@unchecked Sendable` conformances.

## Decision

Milestone 3.4 adopts Swift 6 language mode and complete strict-concurrency
checking for the application, unit-test, and UI-test targets. Default actor
isolation is `nonisolated`; approachable concurrency remains enabled.

Ownership is explicit by layer:

- SwiftUI views, observable ViewModels, presentation mappers, the app entry
  point, and `AppContainer` are explicitly isolated to `MainActor`.
- Domain models, snapshots, repository contracts, and use-case contracts that
  cross asynchronous boundaries are compiler-checked `Sendable` values or
  immutable types. Domain has no default global-actor dependency.
- `MemoryCacheStore` and the in-flight request registry are actors.
- `UserDefaultsLocalStore` preserves its synchronous API and persistence format
  while serializing each read-modify-write transaction with
  `Synchronization.Mutex`. The protected value is only a sendable backend
  identifier; a `UserDefaults` instance is obtained and used entirely inside
  the critical section because Foundation does not declare `UserDefaults`
  `Sendable`.
- HTTP, catalog, recommendation, and default repository implementations are
  immutable compiler-checked `Sendable` types. `JSONResponseMapper` creates a
  decoder per call instead of sharing mutable decoder state.
- Test doubles use the same contracts: actors for asynchronous mutable state,
  mutexes for synchronous mutable protocols, and immutable value stubs where
  no mutation is required.

## Consequences

- all targets receive Swift 6 diagnostics under complete strict checking
- non-UI work no longer inherits `MainActor` implicitly
- persistence operations are atomic within the local store without changing
  stored keys, encoding, ordering, or synchronous repository behavior
- stale-response, cancellation, and background-refresh behavior remain intact
- all former `@unchecked Sendable` conformances are removed; there are no
  unchecked exceptions or diagnostic suppressions
- adding mutable shared state now requires an actor, a lock-protected owner, or
  an explicitly justified global actor

The implementation and validation evidence are recorded in
[Milestone 3.4](../milestones/milestone-3.4-swift-6-concurrency.md).

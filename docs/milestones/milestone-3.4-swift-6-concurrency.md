# Milestone 3.4 — Swift 6 Concurrency Migration

## Status

Implementation complete — Pending Review and Device Smoke Test

## Goal

Adopt Swift 6 strict concurrency on the stable post-pilot codebase before
backend and provider integration introduce additional asynchronous boundaries.

This is a technical correctness milestone. It must not change product behavior,
navigation, persistence semantics, or user-facing copy.

## Why Now

- the full automated suite and Release build are green
- the basic two-device pilot passed
- the current codebase is still small enough to migrate deliberately
- backend, provider, analytics, and regional-availability work will add more
  concurrency if migration is delayed
- the current default `MainActor` isolation hides ownership decisions in Domain
  and Data

## Current Baseline

- Swift 5 language mode
- approachable concurrency enabled
- default `MainActor` isolation
- explicit `@MainActor` presentation models
- several `@unchecked Sendable` repository and persistence types
- CI tests, analyze, Release build, and bundle inspection passing

## In Scope

1. Inventory every concurrency warning, mutable shared dependency, task, actor
   boundary, and `@unchecked Sendable`.
2. Remove default `MainActor` isolation from non-UI code.
3. Keep SwiftUI Views, observable ViewModels, and composition explicitly
   isolated to `MainActor`.
4. Give mutable persistence and repositories explicit ownership:
   immutable/sendable value, actor, lock-protected type, or main-actor
   dependency where product constraints justify it.
5. Enable Swift 6 language mode and complete strict checking.
6. Replace each `@unchecked Sendable` with proven compiler-checked isolation,
   or document a narrow exception if removal is not technically possible.
7. Update tests and mocks to use the same isolation contracts.
8. Keep cancellation and stale-response protections intact.
9. Update ADR-008 with the final architecture and consequences.

## Out of Scope

- UI or navigation changes
- recommendation behavior changes
- persistence format changes
- backend or AI-provider integration
- analytics
- broad repository abstraction or modularization
- performance optimization without evidence from the migration

## Implementation Order

### Phase 1 — Inventory and compiler feedback

- capture the current build settings and green test baseline
- enable Swift 6 diagnostics without committing a broken intermediate state
- classify findings by Presentation, Domain, Data, tests, and composition

### Phase 2 — Isolation design

- make UI isolation explicit
- isolate mutable local persistence
- correct repository and protocol sendability
- remove global isolation assumptions from Domain values and use cases

### Phase 3 — Strict mode

- enable Swift 6 language mode for app and test targets
- remove or justify remaining unchecked conformances
- resolve warnings without suppressing diagnostics

### Phase 4 — Verification and documentation

- run the complete unit and UI suite
- run Debug, Release, and Analyze gates
- compare observable behavior with the pilot baseline
- update ADR-008 and this milestone with final evidence

## Acceptance Criteria

- all application and test targets compile in Swift 6 language mode
- complete unit and UI suite passes
- Debug and Release builds pass
- static analysis passes
- no project concurrency warnings
- no new `@unchecked Sendable`
- existing unchecked conformances are removed or explicitly justified in ADR-008
- Search and Recommendation stale-response tests remain green
- persistence and Watchlist behavior remain unchanged
- CI passes on the final PR

## Agent Constraints

The implementing agent must:

- treat this document and ADR-008 as authoritative
- follow `AGENTS.md` and
  `docs/process/github-app-authentication.md` before any GitHub write
- avoid unrelated cleanup and product changes
- keep commits reviewable by migration phase
- explain the ownership model chosen for each mutable dependency
- never silence a warning merely to make the compiler green
- stop and request a product/architecture decision if a fix would change
  behavior or public contracts

## Implementation Result

The migration implements the ownership model accepted in
[ADR-008](../decisions/adr-008-swift-concurrency-baseline.md):

- all application, unit-test, and UI-test configurations use Swift 6 language
  mode, `nonisolated` default isolation, and complete strict-concurrency
  checking
- all SwiftUI views, observable ViewModels, presentation mappers, app
  composition, and the app entry point are explicitly `@MainActor`
- Domain and Data values that cross asynchronous boundaries are
  compiler-checked `Sendable`
- memory cache and in-flight request ownership use actors
- local persistence keeps its synchronous behavior and format while a mutex
  serializes complete read-modify-write transactions
- immutable HTTP clients and repositories are compiler-checked `Sendable`;
  response decoding no longer shares a mutable decoder
- asynchronous test doubles use actors, synchronous mutable test doubles use
  mutexes, and immutable stubs use values
- every former `@unchecked Sendable` conformance was removed, with no
  `nonisolated(unsafe)` or `@preconcurrency` suppression

No navigation, persistence key or encoding, recommendation result, cancellation
guard, stale-response guard, or user-facing copy changed.

## Automated Validation

The pre-migration baseline passed 102 unit tests and 1 UI smoke test in Swift 5.
The final Swift 6 implementation passed the following local gates on Xcode 26.5
with an iPhone 17 Pro simulator running iOS 26.5:

```text
xcodebuild test \
  -project PickOne.xcodeproj \
  -scheme PickOne \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=latest' \
  -parallel-testing-enabled NO \
  -derivedDataPath /tmp/PickOne-M34-Final-Tests \
  CODE_SIGNING_ALLOWED=NO
```

Result: 104 logical tests passed (103 unit tests and 1 UI test), 0 failed,
0 skipped. The Search and Recommendation stale-response tests passed within
this suite.

```text
xcodebuild build \
  -project PickOne.xcodeproj \
  -scheme PickOne \
  -configuration Debug \
  -destination 'generic/platform=iOS Simulator' \
  -derivedDataPath /tmp/PickOne-M34-Final-Debug \
  CODE_SIGNING_ALLOWED=NO

xcodebuild analyze \
  -project PickOne.xcodeproj \
  -scheme PickOne \
  -destination 'generic/platform=iOS Simulator' \
  -derivedDataPath /tmp/PickOne-M34-Final-Analyze \
  CODE_SIGNING_ALLOWED=NO

xcodebuild build \
  -project PickOne.xcodeproj \
  -scheme PickOne \
  -configuration Release \
  -destination 'generic/platform=iOS' \
  -derivedDataPath /tmp/PickOne-M34-Final-Release \
  CODE_SIGNING_ALLOWED=NO

Scripts/check-secrets.sh
Scripts/inspect-app-bundle.sh \
  /tmp/PickOne-M34-Final-Release/Build/Products/Release-iphoneos/PickOne.app
```

Result: every command exited successfully. Quiet compiler output contained no
project warning. Static source checks found zero unchecked or unsafe
concurrency suppressions, and `git diff --check` passed.

## Human Validation

No exhaustive physical-device regression is required for every compiler-only
commit. After automated gates pass, the product owner performs a short device
smoke test covering launch, Search, Ask, Detail, and Watchlist before merge.

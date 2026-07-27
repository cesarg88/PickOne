# ADR-008 — Swift Concurrency Baseline

## Status

Accepted

## Context

The project is compiled by Xcode 26 with Swift 5 language mode, approachable
concurrency, and `MainActor` as the default isolation. This is not equivalent to
Swift 6 strict-concurrency checking.

## Decision

Milestone 3.3 keeps the existing language and isolation mode, removes known
project warnings, and forbids introducing additional `@unchecked Sendable`
conformances.

The full migration will be a dedicated technical milestone. It will remove
default global isolation from non-UI code, isolate mutable stores explicitly,
enable Swift 6 language mode and complete concurrency checking, and replace
existing unchecked conformances with proven isolation.

## Consequences

- the pilot baseline stays small and low risk
- documentation accurately describes the current compiler behavior
- Swift 6 readiness remains explicit technical debt rather than an implied
  property of the current build

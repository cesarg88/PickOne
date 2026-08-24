# PickOne Engineering Definition

## Document Status

- Status: `Canonical`
- Last engineering review: `2026-08-24`

This document is the single current source of truth for PickOne's technical
invariants and engineering quality bar. Accepted ADRs preserve the reasoning for
individual decisions, active specifications bound implementation, and
`PRODUCT.md` remains authoritative for product behavior.

## Engineering Mission

Keep PickOne safe to change. Prefer explicit contracts, deterministic behavior,
small reviewable delivery, and verification that another engineer or agent can
reproduce without relying on chat history.

The Technical Lead owns engineering readiness, architecture, code quality, and
technical debt. The role may challenge feasibility and reject unsafe
implementations, but it must return product ambiguities to the Product Owner.

## Architecture

The dependency direction is:

```text
Presentation -> Domain <- Data
```

### Presentation

- Use Domain use cases and values; never construct or depend on concrete Data
  implementations.
- Keep SwiftUI views declarative and view models explicitly `@MainActor`.
- Own display mapping, navigation, and user-interaction orchestration, not
  business eligibility or persistence rules.

### Domain

- Own business models, invariants, repository contracts, and use-case
  orchestration.
- Remain independent of SwiftUI, network clients, persistence mechanisms, and
  Data DTOs.
- Preserve meaningful distinctions such as unknown versus ineligible, temporary
  context versus stable preference, and intent versus verified outcome.

### Data

- Implement Domain repository contracts.
- Treat network, persistence, configuration, and third-party responses as
  untrusted boundaries.
- Keep DTOs and storage representations inside Data and map them into validated
  Domain values.

### Composition

`AppContainer` is the composition root. It may know concrete Data types and
Presentation view models in order to construct and inject the object graph.
Feature code must not use it as a service locator.

## Swift 6 and Concurrency

- Use Swift 6 language mode with complete strict-concurrency checking.
- Keep UI and observable presentation state on `MainActor`.
- Make values crossing asynchronous boundaries immutable and `Sendable`.
- Give mutable shared state one explicit actor or lock-protected owner.
- Preserve cancellation and stale-response behavior across async boundaries.
- Do not introduce `@unchecked Sendable` or a global-actor escape hatch without
  an accepted ADR and focused tests proving the ownership model.

## API and Naming Design

- Name protocols for the capability they model; do not append `Protocol`.
- Name concrete implementations for behavior or technology; do not append
  `Impl`, `Implementation`, or type-kind suffixes.
- Prefer contracts that make invalid states hard to represent and error
  semantics explicit.
- Avoid speculative abstractions, pass-through wrappers, and public API exposure
  without a current consumer.
- New dependencies, targets, modules, persistence technologies, and cross-layer
  contracts require explicit Technical Lead approval and an ADR when expensive
  to reverse.

## Testing and Verification

- Add a failing focused test before implementing changed behavior or a bug fix.
- Test observable state and outcomes rather than internal call sequences.
- Cover important success, boundary, failure, cancellation, retry, persistence,
  and migration paths at the lowest reliable level.
- Use integration tests for repository and external-boundary behavior and keep UI
  tests for critical end-to-end journeys.
- Run focused tests while iterating and `make verify` before handoff.
- Green automation and physical-device validation are complementary; neither
  replaces the other.
- Ground version-sensitive Apple, Swift, Xcode, and third-party API decisions in
  current primary documentation.

The executable verification contract lives in
[`docs/process/repository-verification.md`](docs/process/repository-verification.md).

## Reviewability and Delivery

- One PR delivers one coherent outcome and remains buildable and green.
- Open implementation PRs as ready for review, never as drafts, after the local
  handoff checks pass. Do not wait for CI before handing the PR to the reviewer.
- Begin technical review independently of CI status. Pending or failed CI does
  not postpone review of the diff; green CI on the final SHA remains a merge
  gate, and any failure must still be resolved before merge.
- Split large milestones into dependency-ordered slices. Use stacked PRs only
  when a child cannot be reviewed or validated independently against `develop`.
- Keep refactors separate from behavior unless the refactor is necessary for the
  accepted implementation.
- Treat roughly 400 lines in one production file as a cohesion review signal,
  not an automatic failure. A file growing beyond 500 lines should be split or
  justified in the PR when the change adds another responsibility.
- Close required milestone, roadmap, backlog, and ADR status in the final
  implementation PR before merge.

## Modularization Strategy

PickOne currently remains a modular monolith: one application target with
explicit internal boundaries. Physical modules are introduced only when they
create measured value through compiler-enforced dependencies, independent test
execution, ownership isolation, reusable pure logic, or build performance.

Prepare new feature boundaries for extraction without forcing premature public
APIs. A physical module requires a stable contract, a dependency graph, focused
tests, and an accepted ADR. The deterministic Decision Engine is the first
candidate to evaluate once its product and technical contracts are accepted;
this is not advance approval to extract it.

## Technical Debt

- Correctness, security, data-loss, concurrency, and migration risks block merge.
- Debt intrinsic to a change should be resolved in that change.
- Non-blocking debt must be recorded with evidence, severity, and a concrete
  resolution trigger; "later" is not a plan.
- Avoid speculative cleanup of stable code. Resolve monitored debt when its
  trigger occurs or when it blocks accepted work.

The active register is
[`docs/engineering/technical-debt.md`](docs/engineering/technical-debt.md).

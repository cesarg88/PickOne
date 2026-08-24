# PickOne Technical Debt Register

## Status

Accepted

## Purpose

Track concrete engineering liabilities without mixing them into the product
backlog. Every item requires evidence, severity, status, and a resolution
trigger. Architectural preferences without an observed cost are not debt.

## Classification

- `Critical` — security, data loss, broken migration, or unsafe concurrency;
  blocks merge.
- `High` — likely correctness or maintainability failure in active work.
- `Moderate` — measurable friction or an unenforced boundary that can become
  costly as the code grows.
- `Low` — localized maintainability concern with strong surrounding tests.

Statuses are `Observed`, `Planned`, `Monitoring`, `Resolved`, or `Accepted`.

## Active Items

### TD-001 — Layer boundaries are not compiler-enforced

- Severity: `Moderate`
- Status: `Monitoring`
- Evidence: Presentation, Domain, and Data are folders in one application
  target; dependency direction currently relies on review and conventions.
- Current mitigation: `ENGINEERING.md`, ADR-002, tests, app composition, and
  PickOne-specific implementation and review skills.
- Resolution trigger: an accepted feature has a stable independently testable
  contract, agents repeatedly conflict across the same boundaries, a boundary
  violation reaches review, or measured build/test performance justifies a
  physical module.
- Milestone 7 evaluation:
  no physical module is justified in D0. Viewer Movie State, persistence, and
  Decision Engine contracts change across PR1–PR5, there is no reuse
  requirement, and no measured build/test problem exists. Reevaluate after PR5
  only if a documented trigger has fired; extraction requires a separate ADR
  and PR.

### TD-002 — Viewer-profile orchestration has concentrated files

- Severity: `Low`
- Status: `Planned`
- Evidence: `ViewerProfileViewModel.swift` and
  `DefaultViewerProfileRepository.swift` are current cohesion-review hotspots
  with extensive focused test coverage.
- Current mitigation: behavior is isolated by use cases, repository contracts,
  persistence values, and dedicated tests.
- Resolution trigger: the next accepted change adds another responsibility to
  either file, tests require unrelated fixture setup, or a reviewer cannot
  reason about one state transition without loading unrelated flows.
- Constraint: do not refactor solely to reduce line count.
- Milestone 7 plan:
  PR2 builds the unified persistence owner, PR3 cuts profile/calibration
  transactions over to it, PR4 migrates Decision Set persistence to the
  non-reusable state identity, and PR5 extracts trusted-state loading, change
  classification, and reaction-driven cycle transition instead of adding them
  to existing coordinator or profile files.

### TD-003 — Viewer state is fragmented across profile and Watchlist stores

- Severity: `High`
- Status: `Planned`
- Evidence:
  calibration reactions live in Viewer Profile while Watchlist membership and
  watched state live in a separate UserDefaults-backed store. Accepted
  Milestone 7 transitions cross both aggregates and cannot be published
  atomically through the current contracts.
- Risk:
  adding catalog-wide reactions or independent watched changes without a
  migration would create contradictory state, partial writes, or lost pilot
  history.
- Resolution:
  ADR-012 and Milestone 7 PR1–PR3 introduce one validated transition reducer,
  a versioned Application Support envelope, active/previous/quarantine
  recovery, and deterministic legacy migration while Search History remains
  independent. PR4 preserves trusted M6 recommendation history while moving the
  Decision Set envelope to the new state identity.
- Resolution evidence required:
  migration over the final M6 build preserves profile, reactions, watched,
  Watchlist, Search History, and trusted Decision Set shown IDs; exhaustive
  transition, recovery, and physical-device upgrade tests pass.

## Resolved Items

None recorded.

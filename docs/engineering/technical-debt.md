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
- Candidate next evaluation: deterministic Decision Engine technical design.

### TD-002 — Viewer-profile orchestration has concentrated files

- Severity: `Low`
- Status: `Monitoring`
- Evidence: `ViewerProfileViewModel.swift` and
  `DefaultViewerProfileRepository.swift` are current cohesion-review hotspots
  with extensive focused test coverage.
- Current mitigation: behavior is isolated by use cases, repository contracts,
  persistence values, and dedicated tests.
- Resolution trigger: the next accepted change adds another responsibility to
  either file, tests require unrelated fixture setup, or a reviewer cannot
  reason about one state transition without loading unrelated flows.
- Constraint: do not refactor solely to reduce line count.

## Resolved Items

None recorded.

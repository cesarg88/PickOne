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
  no trigger fired through PR10. Focused boundaries remain reviewable, the
  complete verification time has not justified extraction, and no reuse or
  compiler-enforced isolation need emerged. Keep monitoring; any future module
  still requires a separate accepted ADR and PR.

## Resolved Items

### TD-002 — Viewer-profile orchestration has concentrated files

- Severity: `Low`
- Status: `Resolved`
- Resolution: Milestone 7 moved local transactions into the actor-owned viewer-
  state repository and focused profile extension, extracted trusted Decision
  State loading and reconciliation planning in PR5, and extracted catalog wait,
  cancellation, and retry ownership into `CalibrationCatalogFlowCoordinator`
  in PR9.
- Evidence: the resulting collaborators have focused Domain, Data, concurrency,
  Presentation, and composed PR10 coverage; no unrelated file-size refactor was
  required.

### TD-003 — Viewer state is fragmented across profile and Watchlist stores

- Severity: `High`
- Status: `Resolved`
- Resolution: ADR-012 and Milestone 7 PR1–PR4 replaced independent profile and
  Watchlist writes with one validated Application Support envelope, atomic
  transitions, previous-valid recovery, exact-byte quarantine, deterministic
  legacy migration, and non-reusable snapshot identity shared with Decision
  Set v2.
- Evidence: exhaustive transition/recovery suites, PR4 physical migration, and
  the PR10 composed final-M6 upgrade test preserve profile, reactions, watched,
  Watchlist, Search History, and every trusted Decision Set shown ID through v2
  publication and repository relaunch.

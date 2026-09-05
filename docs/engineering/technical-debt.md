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
  no trigger fired through PR10 or corrective P0-4. The prolonged integration
  fixture and DEBUG-only device seam compose existing protocols without a
  boundary violation, new dependency, or production module. Focused boundaries
  remain reviewable; keep monitoring, and require a separate accepted ADR and
  PR for any future module.

### TD-002 — Viewer-profile orchestration has concentrated files

- Severity: `Low`
- Status: `Monitoring`
- Milestone 7 decomposition: local transactions moved into the actor-owned
  viewer-state repository and focused extensions; PR5 extracted trusted
  Decision State loading and reconciliation planning; PR9 extracted catalog
  wait, cancellation, and retry ownership into
  `CalibrationCatalogFlowCoordinator`.
- Remaining evidence: `ViewerProfileViewModel` and the combined
  `LocalViewerStateRepository` plus `LocalViewerStateRepository+ViewerProfile`
  responsibility remain cohesion-review hotspots despite their focused tests.
- Current mitigation: the extracted collaborators, actor isolation, transition
  reducer, repository boundaries, and focused Domain, Data, concurrency,
  Presentation, and composed PR10 coverage keep behavior reviewable.
- Resolution trigger: at the post-Milestone 7 technical checkpoint, confirm
  whether either hotspot still requires unrelated state-transition context or
  fixture setup to change safely. Extract only an accepted cohesive
  responsibility; do not refactor solely to reduce line count.
- PR10 constraint: documentary monitoring only; no production refactor belongs
  in the integration-and-closure slice.
- P0-4 checkpoint: the prolonged regression was implemented with existing
  repositories and coordinator contracts, and the device evidence path is
  isolated behind DEBUG with transient state. Neither hotspot required an
  unrelated refactor, so no extraction trigger fired; keep monitoring.

## Resolved Items

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

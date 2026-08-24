---
name: implement-pickone-feature
description: Implement accepted PickOne iOS features and behavior changes with the repository's architecture, Swift 6 concurrency, testing, verification, GitHub identity, and PR handoff rules. Use when modifying PickOne production code from an accepted milestone or feature specification; do not use for product discovery or specification-only work.
---

# Implement a PickOne Feature

## Establish readiness

1. Read `AGENTS.md`, `ENGINEERING.md`, the active milestone, and relevant ADRs.
2. Read `PRODUCT.md` when the change affects user-visible behavior.
3. Read and apply `../apply-pickone-swift-style/SKILL.md` for every Swift change.
4. Confirm that product behavior is accepted and the technical scope has no
   unresolved decision that would change behavior or a public contract.
5. Read the GitHub authentication and repository verification policies.
6. Stop and request clarification instead of inventing missing product behavior.

## Bound the change

1. Identify the affected Presentation, Domain, Data, and composition boundaries.
2. Write a short dependency-ordered plan with focused verification for each
   slice.
3. Keep one branch and PR to one coherent outcome. Split large work into
   independently green PRs; stack only when a real dependency requires it.
4. State explicit non-goals and avoid unrelated refactors.

## Implement with evidence

1. For behavior or bug fixes, write or adjust the focused test first and prove
   that it fails for the intended reason.
2. Implement the smallest coherent solution that satisfies the accepted
   behavior.
3. Preserve `Presentation -> Domain <- Data`; wire concrete dependencies only
   in app composition.
4. Keep UI state on `MainActor`, make cross-boundary values `Sendable`, and give
   mutable shared state one explicit owner.
5. Model loading, empty, error, cancellation, stale data, and retry behavior
   where the specification requires them.
6. Do not add a dependency, target, module, unchecked concurrency escape hatch,
   or new architectural pattern without explicit technical approval.

## Verify and hand off

1. Run focused tests while iterating.
2. Review the complete diff for scope, naming, forced operations, lint
   suppressions, dead code, accidental API exposure, and missing documentation.
3. Run `make verify` from the repository root before handoff.
4. Let the commit hook run; never use `--no-verify`.
5. Use only the `Cesar-IA-Agent` identity for commits and GitHub writes.
6. Start the PR body from `.github/PULL_REQUEST_TEMPLATE.md`, keep every required
   heading, and record the specification, changes, trade-offs, exact validation,
   stack dependency and merge order, device checks, exclusions, and milestone
   closure state.
7. Open the PR as ready for review, never as a draft.
8. Hand off immediately after pushing and opening the PR. Do not wait for CI;
   report it as pending when no result exists yet. CI must still be green before
   merge.

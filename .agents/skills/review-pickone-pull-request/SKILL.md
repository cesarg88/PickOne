---
name: review-pickone-pull-request
description: Review PickOne pull requests for correctness, specification compliance, architecture, Swift 6 concurrency, tests, security, performance, documentation closure, and merge readiness. Use before merging implementation, refactor, migration, CI, or engineering-governance changes; keep the review read-only unless the user explicitly requests a GitHub write.
---

# Review a PickOne Pull Request

## Resolve context

1. Identify the repository, base branch, head branch, final SHA, and any stacked
   dependency or required merge order.
2. Read `AGENTS.md`, `ENGINEERING.md`, the linked specification, and relevant
   ADRs. Read `PRODUCT.md` for user-visible behavior.
3. Compare the entire base-to-head diff, not only the last commit. Inspect the
   last commit separately when it claims to fix review or CI findings.
4. Do not publish an approval, review, comment, or PR mutation unless the user
   explicitly asks for that write.

## Review tests before implementation

Determine whether the tests express the intended behavior and would catch a
regression. Check success, boundaries, errors, cancellation, stale state,
persistence, migration, and concurrency where relevant. Reject tests that only
mirror implementation details or make the production contract weaker.

## Review the implementation

Evaluate five axes:

1. **Correctness** — accepted behavior, invariants, edge cases, error semantics,
   state transitions, and cancellation.
2. **Readability** — naming, cohesion, control flow, duplication, dead code, and
   abstractions that do not earn their complexity.
3. **Architecture** — `Presentation -> Domain <- Data`, composition ownership,
   dependency direction, and feature scope.
4. **Safety** — secrets, untrusted external data, persistence integrity, Swift 6
   isolation, and mutable shared state.
5. **Performance** — duplicate requests, unbounded work, main-thread blocking,
   cache behavior, and avoidable rendering or mapping work.

Treat repository conventions as the default. Do not request a rewrite merely
because another valid style exists.

## Classify findings

Order findings by severity and include file and line evidence:

- **Critical** — security, data loss, or fundamentally broken behavior.
- **Required** — correctness, architecture, regression coverage, or accepted
  scope issue that must be fixed before merge.
- **Optional** — worthwhile improvement that does not block merge.
- **Nit** — minor style observation; formatting and lint belong to automation.

If there are no findings, say so explicitly and identify residual validation
risks rather than inventing comments.

## Decide merge readiness

Require the final SHA to have green CI, the required physical-device evidence,
an accurate PR description, and documentation closure in the same implementation
PR. For stacked work, approve and merge in dependency order, then revalidate the
new final SHA of the parent PR.

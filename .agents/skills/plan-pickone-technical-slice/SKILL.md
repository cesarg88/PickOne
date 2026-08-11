---
name: plan-pickone-technical-slice
description: Convert an accepted PickOne product specification into a bounded, dependency-ordered iOS engineering plan with contracts, architecture, Swift concurrency, persistence, failure behavior, tests, PR slicing, and validation. Use before implementation of a milestone or significant change; do not write production code or make product decisions.
---

# Plan a PickOne Technical Slice

## Confirm inputs

1. Read `AGENTS.md`, `ENGINEERING.md`, the accepted product specification,
   relevant ADRs, and the code at the affected boundaries.
2. Separate accepted product behavior from technical choices.
3. Return unresolved product behavior to the Product Owner. Do not convert an
   ambiguity into an architectural assumption.
4. Identify technical decisions that need an ADR before implementation.

## Produce the technical design

Define:

- impacted layers and dependency direction;
- Domain inputs, outputs, invariants, and error semantics;
- repository and client contracts plus DTO mapping boundaries;
- Presentation state, orchestration, cancellation, and retry behavior;
- Swift 6 isolation and ownership of mutable state;
- persistence schema, migration, recovery, and compatibility when applicable;
- observability or diagnostic evidence required for risky behavior;
- focused, integration, UI, CI, and physical-device validation;
- security, privacy, availability, rollout, and rollback constraints;
- explicit non-goals and accepted technical debt.

Ground platform or third-party API decisions in current primary documentation.

## Slice for independent delivery

Create a dependency graph and prefer small vertical PRs that remain buildable and
green. For every PR specify:

- outcome and acceptance criteria;
- dependencies and merge order;
- likely files and boundaries;
- focused verification;
- documentation updated or closed;
- work explicitly deferred.

Use a stacked PR only when the child cannot be reviewed or validated against
`develop` independently. Avoid assigning concurrent agents to the same core
files or contracts.

Declare the scope **Engineering Ready** only when no unresolved technical
decision can materially change implementation, contracts, migration, or test
strategy.

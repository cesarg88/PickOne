# Product and Engineering Agent Delivery Model

## Status

Accepted

## Purpose

Keep product and engineering decisions coherent while allowing implementation
work to run in focused, disposable agent tasks with limited context.

The repository, not a long-running chat, is the durable source of truth.

## Roles

### Product Owner

- owns product intent and final scope decisions
- works with the designated product agent to maintain `PRODUCT.md` and product
  specifications
- validates behavior on physical devices
- provides qualitative pilot feedback
- approves tradeoffs that change the user experience

### Technical Lead

- owns engineering readiness, architecture, technical quality, and the technical
  debt policy
- translates accepted product behavior into technical contracts and delivery
  slices without changing that behavior
- writes and maintains `ENGINEERING.md`, technical ADRs, engineering sections of
  milestones, and verification requirements
- identifies architecture constraints and integration risks
- reviews implementation pull requests
- verifies automated evidence, protects scope, and may block a merge on technical
  quality grounds
- returns unresolved product questions to the Product Owner instead of deciding
  them

### Implementation Agent

- receives one bounded specification
- works in a separate task and branch
- implements only the accepted scope
- runs the required automated checks
- opens a reviewable PR with evidence and unresolved questions
- does not invent product behavior or broaden architecture independently
- uses only the `Cesar-IA-Agent` identity for GitHub writes
- stops instead of falling back to a personal or work GitHub account

## Sources of Truth

For product intent and user-visible behavior, [`PRODUCT.md`](../../PRODUCT.md)
is canonical.

For current technical invariants, [`ENGINEERING.md`](../../ENGINEERING.md) is
canonical. Accepted ADRs preserve the reasoning and consequences of individual
technical decisions.

Within that product definition, use this order for delivery details:

1. active milestone or feature specification
2. accepted ADRs for technical decisions
3. improvement backlog and roadmap
4. implementation PR discussion
5. chat history

No delivery document may silently redefine the canonical product. If a
milestone needs different behavior, update `PRODUCT.md` through product steering
before delegating implementation.

Chat conclusions must be promoted into the repository before they are treated
as durable decisions.

All GitHub operations must also follow the mandatory
[GitHub App Authentication Policy](github-app-authentication.md).

## Definition of Ready for Autonomous Implementation

### Product Ready

The Product Owner has accepted:

- problem and desired outcome
- user or system behavior
- scope and explicit non-goals
- acceptance criteria
- privacy constraints and required physical-device validation
- no unresolved product decision that could materially change implementation

### Engineering Ready

The Technical Lead has accepted:

- relevant architecture constraints and ADRs
- data, error, loading, empty, and cancellation behavior
- concurrency, persistence, migration, security, and dependency implications
- required tests and CI gates
- rollout or feature-flag expectations
- PR dependency graph, stack order when applicable, and documentation closure
- no unresolved technical decision that could materially change contracts,
  implementation, migration, or verification

If one of these is intentionally irrelevant, the specification should say so.

## Delivery Workflow

1. The Product Owner and product agent define and accept user-visible behavior.
2. The product decision is written into `PRODUCT.md`, a versioned specification,
   roadmap item, or backlog entry.
3. The Technical Lead reviews feasibility and defines the technical contracts,
   ADRs, risks, verification, and delivery slices.
4. Product Ready and Engineering Ready are recorded before implementation.
5. A new implementation task and branch are created for one bounded outcome.
6. The implementation agent works from repository documents, not from the full
   steering-chat history.
7. The agent opens a PR using `.github/PULL_REQUEST_TEMPLATE.md`, automated
   validation, and a concise handoff.
8. The Technical Lead reviews correctness, architecture, scope, tests,
   failure behavior, and documentation.
9. The Product Owner performs the specified physical-device validation.
10. Required changes are returned to the implementation task.
11. Before merge, the implementation PR records final validation and closes the
    milestone, roadmap, backlog, and ADR status required by its specification.

## Pull Request Handoff Requirements

Every implementation PR must start from `.github/PULL_REQUEST_TEMPLATE.md` and
retain all of its headings, including when created through an API or CLI. Its
content must state:

- what changed
- why it changed
- specification and backlog identifiers
- base branch, dependent PRs, and merge order when stacked
- important architecture decisions
- tests and commands executed
- CI result
- known limitations
- device checks requested from the Product Owner
- follow-up work intentionally excluded

## Commit Requirements

Use a Conventional Commit subject:

```text
<type>(<optional-scope>): <imperative lowercase subject>
```

Allowed types are `feat`, `fix`, `docs`, `style`, `refactor`, `perf`, `test`,
`chore`, and `ci`. Keep each commit coherent, avoid vague subjects, and do not
end the subject with a period. Let the repository hook run and use only the
identity required by the GitHub App authentication policy.

## Context Management

- keep product steering and technical leadership in separate tasks
- use one separate implementation task per milestone or small feature
- avoid carrying full implementation transcripts back into the steering task
- return only the PR, decisions, validation evidence, and unresolved questions
- write every accepted decision into the repository
- use repository documents rather than chat history as the context package for
  product, technical, and implementation agents

## Scope and Review Rules

- one PR should deliver one coherent outcome
- large milestones should be divided into independently green PRs; stacking is
  reserved for real dependency constraints
- agents may refactor only where required by the specification
- architecture changes require an ADR or explicit review decision
- new dependencies require justification and approval
- automated green checks do not replace product/device validation
- device validation does not replace automated regression coverage
- a reviewer should reject accidental scope expansion even when the code works

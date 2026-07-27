# Product-Led Agent Delivery Model

## Status

Accepted

## Purpose

Keep product and architecture decisions coherent while allowing implementation
work to run in focused, disposable agent tasks with limited context.

The repository, not a long-running chat, is the durable source of truth.

## Roles

### Product Owner

- owns product intent and final scope decisions
- validates behavior on physical devices
- provides qualitative pilot feedback
- approves tradeoffs that change the user experience

### CTO / Product Engineer

- helps shape product decisions with the Product Owner
- writes and maintains specifications, ADRs, milestones, and acceptance criteria
- identifies architecture constraints and integration risks
- reviews implementation pull requests
- verifies automated evidence and protects scope
- updates durable documentation after decisions and merges

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

Use this order when documents appear to conflict:

1. accepted ADRs
2. active milestone or feature specification
3. product strategy and product brief
4. improvement backlog and roadmap
5. implementation PR discussion
6. chat history

Chat conclusions must be promoted into the repository before they are treated
as durable decisions.

All GitHub operations must also follow the mandatory
[GitHub App Authentication Policy](github-app-authentication.md).

## Definition of Ready for Autonomous Implementation

An implementation task is ready only when its specification includes:

- problem and desired outcome
- user or system behavior
- scope and explicit non-goals
- acceptance criteria
- relevant architecture constraints and ADRs
- data, error, loading, empty, and cancellation behavior
- privacy and security constraints
- required tests and CI gates
- rollout or feature-flag expectations
- physical-device validation required from the Product Owner
- no unresolved decision that could materially change the implementation

If one of these is intentionally irrelevant, the specification should say so.

## Delivery Workflow

1. Product Owner and CTO/Product Engineer discuss the problem in the steering
   task.
2. The decision is written into a versioned specification, ADR, roadmap item,
   or backlog entry.
3. The specification is reviewed until it meets the Definition of Ready.
4. A new implementation task and branch are created for one bounded outcome.
5. The implementation agent works from repository documents, not from the full
   steering-chat history.
6. The agent opens a PR with automated validation and a concise handoff.
7. The CTO/Product Engineer reviews correctness, architecture, scope, tests,
   failure behavior, and documentation.
8. The Product Owner performs the specified physical-device validation.
9. Required changes are returned to the implementation task.
10. After merge, roadmap, backlog, milestone, and ADR status are updated.

## Pull Request Handoff Requirements

Every implementation PR should state:

- what changed
- why it changed
- specification and backlog identifiers
- important architecture decisions
- tests and commands executed
- CI result
- known limitations
- device checks requested from the Product Owner
- follow-up work intentionally excluded

## Context Management

- keep this steering task focused on product, architecture, specifications, and
  PR review
- use one separate implementation task per milestone or small feature
- avoid carrying full implementation transcripts back into the steering task
- return only the PR, decisions, validation evidence, and unresolved questions
- write every accepted decision into the repository
- start a new steering task when the active product phase changes materially,
  using repository documents as its context package

## Scope and Review Rules

- one PR should deliver one coherent outcome
- agents may refactor only where required by the specification
- architecture changes require an ADR or explicit review decision
- new dependencies require justification and approval
- automated green checks do not replace product/device validation
- device validation does not replace automated regression coverage
- a reviewer should reject accidental scope expansion even when the code works

## First Application of This Model

- Steering work:
  define Decision Engine v1 and the product measurement contract.
- Delegated implementation:
  Milestone 3.4 — Swift 6 Concurrency Migration.
- Product Owner validation:
  short physical-device smoke test after automated migration gates pass.
- CTO/Product Engineer validation:
  review isolation design, strict-concurrency correctness, tests, and final PR.

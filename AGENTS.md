# PickOne Agent Instructions

## Product Authority

Before work that defines or changes user-visible product behavior, read
[`PRODUCT.md`](PRODUCT.md).

`PRODUCT.md` is the canonical authority for product intent and behavior.
Milestones and ADRs may bound or explain implementation, but must not silently
contradict it. An unresolved product question requires clarification rather
than an agent-invented decision.

## Engineering Authority

Before implementation, architecture, refactoring, migration, or code review,
read [`ENGINEERING.md`](ENGINEERING.md).

`ENGINEERING.md` is the canonical authority for current technical invariants.
Accepted ADRs explain individual decisions and the active specification bounds
the implementation. The Technical Lead owns engineering readiness and code
quality but does not invent or override product behavior.

## Mandatory GitHub Identity

Before any GitHub write operation, read and follow
[`docs/process/github-app-authentication.md`](docs/process/github-app-authentication.md).

All commits, pushes, pull requests, reviews, and GitHub write operations must use
the `Cesar-IA-Agent` GitHub App identity.

Never use:

- the `cesar-fever` account
- the `cesarg88` user identity
- the globally authenticated `gh` account
- SSH identities or personal Git credential helpers

If GitHub App authentication or a required App permission is unavailable, stop
and report the blocker. Do not fall back to a user account.

## Delivery Model

Read [`docs/process/agent-delivery-model.md`](docs/process/agent-delivery-model.md)
before implementation work.

Implementation agents must:

- work from the active milestone or feature specification
- keep scope bounded to that specification
- use a separate branch and pull request unless explicitly instructed otherwise
- preserve accepted architecture and ADR decisions
- provide automated validation and a concise PR handoff
- stop for clarification when a fix would change product behavior or public
  contracts

## Mandatory Verification

Before committing or handing off implementation work, read and follow
[`docs/process/repository-verification.md`](docs/process/repository-verification.md).

Every commit must pass the installed formatting and linting hook. Before
handing off implementation work or opening a pull request, run `make verify`
from the repository root. Do not bypass the hook with `--no-verify`. If a
required tool or check is unavailable, report the blocker rather than claiming
successful validation.

## Code Review Rules

Review the linked specification and tests before judging implementation style.
Block a merge when:

- Presentation depends on concrete Data implementations outside app composition
- Domain depends on SwiftUI, persistence, networking, or Data DTOs
- external failures or unknown evidence are silently converted into valid
  negative business outcomes
- mutable shared state lacks one explicit actor or lock-protected owner
- an `@unchecked Sendable`, forced operation, lint suppression, new dependency,
  or new target lacks a narrow documented justification
- changed behavior lacks regression coverage for its important success and
  failure paths
- the PR expands product behavior, public contracts, or architecture beyond its
  accepted scope
- final CI, required device evidence, PR description, or milestone documentation
  does not match the final SHA

Formatting and lint findings belong to the installed automation. Review comments
should prioritize correctness, safety, architecture, and maintainability.

# PickOne Agent Instructions

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

# ADR-006 — Stubbed Recommendation Source
## Status
Accepted
## Context
Recommendation UX needed validation before locking into backend or provider strategy.
## Decision
Keep the active recommendation source as a local stub/mock.
## Consequences
Recommendation work can progress safely without auth, deployment, or provider coupling, but source behavior is intentionally limited.

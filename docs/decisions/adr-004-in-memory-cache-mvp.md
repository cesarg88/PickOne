# ADR-004 — In-Memory Cache for MVP
## Status
Accepted
## Context
The app benefits from reduced repeated fetches, but full caching infrastructure is premature.
## Decision
Use an in-memory cache only for the current MVP phase.
## Consequences
Caching stays simple, ephemeral, and local to app sessions until stronger persistence needs emerge.

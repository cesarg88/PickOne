# ADR-005 — Watchlist Summary Persistence
## Status
Accepted
## Context
Watchlist storage needs to remain lightweight and independent from full detail payloads.
## Decision
Persist minimum `MovieSummary` data for watchlist entries.
## Consequences
Watchlist remains simple and local, but it is not a full offline mirror of movie detail data.

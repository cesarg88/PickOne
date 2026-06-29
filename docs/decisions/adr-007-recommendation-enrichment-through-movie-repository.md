# ADR-007 — Recommendation Enrichment Through MovieRepository
## Status
Accepted
## Context
Recommendation source outputs should not be trusted as final UI-ready movie data.
## Decision
Treat recommendation outputs as candidates and enrich them through `MovieRepository` before producing final recommendations.
## Consequences
The recommendation flow stays aligned with existing movie domain infrastructure and avoids UI/source coupling.

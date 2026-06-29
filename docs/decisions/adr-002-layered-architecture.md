# ADR-002 — Layered Architecture
## Status
Accepted
## Context
The app needs maintainable feature growth and clear ownership boundaries.
## Decision
Use a strict `Presentation -> Domain -> Data` architecture.
## Consequences
Business orchestration stays in Domain, DTOs stay in Data, and UI code remains thin and testable.

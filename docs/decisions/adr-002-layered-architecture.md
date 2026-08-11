# ADR-002 — Layered Architecture

## Status

Accepted — dependency notation clarified 2026-08-09

## Context

The app needs maintainable feature growth and clear ownership boundaries.

## Decision

Use the inward dependency direction:

```text
Presentation -> Domain <- Data
```

- Presentation depends on Domain use cases and values, never concrete Data
  implementations.
- Domain owns business rules and repository contracts. It does not depend on
  Presentation, persistence, networking, or Data DTOs.
- Data implements Domain contracts and maps external or persisted values into
  validated Domain values.
- The app composition root may construct concrete Data implementations and
  inject them into Domain use cases and Presentation view models.

This clarification corrects the original shorthand arrow. It does not change
the architecture implemented by later accepted ADRs.

## Consequences

Business orchestration stays in Domain, DTOs stay in Data, and UI code remains thin and testable.

# PickOne Product Roadmap

The canonical definition of the product and its accepted behavioral decisions
live in [`PRODUCT.md`](../../PRODUCT.md). This roadmap tracks delivery only and
must not redefine that product.

Pending product and engineering recommendations are tracked in
[Product & Engineering Improvement Backlog](improvement-backlog.md).

Product decisions and delegated implementation follow the
[Product-Led Agent Delivery Model](../process/agent-delivery-model.md).

## Status

Current Phase:
Phase 2 — Intelligence

## Phase 1 — MVP

Status: Complete

### Milestone 0

Foundation

### Milestone 1

Discovery & Detail

### Milestone 2

Watchlist & Search

### Milestone 3

Conversational Recommendations

### Milestone 3.1

Recommendation Enrichment

### Milestone 3.2

Ask UX Polish

## Phase 2 — Intelligence

Status:
In Progress

### Epic 2.1

Recommendation Strategy

Status:
Completed

Purpose:

Define how PickOne should think before introducing AI infrastructure.

Outcome:

Recommendation Strategy v1 accepted.

### Milestone 3.3

Repository & Pilot Release Health

Status:
Complete — Basic Two-Device Pilot Passed

Purpose:

Establish reproducible builds, a green full test suite, release-bundle hygiene,
and a reliable two-person device pilot before continuing Intelligence work.

### Milestone 3.4

[Swift 6 Concurrency Migration](../milestones/milestone-3.4-swift-6-concurrency.md)

Status:
Planned

Purpose:

Move the project to Swift 6 strict concurrency before backend and provider work
adds more asynchronous complexity. This milestone must not change product
behavior.

### Epic 2.2

Decision Engine v1

Status:

Planned

Purpose:

Define the product reasoning model that combines stable preferences, current
viewing context, active region, subscriptions, watched state, and availability
into three recommendation decisions.

No provider-specific implementation.

### Epic 2.3

AI Provider Abstraction

Status:

Planned

Purpose:

Define repository boundaries, interfaces and contracts for future providers.

### Epic 2.4

First Real Provider

Status:

Planned

Purpose:

Connect PickOne to its first production recommendation backend.

## Guiding Principle

Product decisions come before infrastructure.

The recommendation engine should evolve from product strategy, never the other way around.

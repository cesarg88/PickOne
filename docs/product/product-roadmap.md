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
Phase 3 — Decision Product MVP

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
Complete

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
Complete — merged in PR #13

Purpose:

Move the project to Swift 6 strict concurrency before backend and provider work
adds more asynchronous complexity. This milestone must not change product
behavior.

### SPIKE-001

[TMDB Spain Streaming Availability](../research/tmdb-es-streaming-availability-findings.md)

Status:
Complete — documented in PR #15

Purpose:

Validate whether TMDB can support Spain-specific, exact-provider subscription
eligibility for the first pilot.

Outcome:

Viable for the pilot with exact-provider movie-level verification and explicit
trust restrictions.

## Phase 3 — Decision Product MVP

Status:
Planning

### Milestone 4

Availability Foundation

Purpose:

Add the allowlisted Spain providers, TMDB candidate discovery, exact
movie-level eligibility verification, freshness handling, attribution, and
fallback watch-page handoff.

### Milestone 5

Viewer Profile & Onboarding

Purpose:

Collect region, selected services and plans, title-based taste calibration, and
persist one editable local profile per installation.

### Milestone 6

Three for Tonight

Purpose:

Define and implement the first deterministic decision engine, a persistent
three-title Home set, honest smaller sets, reasons, and explicit refresh.

### Milestone 7

Decision Feedback

Purpose:

Add `Watch this`, `Save for later`, `Not tonight`, `Not interested`, and
`Already watched` with their accepted learning semantics.

### Milestone 8

Trailers & Pilot Measurement

Purpose:

Add suitable trailers, viewing confirmation, and the minimum privacy-safe
measurement needed to evaluate time-to-decision.

## Deferred Intelligence Infrastructure

AI provider integration, backend infrastructure, and generalized
multi-provider abstractions remain deferred until the deterministic decision
experience demonstrates a product need they can solve.

## Guiding Principle

Product decisions come before infrastructure.

The recommendation engine should evolve from product strategy, never the other way around.

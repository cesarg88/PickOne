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

Status:
In Progress

## Phase 1 — Application Foundation & Feature Prototype

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

## Phase 2 — Product Strategy & Technical Readiness

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
and a reliable two-device pilot before starting the Decision Product MVP.

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

### Milestone 4

[Availability Foundation](../milestones/milestone-4-availability-foundation.md)

Status:
Complete — implementation merged in PR #16 and targeted iPhone validation
passed

Purpose:

Add the allowlisted Spain providers, exact movie-level eligibility
verification, freshness handling, direct Movie Detail presentation,
attribution, and the secondary fallback watch-page handoff.

### Milestone 5

[Viewer Profile & Onboarding](../milestones/milestone-5-viewer-profile-onboarding.md)

Status:
Complete — implementation in PR #20, automatic completion correction merged
from PR #21, and physical iPhone validation passed

Purpose:

Collect the supported services and title-based taste calibration, then persist
one editable local profile per installation. The pilot fixes the region to
Spain and maps the Product Owner's known plan entitlements internally rather
than exposing country or plan-variant selectors. Calibration includes positive,
neutral, and negative watched reactions, uses localized recognition metadata,
and derives confidence from stored reactions rather than persisting a counter.
After the last valid onboarding action, PickOne persists the completed profile
and enters the application automatically; only the low-signal choice between
`Rate more movies` and `Continue` requires an explicit decision.

### Milestone 6

[Three for Tonight](../milestones/milestone-6-three-for-tonight.md)

Status:
Complete — implementation and documentary closure merged in PR #31

Purpose:

Define and implement TMDB candidate generation, the first deterministic
decision engine, a persistent three-title Home set, honest smaller sets,
reasons, and explicit refresh. Discover results remain candidates until
Milestone 4 verification proves exact movie-level eligibility. Previously seen
exclusion combines informative calibration reactions with the independent
Watchlist watched state.

Delivery is split into dependency-ordered PRs for the pure P1 score, pure
selection and explanations, TMDB Discover recall, trusted input assembly,
Decision Set persistence, asynchronous orchestration, and the Home experience.
The application remains one physical target while the Decision Engine is kept
as an explicit internal boundary.

The closure correction narrows visible positive anchors to current `Love it`
or `Like it` reactions with at least one shared genre and genre Jaccard of at
least `1/3`. Era may reinforce but never establish the explanation, and visible
copy enumerates only the actual structured shared signals. P1 scoring is
unchanged.

### Utility Checkpoint after Milestone 6

Status:
Complete — functional checkpoint passed and Milestone 7 direction accepted

Purpose:

The Product Owner uses the complete onboarding, availability, and Three for
Tonight flow on the physical pilot iPhone during real household movie
decisions. The checkpoint evaluates whether:

- the recommendations make sense for the Product Owner
- the reported Spanish subscription availability is correct
- the experience helps reach a confident choice quickly

This is a lightweight household validation, not external user research or an
analytics implementation. The Product Owner's device validation confirmed the
flow and identified the explanation-strength correction plus continuous taste
learning as the correct next investment. The household utility checkpoint is
repeated after Milestone 7 with the enriched Taste Profile.

### Milestone 7

[Continuous Taste Learning](../milestones/milestone-7-continuous-taste-learning.md)

Status:
Accepted — Ready for implementation; PR1 begins after D0 merges

Purpose:

Unify watched facts, Movie reactions, `Not interested`, and future Watchlist
intent in one recoverable local state. Allow feedback from Movie Detail and the
accepted `My movies` history, recalculate Taste Profile and Home safely after
changes, preserve recommendation-cycle history, and load versioned remote
calibration catalogs with cached and bundled fallback plus exact-flow snapshot
freezing.

Milestone 7 does not add `Watch this`, `Not tonight`, rewatch intent, AI,
accounts, analytics, or a physical module. Delivery is split into D0 plus ten
small dependency-ordered implementation and closure PRs, including a dedicated
Decision Set v1-to-v2 migration slice.

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

# ADR-009 — Availability Boundary and Verification

## Status

Accepted

## Context

PickOne must recommend movies that the viewer can actually watch through a
selected subscription in the active region. SPIKE-001 established that TMDB can
support the Spain pilot, but only when Discover is treated as candidate
generation and each movie is verified against the exact provider in the
movie-level `ES.flatrate` response.

Availability differs from catalog metadata:

- it has explicit region, entitlement, monetization, and freshness rules
- source failure is not evidence that a movie is unavailable
- it requires synchronous revalidation at trust-sensitive boundaries
- it can fail without making otherwise valid Movie Detail content unusable
- it carries JustWatch attribution and an optional TMDB regional watch URL

Adding these responsibilities to `MovieRepository` would combine catalog
metadata with a separate business boundary and lifecycle.

## Decision

### Architecture boundary

Introduce a dedicated `AvailabilityRepository` protocol in Domain with its
implementation, TMDB client, DTOs, mapper, and memory cache in Data.

The dependency direction remains:

```text
Presentation → Domain ← Data
```

Runtime control flow may proceed from Presentation through Domain to Data, but
Domain owns the contracts and eligibility rules. Presentation uses availability
use cases only. DTOs, TMDB response shapes, cache implementation, and HTTP
errors never enter Presentation.

`MovieRepository` remains responsible for movie catalog metadata and
enrichment. TMDB Discover candidate generation belongs to the Decision Engine
milestone and is not added as unused Milestone 4 code.

### Pilot viewing context

Milestone 4 receives an immutable viewing context containing:

- region `ES`
- Netflix `8`
- Amazon Prime Video `119`
- Disney Plus `337`
- HBO Max `1899`

The context is injected at the composition root. It is not persisted and does
not introduce a temporary onboarding UI or hidden viewer profile. Milestone 5
will provide the same input contract from the accepted local profile.

### Evidence and domain outcome

Successfully decoded movie-level evidence for region `ES` records:

- movie identity
- region
- all relevant monetization arrays
- provider IDs, product-facing names, and optional logo paths
- the exact optional regional watch URL returned by TMDB
- `verifiedAt`, set only when the regional evidence is successfully verified

The Domain use case evaluates that evidence against the viewing context and
returns exactly one completed outcome:

- `eligible(providers, evidence)` — at least one selected and allowlisted
  provider occurs exactly under `ES.flatrate`
- `ineligible(evidence)` — valid `ES` evidence exists but no selected,
  allowlisted provider satisfies the rule
- `unknown(reason)` — `ES` evidence is absent, invalid, or could not be obtained

Network, server, and decoding failures map to `unknown`. Cancellation continues
to propagate as cancellation and must not publish a replacement availability
state.

An `unknown` outcome fails closed when availability is used for recommendations
but is never stored or presented as an ineligible result.

### Eligibility rules

- compare stable provider IDs, never display names, priorities, or logos
- require the exact selected provider in `ES.flatrate`
- return every selected provider that satisfies the rule
- deduplicate providers by ID and order them using the fixed product order:
  Netflix, Amazon Prime Video, Disney Plus, HBO Max
- ignore rent, buy, free, and ads arrays for pilot eligibility
- ignore stores, separately paid add-on channels, explicit unselected
  ad-labelled variants, and every provider outside the allowlist
- a provider that appears under `flatrate` remains eligible even when it also
  appears under another monetization type
- an absent `ES` entry is `unknown`; a valid `ES` entry with no qualifying
  provider is `ineligible`

### Freshness and cache

Cache only verified regional evidence, not `verifiedAt` in isolation and not an
`unknown` result.

- storage is memory-only and actor-isolated
- cache identity is movie ID plus region
- selected services are evaluated against cached evidence rather than included
  in the cache key
- evidence is fresh through 24 hours and stale only when its age is greater
  than 24 hours
- stale evidence is not returned as current proof while a background refresh
  runs; required verification waits for a new source result
- relaunching the application starts with an empty cache and triggers a new
  verification when availability is needed
- the implementation injects a clock so boundary behavior is deterministic in
  tests

This is a specialized availability policy. It does not change the existing
general movie-cache behavior accepted by ADR-004.

### Presentation independence

Movie Detail owns an availability-section state separate from its overall
detail state. Detail and availability requests start concurrently.

- movie content can render while availability is still loading
- availability failure never changes an otherwise loaded Detail into a
  screen-level error
- cancellation and stale-response protection prevent a result for one movie
  from updating another movie
- logo loading failure does not change eligibility; the provider name is the
  accessible visual fallback

Availability is not added to `MovieDetailSnapshot` in a way that makes the
existing detail use case wait for it.

### Handoff

Provider logos are informational and non-interactive.

The optional secondary handoff may use only the exact country-specific URL
returned by TMDB. PickOne never constructs or infers provider URLs.

- accept only a valid HTTPS TMDB URL
- hide the handoff when the URL is absent or invalid without changing an
  otherwise eligible outcome
- label the destination as TMDB
- if evidence is older than 24 hours, synchronously reverify before opening
- open only the latest returned URL when the movie remains eligible
- do not open when revalidation becomes ineligible or unknown; publish the new
  section state instead

## Consequences

- availability can evolve without bloating `MovieRepository`
- Domain preserves the difference between confirmed ineligibility and missing
  evidence
- the same verified result can support Detail now and recommendation filtering
  later
- the first availability load after every application launch requires a TMDB
  request
- transient failures may produce `unknown`, but never a false unavailable claim
- the Movie Detail implementation adds independent asynchronous state and
  cancellation handling
- no backend, direct JustWatch integration, provider deep link, disk cache, or
  generalized multi-source abstraction is introduced

## Rejected Alternatives

### Extend `MovieRepository`

Rejected because catalog metadata and availability have different business
rules, freshness semantics, errors, and trust boundaries.

### Collapse failures into unavailable

Rejected because absence of evidence is not evidence of absence and would
damage product trust.

### Persist `verifiedAt` without its evidence

Rejected because a timestamp cannot prove which provider, region, and
monetization data was verified.

### Persist availability during the pilot

Rejected because memory-only evidence is sufficient and avoids a persistence
format and migration before need is demonstrated.

### Combine availability into the blocking Detail snapshot

Rejected because availability must degrade independently and must not delay
otherwise useful movie content.

### Make provider logos open the TMDB watch page

Rejected because the destination is not the provider represented by the logo.

### Construct provider deep links

Rejected because TMDB does not supply them and inferred links would make an
unsupported promise.

## Related Documents

- [Milestone 4 — Availability Foundation](../milestones/milestone-4-availability-foundation.md)
- [TMDB Spain Streaming Availability Findings](../research/tmdb-es-streaming-availability-findings.md)
- [ADR-002 — Layered Architecture](adr-002-layered-architecture.md)
- [ADR-004 — In-Memory Cache for MVP](adr-004-in-memory-cache-mvp.md)
- [ADR-008 — Swift Concurrency Baseline](adr-008-swift-concurrency-baseline.md)

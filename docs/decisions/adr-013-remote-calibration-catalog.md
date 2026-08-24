# ADR-013 — Remote Calibration Catalog with Frozen Local Fallback

## Status

Accepted

The Product Owner accepted the two-second fallback, exact-snapshot freeze, and
AWS-independent client boundary on 2026-08-19. The ADR was accepted with the
final Milestone 7 D0 specification on 2026-08-24 after Milestone 6 merged.

## Context

Milestone 5 bundles one fixed calibration catalog in application code. Updating
its titles, order, or fallback metadata therefore requires a new app build.
Milestone 7 must allow a manually managed remote catalog while preserving:

- deterministic onboarding and recalibration;
- usable offline behavior;
- resumable drafts;
- historical Movie reactions across catalog changes;
- no AWS credentials or AWS-specific Domain contracts;
- complete validation of remote data before it becomes product input.

The canonical term is defined by the
[Product Language Glossary](../product/product-language-glossary.md).

## Decision

### Domain boundary

Domain owns immutable values equivalent to:

```text
CalibrationCatalogReference
├── schemaVersion
├── catalogID
├── version
├── region
└── locale

CalibrationCatalogSnapshot
├── reference
├── ordered movies
└── updatedAt

CalibrationCatalogResolution
├── snapshot
├── source = remote | cached | bundled
└── remoteFailure?
```

Domain exposes a capability equivalent to:

```text
CalibrationCatalogRepository.resolve(region, locale, deadline)
```

It does not know S3, CloudFront, AWS regions, bucket names, IAM, or credentials.

Remote outcomes remain distinguishable:

- `absent`: the configured document returns a definitive not-found response;
- `invalid`: supported JSON cannot satisfy content invariants;
- `incompatible`: schema version is unsupported;
- `unavailable`: timeout, cancellation-independent transport failure, or
  server failure prevents a usable response.

These diagnostics do not block calibration when a valid cached or bundled
snapshot exists.

### Document schema

The first remote schema contains at least:

```json
{
  "schemaVersion": 1,
  "catalogID": "es-household-calibration",
  "version": 1,
  "region": "ES",
  "locale": "es-ES",
  "updatedAt": "2026-08-19T00:00:00Z",
  "movies": [
    {
      "order": 0,
      "block": "primary",
      "tmdbMovieID": 238,
      "titleKnownInSpain": "El padrino",
      "originalOrEnglishTitle": "The Godfather",
      "year": 1972,
      "originalLanguage": "en"
    }
  ]
}
```

The Data DTO is not used outside the mapping boundary.

Complete validation requires:

- a recognized top-level schema;
- non-empty stable catalog ID and positive version;
- exact supported region and locale;
- valid ISO-8601 update date;
- a bounded response size before decoding;
- a bounded movie count;
- positive unique TMDB IDs;
- unique contiguous zero-based order;
- recognized `primary`, `reserve`, and `optionalExtension` blocks;
- exactly 12 primary, three reserve, and six optional-extension entries for the
  accepted v1 flow;
- non-empty localized and original/English fallback titles;
- plausible four-digit year and non-empty language code;
- early-stop diversity: at least one entry whose `originalLanguage` is not
  English (`en`) in the first eight positions. Spanish (`es`) satisfies the
  rule; other non-English languages provide the accepted clearly international
  alternative.

Any failed invariant rejects the complete remote document. Partial catalogs are
never admitted.

### Prefetch and two-second visible deadline

Prefetch begins before calibration:

- during first onboarding, start while the Viewer is choosing services;
- for recalibration, start when the Viewer requests `Repeat calibration`;
- a cached valid snapshot may be prepared immediately while remote validation
  proceeds.

When calibration needs a catalog, Presentation may show a dedicated loading
state for at most two seconds. The deadline covers the unresolved portion of
prefetch; it is not restarted by navigation or retry loops.

Resolution precedence at the deadline is:

1. valid compatible remote snapshot completed in time;
2. last valid compatible cached snapshot;
3. bundled fallback snapshot.

If remote completes after fallback selection, a valid result may update the
cache for a future flow but never replaces the snapshot chosen by the active
flow.

Cancellation of calibration cancels only the caller's wait. A shared prefetch
may finish and populate the cache if it remains owned by the catalog
repository.

### Exact snapshot freeze

Starting onboarding or recalibration persists the complete chosen
`CalibrationCatalogSnapshot` inside its draft, not only a version identifier.

Consequences:

- relaunch resumes with the exact order and fallback metadata;
- cache eviction cannot break an active draft;
- remote updates never alter current progress;
- Back navigation remains deterministic;
- completing the flow records its catalog reference while Viewer Movie State
  retains reactions independently of later catalog membership.

The bundled fallback is validated by the same Domain invariants in automated
tests.

### Data implementation

Data introduces a dedicated HTTPS client returning response data and HTTP
metadata needed to classify status. The existing TMDB JSON client is not
expanded into an AWS-aware or catalog-specific abstraction.

The remote endpoint is injected through application configuration. The iOS app
contains no AWS access key, secret, signing code, bucket-write permission, or
AWS SDK.

The repository actor owns:

- one in-flight prefetch shared by callers;
- deadline and cancellation coordination;
- remote DTO mapping and complete validation;
- one exact last-valid cache entry per supported region and locale;
- cache replacement only after validation;
- bundled fallback resolution.

The last-valid remote cache is a versioned file under the app's Caches
directory because it is reconstructable. An active frozen draft lives in the
non-discardable local viewer-state envelope defined by ADR-012.

The HTTP cache may reduce requests but is not the product fallback guarantee.

### Initial infrastructure

The first deployment may use:

- a private Amazon S3 bucket;
- S3 Versioning for manual rollback;
- CloudFront with Origin Access Control;
- HTTPS-only viewer access;
- read-only `GET` and `HEAD` behavior;
- explicit cache-control metadata and invalidation when an immediate manual
  update is required.

Manual upload or replacement is an operational concern outside the iOS code.
Another HTTPS static host can replace AWS without changing Domain or the JSON
schema.

### Publication governance

The initial remote document mirrors the accepted bundled household catalog in
the remote schema. A later change to IDs, order, blocks, or fallback metadata is
a product-content change: the Product Owner approves the complete validated
snapshot before publication, its version is incremented deliberately, and the
previous object remains recoverable.

The repository records a publication checklist and the exact JSON proposed for
the pilot. This ADR does not authorize an implementation agent to create or
modify AWS resources, DNS, or another external host. The Product Owner must
provide the read-only HTTPS endpoint or separately authorize its provisioning.
The endpoint URL is configuration, not a credential.

## Failure behavior

- remote absent, invalid, incompatible, or unavailable plus valid cache:
  continue with cache and retain diagnostic reason;
- remote and cache unusable plus valid bundled snapshot: continue with bundled;
- bundled validation failure: treat as a programmer/build error and block the
  flow rather than inventing a catalog;
- cache write failure: use the validated in-memory remote snapshot for the
  current flow, report diagnostic failure, and retain the previous cache;
- frozen draft decode or invariant failure: use the local viewer-state recovery
  path; never substitute a newer catalog into that draft;
- no state displays AWS-specific terminology to the Viewer.

Retry may attempt a new remote resolution only before a flow is frozen. A
started flow always retains its snapshot.

## Security and privacy

- accept only HTTPS URLs permitted by App Transport Security;
- impose response byte and item-count limits before allocating unbounded work;
- reject redirects outside the configured HTTPS trust policy;
- treat every remote field as untrusted;
- do not send Viewer Profile, reactions, Watchlist, or identifiers to the
  static catalog host;
- do not log the Viewer's responses with catalog network diagnostics;
- no remote document can modify provider allowlists, engine weights, feature
  flags, executable behavior, or arbitrary URLs.

## Consequences

### Positive

- catalog contents can change without an app release;
- onboarding remains deterministic and resumable;
- outages cannot block a valid fallback flow beyond two visible seconds;
- Domain remains independent from AWS;
- historical reactions survive catalog rotation;
- S3/CloudFront can be replaced without changing product contracts.

### Costs

- onboarding gains a bounded network-resolution state;
- drafts store a small immutable catalog snapshot;
- cache and network failures require explicit typed coverage;
- manual catalog publication needs an operational checklist outside the app.

## Alternatives considered

### Use a hardcoded catalog only

Rejected. Every content adjustment would still require an app release.

### Fetch directly from an AWS API or SDK

Rejected. Static read-only JSON needs no client credentials or AWS-specific
runtime dependency.

### Persist only catalog ID and version in the draft

Rejected. Cache eviction or remote replacement could make a resumable draft
unavailable or change its content.

### Let a late remote response replace an active fallback flow

Rejected. It would change movie order and progress after the Viewer began.

### Depend only on URLCache

Rejected. HTTP caching is not an explicit last-valid product guarantee and can
be evicted independently of draft recovery.

## Verification obligations

- DTO mapping and every invariant boundary;
- over-size response rejected before decode;
- exact status classification for 404, incompatible schema, invalid content,
  timeout, transport, and server failure;
- remote, cached, and bundled precedence;
- visible wait never exceeds two seconds under an injected clock;
- a late valid response updates only the next flow;
- one in-flight prefetch is shared safely and caller cancellation propagates
  correctly;
- cache write failure retains previous valid bytes;
- draft persists and resumes the exact selected snapshot;
- remote changes never alter a started onboarding or recalibration;
- bundled fallback completes onboarding with no network;
- no AWS credentials, SDK, or user-state payload enters the app bundle or
  request.
- the initial remote JSON is schema-valid, matches the Product Owner-approved
  catalog, and its published bytes are recorded for reproducibility;
- a read-only pilot endpoint is validated before milestone closure.

## Related documents

- [Milestone 7 — Continuous Taste Learning](../milestones/milestone-7-continuous-taste-learning.md)
- [Product Language Glossary](../product/product-language-glossary.md)
- [ADR-010 — Local Viewer Profile and Dynamic Viewing Context](adr-010-local-viewer-profile-and-dynamic-context.md)
- [ADR-012 — Unified Local Viewer Movie State](adr-012-unified-local-viewer-movie-state.md)

## Primary infrastructure references

- [AWS — Restrict access to an S3 origin with OAC](https://docs.aws.amazon.com/AmazonCloudFront/latest/DeveloperGuide/private-content-restricting-access-to-s3.html)
- [AWS — Require HTTPS between CloudFront and S3](https://docs.aws.amazon.com/AmazonCloudFront/latest/DeveloperGuide/using-https-cloudfront-to-s3-origin.html)
- [AWS — S3 Versioning](https://docs.aws.amazon.com/AmazonS3/latest/userguide/Versioning.html)

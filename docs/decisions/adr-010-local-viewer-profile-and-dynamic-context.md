# ADR-010 — Local Viewer Profile and Dynamic Viewing Context

## Status

Accepted

The Product Owner and CTO accepted this architecture on 2026-08-02. Milestone 4
was closed independently in PR #19, PR #18 was updated onto that `develop`
state, and the resulting documentation was confirmed conflict-free.

On 2026-08-03, physical-device validation led to an accepted automatic-
completion flow. This amendment changes Presentation orchestration but does not
change the repository boundary, envelope model, or atomicity definition.

Milestone 7 accepts two scoped successors without rewriting this historical
Milestone 5 decision. ADR-012 supersedes the physical
profile/Watchlist persistence envelope and the temporary separation of
calibration knowledge from watched state; ADR-013 supersedes the bundled-only
catalog source. `ViewerProfileRepository`, dynamic availability context, draft
lifecycle, and automatic completion semantics remain authoritative.

Cross-cutting terms use the canonical
[Product Language Glossary](../product/product-language-glossary.md).

## Context

Milestone 4 introduced a dedicated availability boundary with evidence cached
by movie ID and viewing region. The pilot currently constructs
`CheckMovieAvailability` with immutable
`AvailabilityViewingContext.spainPilot`, which selects all allowlisted services
for the lifetime of `AppContainer`.

Milestone 5 introduces one editable local viewer profile. It must persist:

- fixed Spain region;
- selected supported services;
- versioned calibration reactions;
- resumable onboarding or recalibration progress.

The profile becomes the current source of availability context. A service edit
must affect every availability check started after the save without discarding
fresh TMDB evidence. The system must also distinguish absent, incomplete,
unsupported, corrupt, and detectably unreadable state without silently
manufacturing a default profile.

The profile and the two draft variants have different lifecycles. During first
onboarding there is no completed profile. During recalibration, a completed
profile must remain active while a calibration-only replacement draft is saved.
Completion must replace the profile and remove the draft in one serialized
envelope update. Once Domain determines that calibration is complete,
Presentation triggers this replacement automatically; completion is not a
separate user confirmation.

## Decision

### Dedicated Domain boundary

Introduce a `ViewerProfileRepository` protocol owned by Domain. Do not add
profile responsibilities to:

- `MovieRepository`;
- `AvailabilityRepository`;
- the existing Data-layer `LocalStore` contract;
- a global singleton or service locator.

Domain models the current viewer state and owns its invariants. Data implements
local persistence. Presentation interacts only through focused use cases.

The compile-time dependency direction remains:

```text
Presentation → Domain ← Data
```

### Domain values

Add values equivalent to:

```text
ViewerProfile
ViewerProfileDraft
FirstOnboardingDraft
RecalibrationDraft
CalibrationReaction
CalibrationCatalogID
ViewerProfileLoadState
ViewerProfileRecoveryReason
```

Exact Swift names may follow repository conventions, but the semantic states
must remain distinct.

A completed `ViewerProfile` contains:

- profile schema version;
- calibration catalog version;
- Spain region;
- one or more selected allowlisted service IDs;
- reactions keyed by TMDB movie ID.

The existence of `completedProfile` is the completed-onboarding state. No
additional persisted boolean represents completion.

`ViewerProfileDraft` is a tagged choice between two semantically different
payloads. Draft schema identification belongs to the envelope/variant encoding.

A `FirstOnboardingDraft` contains:

- calibration catalog version;
- current user-facing onboarding step: service selection, calibration, or the
  low-signal decision;
- selected service IDs;
- reactions keyed by TMDB movie ID;
- current ordered catalog position;
- optional-extension state.

A `RecalibrationDraft` contains calibration state only:

- calibration catalog version;
- reactions keyed by TMDB movie ID;
- current ordered catalog position;
- optional-extension state.

`RecalibrationDraft` has no region or selected-service field. This exclusion is
part of the model and persisted DTO shape, not a convention that callers must
remember.

Domain exposes `informativeSignalCount` as a calculated property over the
stored reactions. It counts `Love it`, `Like it`, `It was okay`, and
`Didn't like it`. The neutral `It was okay` case means watched and informative
but is neither positive nor negative. The count is not persisted in either the
profile or draft.

Domain validates:

- region is supported;
- at least one selected service is allowlisted before completion;
- reaction IDs belong to the stored catalog version;
- response values are recognized;
- current position and extension state are valid for the catalog;
- any persisted catalog position is consistent with the stored reactions and
  extension state;
- a first-onboarding draft exists only without a completed profile;
- a recalibration draft exists only with a completed profile;
- recalibration completion combines region and selected services from the
  current active profile with reactions and catalog version from the draft.

Invalid invariants are not repaired by guessing.

### Repository operations

The Domain repository supports behavior equivalent to:

```text
loadState()
saveDraft(draft)
completeFirstOnboarding()
completeRecalibration()
updateServices(selection)
resetDraft()
resetProfileAndDraft()
```

Operations may be grouped differently if whole-envelope replacement and
distinct outcomes remain explicit. `completeRecalibration` must load the active
profile inside the same serialized repository operation that replaces the
envelope; it cannot accept region or services copied from the draft or captured
when recalibration began. Repository outcomes distinguish at least:

- unsupported schema;
- corrupt or invariant-invalid data;
- encoding failure;
- decoding failure;
- a storage error explicitly surfaced by a test double or future storage
  implementation.

Repository operations are serialized under one concurrency owner.

### Single persisted state envelope

Persist one encoded envelope under one dedicated local key. The envelope can
contain both:

- an optional completed profile;
- an optional tagged first-onboarding or recalibration draft.

Conceptually:

```text
ViewerStateEnvelopeV1
├── envelopeSchemaVersion
├── completedProfile?
└── profileDraft?
    ├── firstOnboarding(FirstOnboardingDraft)
    └── recalibration(RecalibrationDraft)
```

The envelope enables these valid combinations:

| Completed profile | Draft | Meaning |
| --- | --- | --- |
| No | None | First launch/profile absent |
| No | First onboarding | Incomplete first onboarding |
| Yes | None | Normal completed state |
| Yes | Recalibration | Active profile plus calibration-only replacement draft |

A profile with a first-onboarding draft and a recalibration draft without a
profile are invalid envelope combinations. They are reported as invalid data,
not coerced into another state.

Write the complete encoded envelope as one UserDefaults `Data` value. Do not
store profile fields, reactions, or draft progress in separate keys whose
independent logical updates could expose an inconsistent aggregate.

UserDefaults is accepted for this small local pilot aggregate. A database or
file-based store is not justified by the current scale.

### Atomicity

For this ADR, atomicity is a logical repository guarantee with these precise
properties:

- one concurrency owner serializes repository operations;
- the complete envelope is encoded before its stored value is replaced;
- the aggregate occupies one key rather than multiple independently updated
  keys;
- readers observe complete envelopes produced by repository logic, not partial
  states assembled from several field writes.

This does not mean that `UserDefaults.set` confirms physical persistence. That
API does not expose a physical-write acknowledgement, so v1 neither detects nor
promises recovery from an unreported durability failure.

Required transitions:

- first-onboarding change: replace envelope with updated draft;
- first completion: replace draft-only envelope with profile-only envelope;
- begin recalibration: replace profile-only envelope with profile-plus-draft;
- recalibration change: replace only the draft inside a full envelope;
- service edit during recalibration: replace the active profile selection while
  preserving the calibration-only draft;
- recalibration completion: replace profile-plus-draft with replacement
  profile-only envelope, taking current region and services from the active
  profile and reactions/catalog version from the draft;
- reset draft: remove only draft and preserve profile;
- reset profile: remove both profile and draft.

First-onboarding completion is invoked immediately after the last valid action
reaches an accepted Domain completion condition. There is no persisted
`readyToSave` state or user-confirmed save transition. A detectable failure
leaves the completed draft envelope intact so Presentation can remain on the
current onboarding state and retry the same completion operation. Presentation
enters the main application only after the repository returns the completed
profile successfully.

An encoding failure occurs before replacement and therefore leaves the previous
stored bytes unchanged. The same guarantee applies when a test double or future
storage implementation rejects a replacement before mutation. The
`UserDefaults` implementation does not manufacture a generic write-failure
state for a condition its API cannot report.

### Migration and byte preservation

Schema dispatch occurs before decoding a version-specific payload. Version 1
has no predecessor and therefore no data migration.

Future builds may register explicit migrations. When no accepted migration
exists:

- return unsupported-version state;
- preserve stored bytes;
- require explicit viewer reset.

When decoding or invariant validation fails:

- return corrupt-data state;
- preserve stored bytes;
- require explicit viewer reset.

Do not decode a newer schema as v1, drop unknown fields into a guessed current
profile, or overwrite bytes while merely loading.

### Calibration catalog boundary

The catalog identity, order, TMDB IDs, Spain-localized fallback titles, original
or English fallback titles, and years are bundled deterministic product data.
Domain receives an immutable catalog value through composition. No remote
response may change its membership or order.

Existing movie/catalog infrastructure may hydrate artwork and Spanish-localized
metadata. Cards show the title known in Spain first and the original or English
title plus year second. Failed hydration falls back to the same bundled display
fields and does not change catalog identity or block reaction entry. The first
eight positions include Spanish-language or clearly international cinema before
early completion can occur.

Presentation suppresses the secondary title when both forms are equivalent
after trimming surrounding whitespace, collapsing repeated whitespace, and a
case-insensitive comparison. It then shows one `Title · Year` line. Distinct
forms use two lines. Punctuation and diacritics remain significant; the mapper
does not perform linguistic normalization. Hydrated and fallback metadata use
the same rule.

No generalized remote configuration or catalog-management abstraction is
introduced.

#### Accepted Milestone 7 supersession

ADR-013 replaces only the catalog source and snapshot lifecycle. The ordered
catalog may resolve from a complete validated remote
document, last valid cache, or bundled fallback after at most two visible
seconds. The exact resolved snapshot is persisted with the draft so membership,
order, and fallback metadata cannot change during an active flow. Domain still
receives one immutable catalog value and remains independent of networking and
hosting.

### Current viewing context

Introduce a Domain boundary equivalent to `GetCurrentViewingContext`. It reads
the current completed profile from `ViewerProfileRepository` and maps:

- stored Spain region to `ViewingRegion.spain`;
- selected provider IDs to the accepted `PilotStreamingService` allowlist.

It never returns a hardcoded all-services fallback.

Change availability orchestration to the equivalent runtime flow:

```text
Movie Detail / caller
    → CheckMovieAvailability.execute(movieID, policy)
        → GetCurrentViewingContext.execute()
            → ViewerProfileRepository
        → AvailabilityRepository.getVerifiedEvidence(movieID, region, policy)
        → evaluate evidence against captured selected services
```

`CheckMovieAvailability` resolves and captures one viewing context at the start
of every execution. It no longer stores immutable `.spainPilot` context.

Consequences:

- a check begun after a successful service save uses the new selection;
- an already-running check may complete under its captured prior selection;
- Movie Detail does not need live updates while Preferences is open;
- the availability evidence cache remains keyed by movie and region;
- switching services can reuse fresh evidence and reevaluate it in Domain;
- playback handoff uses the same dynamic path and current selection;
- no profile or unrecoverable profile state produces typed context
  unavailability rather than all-services eligibility.

### Root routing

Add a root presentation state that loads viewer-profile state before choosing
between onboarding, recovery, and the main application.

First onboarding with no completed profile gates the main tabs. A
recalibration draft coexisting with a completed profile does not gate the app;
Settings exposes the resume path while the completed profile remains active.

This routing belongs to Presentation and app composition. Persistence does not
choose screens.

### Automatic completion orchestration

Presentation owns the orchestration between Domain completion rules and the
repository's whole-envelope replacement:

```text
last valid onboarding action
    → Domain reports completion due
    → completeFirstOnboarding()
        → success: enter the main application
        → detectable failure: retain draft, stay on the current onboarding
          state, and expose retry
```

No completion-confirmation screen, `readyToSave` presentation state, or
`Save preferences` action sits between the Domain outcome and the repository
operation. The only explicit completion-related user decision remains the
low-signal choice between `Rate more movies` and `Continue`.

### Stable Preferences entry

Use a fifth main `Settings` tab containing Preferences and About.

Rationale:

- it remains stable when Home replaces Discover;
- it avoids duplicating a toolbar action across tab navigation stacks;
- it does not imply account or multi-profile identity;
- it gives attribution and recovery-related settings a permanent home.

The current Discover-specific About action moves to Settings. The Product Owner
and CTO accepted this tab decision with the ADR.

### Concurrency

- Use one actor or equivalent checked serialization boundary for the local
  profile repository.
- Repository and use cases conform to `Sendable` without unchecked
  conformance.
- `AppContainer` owns one repository instance shared by profile use cases and
  current-context resolution.
- Presentation view models remain `@MainActor`.
- Persisted DTOs are immutable values and do not escape Data.
- No global mutable current-profile cache is introduced.

## Alternatives Considered

### Keep immutable `.spainPilot` context in `AppContainer`

Rejected. Service edits would require rebuilding composition or would leave
availability stale for the app lifetime.

### Mutate a shared in-memory `AvailabilityViewingContext`

Rejected. It creates a second source of truth, loses state on relaunch, and
introduces synchronization and stale-read behavior outside the profile
repository.

### Pass selected services from every view into availability

Rejected. Presentation would coordinate profile state and business context,
and every caller could apply different or stale selection rules.

### Add selected services to `AvailabilityRepository`

Rejected. The repository owns source evidence by movie and region. Provider
selection is a viewer-specific Domain eligibility rule and must not contaminate
the evidence cache key or Data boundary.

### Add profile methods to existing `LocalStore`

Rejected. `LocalStore` already combines Watchlist and Search History. Extending
it would create a broad persistence service and make whole-envelope
profile/draft transitions harder to model and test independently.

### Store profile and draft under separate keys

Rejected. Recalibration completion and reset would require multiple logical
updates and could expose an intermediate combination between them.

### Replace UserDefaults with SwiftData or a database

Rejected for v1. The aggregate is small, local, single-writer, and replaced as
one encoded value. A database adds migration and concurrency complexity without
an observed need.

### Gate the app whenever any draft exists

Rejected for recalibration. A valid completed profile remains usable while its
replacement is incomplete. First onboarding still gates because no usable
profile exists.

### Use a Discover toolbar action for Preferences

Rejected. Discover will stop being the primary surface in Milestone 6, making
the entry temporary and requiring another navigation migration.

### Calibration knowledge and Watchlist

An informative calibration reaction preserves evidence that the viewer saw the
movie during calibration. It does not become the movie's global definitive
watched state and does not mutate Watchlist or Movie Detail in Milestone 5.
Those existing surfaces may therefore remain temporarily independent.

Milestone 6 must combine the four informative calibration reactions with the
existing Watchlist watched state to exclude previously seen movies from Three
for Tonight. A unified viewing-history model and synchronization between these
surfaces remain outside Milestone 5.

#### Accepted Milestone 7 supersession

ADR-012 replaces this temporary separation. Informative
calibration responses become Movie reactions and watched facts in unified
Viewer Movie State. Recalibration upserts only informative responses;
`Haven't seen it`, `Don't know it`, and movies omitted from the frozen catalog
do not erase historical feedback. Watchlist remains independent future intent
for an unwatched movie rather than a watched-state container.

The v2 completed Viewer Profile retains region, selected services, lifecycle,
and the last completed catalog reference but drops the legacy reaction map.
Current Movie reactions then have exactly one persisted owner.

ADR-012 also moves the completed profile, drafts, and per-movie state into one
versioned Application Support envelope with active, previous-valid, quarantine,
and legacy recovery. That successor preserves ADR-010's single-owner,
whole-envelope publication guarantee while adding recovery that the
UserDefaults v1 API could not provide.

## Consequences

### Positive

- One authoritative local profile drives onboarding, future ranking, and
  availability context.
- Profile replacement and draft progress have explicit serialized-envelope
  semantics.
- Recalibration cannot own or restore stale service selection.
- Existing Watchlist and Search History remain independent.
- Service edits take effect predictably without unnecessary TMDB requests.
- Corrupt and unsupported data cannot silently become an empty/default profile.
- Milestone 6 receives raw, versioned reactions and an honestly calculated
  confidence count.
- Architecture remains layered and testable under Swift 6.

### Costs

- Startup gains an asynchronous state-resolution phase.
- Persisted state needs explicit schema decoding, invariant validation, and
  recovery UI from the first version.
- Recalibration requires profile and draft coexistence rather than a single
  simple record.
- `CheckMovieAvailability` gains a Domain dependency on current-context
  resolution.
- The accepted fifth tab consumes permanent primary-navigation space.

### Risks and mitigations

- **Risk:** a persisted catalog position conflicts with stored reactions.
  **Mitigation:** validate both against the versioned catalog on every load and
  completion.
- **Risk:** automatic final persistence fails after the last valid action.
  **Mitigation:** preserve the completed draft, keep Presentation on the current
  onboarding state with retry, and route into the application only after a
  successful repository result.
- **Risk:** service change causes unnecessary network requests.
  **Mitigation:** preserve evidence cache key as movie plus region.
- **Risk:** recalibration weakens a usable profile before completion.
  **Mitigation:** keep active profile until whole-envelope replacement
  completes.
- **Risk:** a service edit races with recalibration completion.
  **Mitigation:** serialize both operations and compose completion from the
  active profile inside the replacement operation; the calibration-only draft
  has no service fields to restore.
- **Risk:** future schema update silently loses data.
  **Mitigation:** explicit version dispatch and migration registry.
- **Risk:** Settings becomes overcrowded later.
  **Mitigation:** keep v1 limited to Preferences and About; reassess from
  observed use rather than introduce a generic navigation framework.

## Acceptance Record

The architecture and its documentary prerequisites are accepted:

1. the isolated Milestone 4 documentary closure was merged in PR #19;
2. PR #18 was updated onto the resulting `develop` state;
3. the resulting Milestone 4, ADR-009, Milestone 5, and ADR-010 boundaries were
   confirmed conflict-free;
4. ADR-010, Milestone 5, roadmap, backlog, and the PR description were moved to
   the accepted state together.
5. The Product Owner accepted automatic completion after physical-device
   validation on 2026-08-03; it changes orchestration only and leaves this
   persistence architecture intact.

## Related Documents

- [`PRODUCT.md`](../../PRODUCT.md)
- [Product Language Glossary](../product/product-language-glossary.md)
- [Milestone 7 — Continuous Taste Learning](../milestones/milestone-7-continuous-taste-learning.md)
- [ADR-012 — Unified Local Viewer Movie State](adr-012-unified-local-viewer-movie-state.md)
- [ADR-013 — Remote Calibration Catalog](adr-013-remote-calibration-catalog.md)
- [Milestone 5 — Viewer Profile & Onboarding](../milestones/milestone-5-viewer-profile-onboarding.md)
- [ADR-009 — Availability Boundary and Verification](adr-009-availability-boundary-verification.md)
- [Architecture Skeleton](../architecture/architecture-skeleton.md)

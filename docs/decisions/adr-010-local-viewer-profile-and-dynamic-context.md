# ADR-010 — Local Viewer Profile and Dynamic Viewing Context

## Status

Proposed — requires architecture review before Milestone 5 implementation

## Context

Milestone 4 introduced a dedicated availability boundary with evidence cached
by movie ID and viewing region. The pilot currently constructs
`CheckMovieAvailability` with immutable
`AvailabilityViewingContext.spainPilot`, which selects all allowlisted services
for the lifetime of `AppContainer`.

Milestone 5 introduces one editable local viewer profile. It must persist:

- fixed Spain region;
- selected supported services;
- versioned calibration reactions and signal count;
- completed onboarding state;
- resumable onboarding or recalibration progress.

The profile becomes the current source of availability context. A service edit
must affect every availability check started after the save without discarding
fresh TMDB evidence. The system must also distinguish absent, incomplete,
unsupported, corrupt, and transiently unavailable state without silently
manufacturing a default profile.

The profile and onboarding draft have different lifecycles. During first
onboarding there is no completed profile. During recalibration, a completed
profile must remain active while a replacement draft is saved. Completion must
replace the profile and remove the draft atomically.

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
OnboardingDraft
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
- reactions keyed by TMDB movie ID;
- informative-signal count;
- completed onboarding state.

An `OnboardingDraft` contains:

- draft schema version;
- calibration catalog version;
- current flow step;
- selected service IDs;
- reactions keyed by TMDB movie ID;
- informative-signal count;
- current ordered catalog position;
- optional-extension state.

Domain validates:

- region is supported;
- at least one selected service is allowlisted before completion;
- reaction IDs belong to the stored catalog version;
- response values are recognized;
- informative count equals the three informative reaction cases;
- current position and extension state are valid for the catalog;
- a completed profile cannot claim incomplete onboarding.

Invalid invariants are not repaired by guessing.

### Repository operations

The Domain repository supports behavior equivalent to:

```text
loadState()
saveDraft(draft)
complete(profile, replacingDraft)
updateServices(selection)
resetDraft()
resetProfileAndDraft()
```

Operations may be grouped differently if atomicity and distinct outcomes remain
explicit. Errors must distinguish at least:

- unsupported schema;
- corrupt or invariant-invalid data;
- transient read failure;
- transient write failure.

Repository operations are serialized under one concurrency owner.

### Single persisted state envelope

Persist one encoded envelope under one dedicated local key. The envelope can
contain both:

- an optional completed profile;
- an optional onboarding or recalibration draft.

Conceptually:

```text
ViewerStateEnvelopeV1
├── envelopeSchemaVersion
├── completedProfile?
└── onboardingDraft?
```

The envelope enables these valid combinations:

| Completed profile | Draft | Meaning |
| --- | --- | --- |
| No | No | First launch/profile absent |
| No | Yes | Incomplete first onboarding |
| Yes | No | Normal completed state |
| Yes | Yes | Active profile plus replacement recalibration draft |

Write the complete encoded envelope as one UserDefaults `Data` value. Do not
store profile fields, reactions, signal count, or draft progress in separate
keys that can be partially updated.

UserDefaults is accepted for this small local pilot aggregate. A database or
file-based store is not justified by the current scale.

### Atomicity

Atomic means that readers observe either the last complete encoded envelope or
the next complete encoded envelope, never a partially updated aggregate.

Required transitions:

- first-onboarding change: replace envelope with updated draft;
- first completion: replace draft-only envelope with profile-only envelope;
- begin recalibration: replace profile-only envelope with profile-plus-draft;
- recalibration change: replace only the draft inside a full envelope;
- recalibration completion: replace profile-plus-draft with replacement
  profile-only envelope;
- reset draft: remove only draft and preserve profile;
- reset profile: remove both profile and draft.

Encoding completes before replacing the stored value. A failed encode or write
leaves the previous persisted bytes unchanged.

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

The catalog identity, order, TMDB IDs, fallback English titles, and years are
bundled deterministic product data. Domain receives an immutable catalog value
through composition. No remote response may change its membership or order.

Existing movie/catalog infrastructure may hydrate artwork and metadata. Failed
hydration falls back to bundled display data and does not change catalog
identity or block reaction entry.

No generalized remote configuration or catalog-management abstraction is
introduced.

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

### Stable Preferences entry

Propose a fifth main `Settings` tab containing Preferences and About.

Rationale:

- it remains stable when Home replaces Discover;
- it avoids duplicating a toolbar action across tab navigation stacks;
- it does not imply account or multi-profile identity;
- it gives attribution and recovery-related settings a permanent home.

The current Discover-specific About action moves to Settings. The exact tab
decision remains subject to Product Owner review before this ADR is accepted.

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
it would create a broad persistence service and make atomic profile/draft
transitions harder to model and test independently.

### Store profile and draft under separate keys

Rejected. Recalibration completion and reset could leave partial state after
one successful write and one failed write.

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

## Consequences

### Positive

- One authoritative local profile drives onboarding, future ranking, and
  availability context.
- Profile replacement and draft progress have explicit atomic semantics.
- Existing Watchlist and Search History remain independent.
- Service edits take effect predictably without unnecessary TMDB requests.
- Corrupt and unsupported data cannot silently become an empty/default profile.
- Milestone 6 receives raw, versioned reactions and an honest confidence count.
- Architecture remains layered and testable under Swift 6.

### Costs

- Startup gains an asynchronous state-resolution phase.
- Persisted state needs explicit schema decoding, invariant validation, and
  recovery UI from the first version.
- Recalibration requires profile and draft coexistence rather than a single
  simple record.
- `CheckMovieAvailability` gains a Domain dependency on current-context
  resolution.
- A fifth tab consumes permanent primary-navigation space unless the proposal
  is revised during review.

### Risks and mitigations

- **Risk:** profile and informative count diverge.
  **Mitigation:** validate count against reactions on every load and completion.
- **Risk:** service change causes unnecessary network requests.
  **Mitigation:** preserve evidence cache key as movie plus region.
- **Risk:** recalibration weakens a usable profile before completion.
  **Mitigation:** keep active profile until atomic replacement succeeds.
- **Risk:** future schema update silently loses data.
  **Mitigation:** explicit version dispatch and migration registry.
- **Risk:** Settings becomes overcrowded later.
  **Mitigation:** keep v1 limited to Preferences and About; reassess from
  observed use rather than introduce a generic navigation framework.

## Validation Required for Acceptance

Before changing this ADR to `Accepted`, confirm:

1. the single-envelope model satisfies first onboarding and recalibration;
2. preserving the active profile during recalibration is the desired product
   behavior;
3. current-context resolution inside availability orchestration is preferable
   to caller-provided context;
4. the fifth `Settings` tab is an acceptable stable navigation cost;
5. calibration reactions should remain separate from Watchlist mutations;
6. bundled catalog fallback metadata is acceptable when TMDB hydration fails.

## Related Documents

- [`PRODUCT.md`](../../PRODUCT.md)
- [Milestone 5 — Viewer Profile & Onboarding](../milestones/milestone-5-viewer-profile-onboarding.md)
- [ADR-009 — Availability Boundary and Verification](adr-009-availability-boundary-verification.md)
- [Architecture Skeleton](../architecture/architecture-skeleton.md)

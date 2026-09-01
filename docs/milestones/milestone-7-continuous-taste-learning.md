# Milestone 7 — Continuous Taste Learning

## Status

`Reopened — P0 correction accepted; implementation pending; final approval
blocked`

- Product direction accepted: `2026-08-19`
- `My movies` label accepted: `2026-08-24`
- Final D0 product and engineering acceptance: `2026-08-24`
- D0 and PR1 through PR9 merged as PRs #32–#42
- PR4 physical migration validation passed on the Product Owner's iPhone
- PR10 (#43) merged on `2026-08-31` as merge commit `546c24e`
- Final physical validation on `2026-09-01` found a reproducible P0 exhaustion
  defect; M7 is formally reopened and M8 must not begin
- Corrective D0 and three implementation slices are specified in
  [Milestone 7 P0 — Home Exhaustion Recovery](milestone-7-p0-home-exhaustion-recovery.md)
- A new integration-and-closure PR plus physical validation on the preserved
  blocked installation are required for final approval
- Dependency satisfied: Milestone 6 and its explanation correction are merged
  into `develop`.

## Identifiers and authority

- Roadmap: Milestone 7
- Backlog: IMP-004 and IMP-022
- Local state architecture:
  [ADR-012 — Unified Local Viewer Movie State](../decisions/adr-012-unified-local-viewer-movie-state.md)
- Catalog architecture:
  [ADR-013 — Remote Calibration Catalog with Frozen Local Fallback](../decisions/adr-013-remote-calibration-catalog.md)
- Decision Engine architecture:
  [ADR-011 — Deterministic Decision Engine v1](../decisions/adr-011-deterministic-decision-engine-v1.md)
- P0 history and recovery architecture proposal:
  [ADR-014 — Bounded Recommendation Suppression and Exhaustion Recovery](../decisions/adr-014-bounded-recommendation-suppression-and-recovery.md)
- Product language:
  [Product Language Glossary](../product/product-language-glossary.md)
- Product authority: [`PRODUCT.md`](../../PRODUCT.md)
- Engineering authority: [`ENGINEERING.md`](../../ENGINEERING.md)

If this specification conflicts with `PRODUCT.md` about behavior,
`PRODUCT.md` wins. If it conflicts with `ENGINEERING.md` about technical
invariants, `ENGINEERING.md` wins. The accepted ADRs own the persistence,
migration, catalog, and Decision Engine boundaries.

## Completion record

- Delivery: original D0 and PR1 through PR10 merged as PRs #32–#43.
- Product result: one recoverable Viewer Movie State now drives Detail,
  Watchlist, `My movies`, calibration, Taste Profile, and Home reconciliation;
  the calibration catalog resolves remote, cache, then bundled and freezes the
  exact chosen snapshot.
- Upgrade evidence: the PR10 composed integration test migrates a final-M6-
  shaped profile, Watchlist, Search History, and Decision Set v1 together,
  preserves trusted shown history, publishes v2 against the migrated snapshot,
  and proves an exact repository relaunch without a second migration.
- End-to-end evidence: the simulator smoke covers onboarding, every main tab,
  Detail feedback, Home update copy, Watchlist-to-`My movies` movement, history
  editing, attribution, and close/resume/complete recalibration.
- Automated evidence: focused integration and UI validation pass. The final
  local `make verify` passed on `2026-08-31` with 500 tests in 90 suites, the
  single milestone UI smoke, static analysis, Release build, and app-bundle
  inspection all green.
- Device evidence: PR4 already validated installed-state migration on the
  Product Owner's iPhone. On `2026-08-31`, the PR10 candidate also built,
  installed, and launched successfully on that iPhone without resetting its
  application data. The remaining final-SHA functional checklist and enriched
  household utility checkpoint are external approval gates and are not
  inferred from simulator automation.
- Reopening evidence: the retained pilot installation reached a persisted
  zero-result Home after normal feedback. Read-only inspection found 93 shown
  IDs, 47 watched IDs, 113 IDs in their union, and an empty current Decision
  Set. Repeated refresh and preference reset could not recover because every
  cycle inherited permanent shown exclusion inside a six-page recall boundary.
  This invalidates the original closure claim without invalidating the prior
  migration, feedback, catalog, or automated evidence.

## Goal

Give PickOne a coherent, editable source of explicit movie knowledge so the
deterministic recommender can learn continuously after onboarding without
changing P1, adding session context, or introducing AI.

The Viewer can record watched state, rate watched movies, reject an unwatched
title as `Not interested`, and edit that state later. The same current evidence
drives Movie Detail, `My movies`, Watchlist projections, calibration, Home
eligibility, and the derived Taste Profile.

The milestone also replaces the hardcoded calibration list as the only source
with a validated remote HTTPS catalog, while keeping exact frozen, cached, and
bundled fallback behavior.

## User outcomes

After Milestone 7:

- Movie Detail shows and edits the current state for any movie;
- watched is available independently of Watchlist;
- reactions are no longer limited to onboarding;
- `Not interested` excludes a title without pretending the Viewer watched or
  disliked its genres;
- Settings exposes one history of ratings, watched-only movies, and `Not
  interested` titles, with Movie Detail as the single editing surface;
- Home reflects successful changes immediately, suppresses recent repetition,
  and can deliberately recover older shown titles that have no explicit
  feedback after never-shown and expanded recall are insufficient;
- Home offers quick explicit feedback from each recommendation card;
- onboarding and recalibration use a remotely manageable catalog when valid,
  with at most two visible seconds before cached or bundled fallback;
- existing household pilot data survives installation and migration.

## Preconditions

### Milestone 6 explanation correction — satisfied

Milestone 6 cannot close until its final implementation satisfies:

- only `Love it` and `Like it` may produce a visible positive anchor;
- candidate and anchor share at least one genre;
- genre Jaccard similarity is at least `1/3`;
- era may reinforce but never qualify an anchor;
- copy enumerates only genuine shared signals;
- retained recommendation evidence is validated against the current reaction;
- the Deadpool–Parasite fixture never produces anchor explanation evidence.

This changes explanation admission and validation, not the P1 scoring formula.
The correction was implemented and merged with Milestone 6. Milestone 7 does
not modify it.

### Original D0 gate — satisfied

Milestone 6 is merged, the documentation branch is rebased onto its resulting
`develop`, completion records preserve the explanation correction, and this
milestone plus ADR-012/ADR-013 are accepted together. PR1 remains gated only on
the merge of this documentation-only D0 branch.

## Scope

### Included

- unified Viewer Movie State and transition rules;
- versioned local persistence, migration, previous-valid recovery, quarantine,
  and explicit destructive last-resort reset;
- watched and Watchlist decoupling across existing surfaces;
- Movie reactions and `Not interested` in Movie Detail;
- `My movies` history in Settings with editing through Movie Detail;
- P1 input from the union of current reactions;
- human-readable recommendation evidence with no internal genre-ID copy;
- deterministic, cancellable, all-or-nothing Taste Profile hydration;
- stable title exclusion for `Not interested`;
- immediate Home repair or regeneration after state changes;
- complete shown-history preservation plus bounded recent suppression across
  reaction-driven cycle changes;
- progressive recall, deterministic rollover, and typed exhausted outcomes;
- quick explicit feedback from every Home recommendation card;
- remote calibration catalog, explicit cache, bundled fallback, and frozen
  drafts;
- full automated, CI, upgrade, and physical-device validation;
- documentary closure in the final implementation PR.

### Explicitly excluded

- P1 weights, thresholds, quality formula, diversity penalty, or tie-breaking
  changes;
- AI, LLMs, embeddings, collaborative filtering, or title-specific scoring;
- quick viewing context, mood, runtime intent, or `Not tonight`;
- `Watch this`, viewing confirmation, or measurement events;
- accounts, backend user data, cloud sync, or household profiles;
- explicit rewatch intent;
- public catalog administration UI;
- automatic feedback from impressions, Detail opens, trailers, or handoff;
- remote feature flags or remote engine configuration;
- a new physical Swift module or package.

## Product semantics

### Viewer Movie State

One validated state exists per positive TMDB movie ID. It represents separately:

- Watch state;
- one optional Movie reaction or `Not interested` preference;
- one optional Watchlist intent;
- display metadata and explicit-state change time.

The exact invariants and transition table are canonical in ADR-012. Important
observable rules are:

- reaction means watched and removes Watchlist intent;
- changing a reaction replaces it;
- removing a reaction keeps watched;
- `Not interested` is available only while unwatched and removes Watchlist;
- watched removes `Not interested` and Watchlist;
- unwatched removes reaction and never restores an earlier Watchlist intent;
- saving to Watchlist requires unwatched and clears `Not interested`;
- removing from Watchlist changes no other state;
- no automatic rewatch meaning is inferred.

An unwatched movie with no preference or Watchlist intent is represented by an
absent record rather than an empty tombstone. Watched without a rating remains
a meaningful persisted state.

Repeated valid actions are idempotent. Assigning the same rating, marking an
already watched movie as watched, saving an already saved movie, removing an
absent Watchlist intent, or undoing state that is already absent leaves
semantic state unchanged.
Such an action preserves `stateChangedAt`, Watchlist `addedAt`, and
`ViewerStateSnapshotID`, produces no Home update, and never creates an empty
tombstone. Invalid actions remain typed rejections rather than no-ops.

`It was okay` is informative watched evidence with value `0`. It is not
positive, negative, or a positive anchor.

The v2 Viewer Profile contains region, selected services, lifecycle, and last
completed catalog reference but no reaction map. Viewer Movie State is the only
persisted owner of current Movie reactions. Taste Profile is derived from that
projection and never persisted.

### Calibration and continuous feedback

First onboarding imports its four informative responses as current Movie
reactions. Recalibration upserts only informative responses for the movies it
actually presents.

`Haven't seen it` and `Don't know it`:

- remain valid calibration responses;
- advance the accepted calibration flow;
- do not create Taste evidence;
- do not change watched;
- do not remove historical rating, `Not interested`, or Watchlist state;
- do not delete feedback for titles absent from recalibration.

When a catalog presents a movie with a current reaction, calibration may show
that reaction as existing context and lets the Viewer confirm or replace it.
It is not copied into the draft or counted toward this flow until the Viewer
responds. A new informative response upserts it; `Haven't seen it` or `Don't
know it` records progress for this flow while leaving the historical reaction
authoritative.

### Reset preferences

The existing confirmed `Reset preferences` action:

- removes ratings and `Not interested`;
- preserves watched facts;
- preserves Watchlist intent;
- removes active profile and calibration draft;
- preserves Search History;
- starts a fresh recommendation-suppression epoch while preserving complete
  diagnostic shown history;
- returns the application to first onboarding.

The destructive recovery reset is a different action with broader copy and is
available only when active, previous, and legacy sources all fail.

## Domain design

### Values

Add immutable `Sendable` values equivalent to:

```text
ViewerMovieState
MovieReaction
MoviePreference
MovieWatchState
WatchlistIntent
MovieFeedbackMetadata
ViewerStateSnapshotID
ViewerMovieStateSnapshot
ViewerMovieStateTransition
ViewerMovieStateChange
ViewerMovieStateLoadState
ViewerMovieStateRecoveryReason
```

The transition value expresses user intent, not storage operations. Domain
applies it through one pure reducer that either returns a complete valid next
state and semantic change impact or a typed rejection.

Change impact distinguishes:

- `tasteChanged`: rating added, changed, or removed;
- `eligibilityChanged`: watched or `Not interested` changed;
- `watchlistIntentChanged`;
- `none` for metadata-only or semantic no-op results.

One transition receives exactly one highest-priority recommendation impact:
`tasteChanged` wins over eligibility and Watchlist effects;
`eligibilityChanged` wins over Watchlist-only effects. Assigning a rating to a
saved unwatched movie therefore produces one `tasteChanged` result even though
it also marks watched and removes Watchlist. Domain returns the complete new
state so every lower-priority field effect is still persisted atomically.
For `none`, the repository returns the current state or continued absence and
the current snapshot identity without replacing the envelope. A metadata-only
refresh may persist separately while preserving state time, snapshot identity,
and Home state.

### Repository capabilities

`ViewerMovieStateRepository` supports behavior equivalent to:

```text
loadState() async -> load state
snapshot() async throws -> identified snapshot
state(movieID) async throws -> ViewerMovieState?
apply(transition, metadata) async throws -> ViewerMovieStateChange
```

Cross-aggregate lifecycle changes use a separate capability equivalent to:

```text
ViewerStateLifecycleRepository
completeCalibration(completion, expectedSnapshotID) async throws
    -> ViewerStateCommit
resetPreferences(expectedSnapshotID) async throws
    -> ViewerStateCommit
```

`CalibrationCompletion` contains the completed profile fields and Domain-
resolved informative reaction upserts. `ViewerStateCommit` returns the committed
profile state and Viewer State snapshot identity. The same Data actor implements
these capabilities and the existing `ViewerProfileRepository` adapter over one
envelope; no use case attempts a profile write followed by a separate movie-
state write.

Watchlist and `My movies` use focused Domain projections over the same snapshot;
they do not own alternate persistence.

Repository errors distinguish invalid transition, corrupt data, unsupported
schema, migration failure, encoding failure, replacement failure, and stale
snapshot identity where applicable.

### Use cases

Introduce focused capabilities equivalent to:

- `GetViewerMovieState`;
- `UpdateViewerMovieState`;
- `GetWatchlist` over Watchlist intent;
- `GetMyMovies` over reactions, watched-only, and `Not interested`;
- `CompleteCalibration` for one serialized profile/movie-state replacement;
- `ResolveCalibrationCatalog`;
- existing availability and Movie Detail use cases remain separate.

Presentation receives Domain values and never reconstructs movie metadata from
formatted strings. This milestone resolves the relevant IMP-007 boundary for
the modified Movie Detail actions.

## Persistence and migration

ADR-012 defines the storage contract. Milestone acceptance additionally
requires:

- one actor owns the active local viewer-state envelope;
- one previous valid copy is retained;
- exact corrupt or incompatible bytes are quarantined;
- legacy Viewer Profile and Watchlist bytes remain read-only recovery inputs;
- Search History remains in its existing independent store;
- no read path catches corruption and returns an empty valid collection;
- a truly fresh install with no current or legacy bytes creates an explicit
  valid profile-absent envelope, while any failed source blocks that path;
- a successful mutation is observable only after the complete envelope is
  persisted;
- migration is complete before Home, Detail, Watchlist, Settings, or calibration
  may consume state.

### Upgrade behavior

On the first Milestone 7 launch:

1. root routing enters local-state resolution;
2. use active v2 if valid;
3. otherwise try previous valid v2;
4. otherwise migrate profile v1 and Watchlist v2;
5. publish the main app or onboarding only after a valid active v2 exists;
6. preserve all sources and show blocking recovery if no safe state can be
   produced.

Viewer-state migration does not delete or overwrite the Decision Set. Home
later runs the explicit Decision Set v1-to-v2 migration below against the new
trusted snapshot identity.

Supported legacy profile and draft catalog versions map through an explicit
registry to the exact bundled snapshot. Draft progress and its first-onboarding
versus recalibration service ownership are preserved. Unknown catalog versions
fail migration; they never resume against a different remote catalog.

### Decision Set v1-to-v2 migration

The final Milestone 6 store contains `DecisionSetEnvelopeV1`, whose cycle owns
valuable shown history but whose schema has no Viewer State snapshot identity.
Milestone 7 introduces `DecisionSetEnvelopeV2` with
`sourceViewerStateSnapshotID`.

A semantically valid v1 envelope is supported legacy data, not corrupt data and
not a publishable current set. Reconciliation must:

1. preserve its exact bytes as a read-only migration source until v2 persistence
   succeeds;
2. carry every v1 `shownMovieID` forward;
3. recompute the cycle signature from the migrated current inputs;
4. retain the cycle ID when that signature matches, or create a successor cycle
   with the same inherited shown history when it differs;
5. regenerate recommendations without publishing the old v1 recommendations;
6. persist the complete v2 envelope with the current Viewer State snapshot
   identity before publication.

Regeneration or persistence failure keeps the exact v1 bytes and shows Retry.
Corrupt or unsupported v1 bytes follow the existing exact-byte quarantine path;
no implementation may partially decode or guess shown history from invalid
data. A genuinely absent v1 store starts with empty history. Recommendation
recovery never mutates Viewer Profile, Viewer Movie State, Watchlist, or Search
History.

## Decision Engine and Home

### Taste input

P1 builds its `TasteProfile` from every current Movie reaction, whether its
source was onboarding, recalibration, Movie Detail, or `My movies`.

- values remain `+1.00`, `+0.50`, `0.00`, and `-0.75`;
- `It was okay` contributes an observation but not directional confidence;
- only `Love it` and `Like it` may be positive anchors;
- `Not interested` never contributes genre or era affinity;
- watched and `Not interested` are title eligibility exclusions;
- Watchlist remains the accepted `+2` intent bonus only.

No hidden weights or title exceptions are added.

### Taste metadata hydration

Every current Movie reaction participates in one complete P1 Taste Profile.
Movie metadata hydration is not candidate-specific enrichment: silently
dropping one failed reaction would change affinities, confidence, scoring, and
explanations while retaining the same trusted state identity. PickOne therefore
does not construct or publish a degraded Taste Profile in Milestone 7.

Hydration follows these accepted rules:

- sort reaction movie IDs ascending before scheduling work;
- hydrate through the existing `MovieRepository` cache boundary;
- use structured concurrency with at most four hydration operations in flight;
- retain the original sorted index and assemble final evidence in that order,
  independent of task completion order;
- propagate caller cancellation to every child task without detached work;
- collect non-cancellation failures by index and report the lowest-ID failure
  deterministically after the bounded work completes;
- invoke P1 only when every current reaction has valid matching movie metadata.

If complete hydration fails, generation fails as a typed retryable input error.
The coordinator may retain only a previously persisted Decision Set that Domain
proves safe under the current Viewer State snapshot; otherwise Home shows
Retry. It never invokes P1 with a subset, fabricates empty evidence, or presents
the result as reduced-confidence personalization. Candidate-specific metadata
or availability enrichment keeps ADR-011's independent per-candidate behavior.

### Human-readable genre evidence

TMDB genre IDs remain valid internal identity for equality, Jaccard, affinity,
and persistence validation. They are not user-facing labels.

For a positive anchor, shared genre evidence uses the human-readable name from
the hydrated anchor/Taste Profile metadata for the same genre ID. Positive
genre-affinity evidence resolves names from the same complete hydrated Taste
Profile. Resolution is deterministic by genre ID and must not depend on task,
set, or dictionary iteration order.

New structured explanation evidence must carry readable names for every genre
it proposes to render. Presentation has no numeric fallback. Persisted evidence
that cannot provide a readable label for its claimed genre signal is not
publishable as-is and must be repaired or regenerated while preserving cycle
shown history. This correction changes neither P1 scoring nor the accepted
positive-anchor threshold.

### Snapshot identity and stale work

Every trusted input snapshot includes the persisted non-reusable
`ViewerStateSnapshotID` covering current completed-profile inputs and Viewer
Movie State.
Generation, refresh, repair, migration reconciliation, and publication capture
that identity. The coordinator checks it before persistence and again before
publication. An obsolete operation cannot be accepted as the current or visible
Decision Set.

Draft-only progress and metadata hydration preserve the identity. A successful
service edit, calibration completion, rating, watched, Watchlist, `Not
interested`, or reset transition receives a fresh identity whenever current
recommendation inputs change.

An already-satisfied repeated action is not an input-changing commit. It keeps
the current identity and causes no repair, regeneration, or transient Home
feedback.

The Decision Set envelope stores the source Viewer State snapshot identity. If
state changes between the pre-persistence check and the write, the post-write
check rejects the result from publication and immediately schedules work for
the newest identity. Restoration also compares the stored source identity with
current state before rendering. A stale envelope is incompatible with current
inputs, not corrupt user data, and is regenerated without discarding cycle
history.

The identity is opaque and compared only for equality. It is never derived from
a numeric counter. Every recommendation-input-changing commit, legacy
migration, and previous-copy recovery publication receives a new identity that
must not be reused. Recovering older state therefore cannot make a Decision Set
from its earlier active lifetime appear current.

One actor remains the authoritative owner of Decision Set mutation. The
existing coordinator must not gain another large responsibility: trusted-state
loading, change classification, and reaction-driven cycle transition are
extracted behind focused Domain collaborators as part of the integration PR.

### Repair, regeneration, and exhaustion recovery

- Watchlist, watched, and `Not interested` changes repair current eligibility
  without changing cycle identity and without erasing complete shown history.
- A Movie-reaction change derives a new Taste Profile and cycle identity.
- If one atomic action changes a Movie reaction plus watched or Watchlist, the
  taste change has precedence and produces only the new-cycle path; it never
  first publishes an eligibility repair.
- The new cycle preserves complete diagnostic history and carries the bounded
  recent-suppression policy defined by ADR-014.
- A reaction applied to a current recommendation removes that title, rebuilds
  the other visible titles against the new Taste Profile, retains those that
  remain eligible, credible, and explainable, and fills only missing slots.
- Watched and `Not interested` are title-local repairs that normally replace
  only the affected card. `Not interested` never changes Taste Profile.
- Every replacement first prioritizes never-shown titles, then expands recall,
  then releases the oldest non-active recent suppression in the accepted
  deterministic increments. Active cards never repeat.
- A successful one- or two-title result and a successful zero-title exhausted
  outcome are distinct from failure and are persisted against the exact trusted
  inputs, search policy, and completion time. Home never repeats an operation
  already known to produce the same empty result while that evidence is less
  than 24 hours old; expiry restores one explicit full-strategy request.
- Other valid recommendations may remain only when their evidence is rebuilt
  and valid under the new snapshot; stale explanation evidence is never
  retained.
- Failure retains only a snapshot Domain still proves safe and exposes Retry.

The exact recent window, recall stages, rollover, v2-to-v3 migration, terminal
copy, and quick-feedback interaction are accepted together in ADR-014 and the
P0 correction specification. P0-1 becomes implementation-ready when D0 merges.

### Presentation feedback

After a successful change causes Home to update, Home shows discreet transient
copy:

> Recommendations updated.

It must not block interaction, claim that every recommendation changed, or
appear before the new Decision Set has been safely persisted and published.
No animation system or progress redesign is introduced.

Every Home recommendation also exposes the accepted P0 quick-feedback menu as
a separate trailing control. It offers the four reactions, `Already watched`,
and `Not interested` without requiring Detail navigation. Mutation progress is
local to that card; failure preserves the card and offers retry. Movie Detail
and `My movies` remain the surfaces for undo and full editing.

## Movie Detail

Movie Detail loads detail, availability, and Viewer Movie State independently.
Movie content remains usable when feedback state cannot load, but feedback
controls show their own retryable failure and must not permit unsafe writes.

### Controls

One viewed-movie group offers:

- `Love it`;
- `Like it`;
- `It was okay`;
- `Didn't like it`;
- change current reaction;
- remove current reaction;
- mark watched or unwatched.

`Not interested` is visually separate and available only for an unwatched
movie. It supports undo.

Watchlist remains a future-intent control and is available only while unwatched.
Controls update together from the new validated state returned by Domain.

### State and failure

Presentation exposes states equivalent to:

- feedback loading;
- loaded and idle;
- saving with the prior state retained;
- retryable load failure;
- non-destructive mutation failure.

Only one explicit transition is in flight per Detail model. Controls are
disabled while saving. Cancellation and stale loads cannot overwrite a newer
successful local mutation.

After successful persistence, the model publishes the returned state and sends
one typed change to Home. Failure keeps the last confirmed state and does not
notify Home.

## Watchlist presentation

At Milestone 7 completion, Watchlist shows only unwatched movies with current
Watchlist intent. It no longer contains a watched section or treats watched as
a property of a saved row. Tapping a Watchlist row opens Movie Detail, where
marking it watched removes it from Watchlist and makes it appear in `My movies`.

PR3 may keep the existing watched projection as a temporary compatibility view
while production storage is cut over. PR7 introduces `My movies` and removes
that compatibility section in the same PR so watched history is never left
without a visible destination on `develop`.

## Settings history

### Name

The accepted final user-facing name is **My movies**.

Rationale:

- it naturally includes ratings, watched-only titles, and `Not interested`;
- `My movie feedback` incorrectly excludes watched-only state;
- `My movie activity` sounds like an event log or analytics surface;
- Watchlist remains unambiguously reserved for future intent.

The Product Owner accepted this label on 2026-08-24. Changing it later is a
Presentation copy decision and does not change the Domain contract.

### Content

Settings adds a `My movies` destination containing:

- every current Movie reaction;
- every watched movie without a reaction;
- every current `Not interested` movie;
- no Watchlist-only rows.

Each row uses TMDB movie ID identity and stored title, year, and poster fallback.
Order is `stateChangedAt` descending, then lower TMDB movie ID for an exact
tie. Metadata hydration never changes `stateChangedAt` or reorders the list.

The list is a read projection, not a second feedback form. Each row shows its
current state and navigates to Movie Detail, which remains the single editing
surface for v1. No swipe action, inline picker, or duplicated feedback controls
are introduced.

State labels reuse the accepted reaction copy or exactly `Watched` and `Not
interested`. The empty-state copy is:

> Your rated, watched, and not interested movies will appear here.

All new UI copy in this milestone is English.

States are loading, empty, loaded, and blocking/retryable read failure. Detail
edits update the projection after successful persistence through the shared
repository snapshot.

## Remote calibration catalog

ADR-013 defines the complete network, cache, validation, security, and frozen
snapshot architecture.

Observable requirements:

- prefetch begins before first calibration content;
- unresolved catalog loading is visible for no more than two seconds;
- precedence is remote, then last valid cache, then bundled;
- remote failure never blocks a valid fallback flow;
- the selected complete snapshot is persisted in the draft;
- relaunch, Back, and completion use that exact snapshot;
- a late or newer remote catalog applies only to a later flow;
- historical Viewer Movie State is independent of catalog membership;
- an existing reaction is reused when its movie appears again;
- no AWS identity, API, copy, or credentials enter Domain or Presentation.

The first remote JSON mirrors the accepted bundled catalog. Future catalog
membership, order, block, or fallback changes require Product Owner approval
even though they do not require an app release. Implementation agents may add
the client, configuration seam, catalog document, and publication checklist,
but may not provision or mutate external infrastructure without separate
authorization.

## Error semantics

- missing state and valid empty state are distinct;
- corrupt and unsupported persistence are distinct and preserve bytes;
- all-source recovery failure is blocking and never becomes empty state;
- previous or recovery-time legacy rollback discloses that an earlier saved
  version was recovered; normal first migration does not show that warning;
- invalid transition is a Domain rejection, not a persistence failure;
- catalog absent, invalid, incompatible, and unavailable remain distinct;
- feedback mutation failure never triggers Home reconciliation;
- Home generation failure after a feedback change retains only proven-safe
  content and offers Retry;
- a fully evaluated zero-result outcome is typed exhaustion, not a transient
  failure, and exposes the accepted recovery navigation instead of Retry or an
  endlessly repeatable refresh; after 24 hours it permits a new explicit full
  strategy so external catalog and availability changes can be observed;
- incomplete current-reaction hydration is a retryable input failure and never
  becomes a partial Taste Profile;
- cancellation is not presented as an error;
- Search History is not reset by recommendation, feedback, catalog, or normal
  preference recovery.

## Swift 6 concurrency

- local viewer state has one actor owner;
- catalog resolution/cache has one separate actor owner;
- Decision Set mutation remains under its coordinator actor;
- Presentation models are explicitly `@MainActor`;
- cross-actor values are immutable `Sendable` snapshots and snapshot identities;
- explicit tasks preserve cancellation and stale-response checks;
- no global notification bus, global mutable profile cache,
  `@unchecked Sendable`, or actor-isolation escape hatch is introduced.

App composition may connect successful state changes to the existing Home view
model through typed callbacks. Domain, not Presentation, classifies whether a
change requires repair or taste regeneration.

## Acceptance criteria

### State and transitions

- watched is represented independently from Watchlist intent and can be
  changed from every Movie Detail; accepted transitions remove conflicting
  future intent where required.
- Every accepted transition matches ADR-012 exactly.
- Rating implies watched and removes Watchlist.
- Removing rating preserves watched.
- `Not interested` is impossible for watched and removes Watchlist.
- Saving to Watchlist clears `Not interested` and requires unwatched.
- Removing Watchlist changes no watched or preference state.
- No state supports explicit rewatch intent.
- A transition that changes reaction plus watched or Watchlist is classified
  once as `tasteChanged`; lower-priority effects never trigger a separate repair.
- Repeating the same rating, watched, Watchlist save/remove, or already-absent
  undo produces `none`, preserves state and snapshot identity, and does not
  update Home; invalid transitions remain rejected.

### Migration and recovery

- installation over M6 preserves profile, services, calibration evidence,
  Watchlist, watched, and Search History.
- active, previous, and legacy recovery order is deterministic.
- corrupt and unsupported bytes are retained exactly.
- quarantine preservation failure never overwrites its original source.
- no failure becomes a fabricated empty collection.
- destructive reset appears only after every recovery source fails.
- normal `Reset preferences` preserves watched and Watchlist.
- normal `Reset preferences` starts a new suppression epoch, clears recent
  suppression and compatible exhausted state, and preserves complete shown
  history.
- successful older-snapshot recovery shows the accepted non-blocking Settings
  review notice.
- successful previous-copy recovery receives a new snapshot identity that has
  never represented an earlier active state.
- a valid M6 Decision Set v1 preserves exact bytes and every shown ID, but none
  of its recommendations publish before regeneration and v2 persistence.
- failed v1 regeneration or v2 persistence retains the legacy source and shows
  Retry; invalid v1 bytes never provide partially guessed history.

### Feedback surfaces

- Movie Detail can inspect, create, replace, and remove each accepted state.
- final Watchlist contains only future intent and has no watched section.
- `My movies` includes ratings, watched-only, and `Not interested` exactly once
  per TMDB ID.
- deterministic order and offline metadata work without immediate TMDB access.
- successful Detail edits update `My movies` and Home; failed edits update
  neither.

### Decision Engine and Home

- P1 constants and fixtures remain unchanged except explanation-strength
  correction already closed in M6.
- all current reactions contribute with their accepted semantics.
- Taste Profile evidence is complete, ordered deterministically, and built with
  no more than four concurrent hydration operations.
- cancellation stops structured hydration work and is never shown as failure.
- recommendation copy contains human-readable genre names and never exposes raw
  genre IDs.
- `Not interested` is exclusion only and never affects affinities.
- a result built from a stale snapshot identity cannot be accepted as current or
  published; a write raced by newer state is semantically unusable and triggers
  regeneration.
- reaction changes preserve complete history, retain only recomputed valid
  unaffected cards, and fill missing slots under the new signature.
- eligibility changes repair the affected card without clearing diagnostic or
  recent history.
- active cards never repeat; recent suppression is bounded and older shown
  titles without explicit feedback become eligible only through accepted
  rollover.
- normal, expanded, and rollover recall execute deterministically in one user
  operation and never relax explicit feedback, availability, or credibility.
- a partial or zero exhausted outcome is explainable, actionable, and not
  silently recomputed until relevant inputs, policy, or its 24-hour freshness
  change.
- `Reset preferences` permits a new generation without deleting watched,
  Watchlist, Search History, or complete shown history.
- Home shows `Recommendations updated.` only after a successful publication.

### Catalog

- valid remote catalog may be used without an app release.
- visible unresolved wait is bounded to two seconds under an injected clock.
- cached and bundled fallback complete calibration offline.
- invalid or incompatible remote data is never partially admitted.
- a started flow never changes snapshot.
- historical state survives catalog rotation.
- the initial approved catalog is reachable through the configured read-only
  HTTPS pilot endpoint before milestone closure.

## Required automated tests

### Pure Domain

- every transition in the accepted table;
- every invalid state and transition;
- canonical removal of an empty unwatched record and retention of watched-only
  state;
- rating replacement and removal;
- `It was okay` neutrality and watched meaning;
- `Not interested` title exclusion without affinity change;
- Watchlist/watched decoupling;
- calibration upsert and non-informative no-op behavior;
- existing reactions require an explicit response before counting toward the
  current calibration flow;
- deterministic `My movies` ordering and projections;
- change-impact classification, including taste precedence for a rating action
  that also marks watched and removes Watchlist.
- idempotent same-rating, already-watched, repeated Watchlist save/remove, and
  absent-undo results, including preserved `stateChangedAt`, Watchlist
  `addedAt`, and absent-record canonicalization.

### Persistence and migration

- envelope round trip and semantic validation;
- profile-only, Watchlist-only, overlapping, empty-valid, and corrupt legacy
  migration;
- first-onboarding and recalibration draft migration with exact snapshot and
  position preservation;
- a corrupt present legacy source prevents partial migration while a genuinely
  absent source does not;
- deterministic migrated `stateChangedAt` and metadata refresh without history
  reordering;
- previous-valid recovery;
- exact quarantine bytes;
- unique quarantine items and quarantine-write failure;
- unsupported schemas;
- clean-install absence versus failed-source recovery;
- encoding, previous-copy, and active-replacement failures;
- concurrent serialized transitions and unique snapshot identities;
- snapshot identity persistence across relaunch, service edits, and draft-only no-op
  behavior;
- semantic no-ops preserve snapshot identity and active/previous envelope bytes;
- previous-copy recovery republishes with a new identity and can never collide
  semantically with an earlier Decision Set source identity;
- normal preference reset and destructive last-resort reset scopes;
- older-snapshot recovery notice and normal-upgrade suppression;
- repository recreation and later-build compatibility fixture.

### Decision Engine and orchestration

- input assembly uses Viewer Movie State rather than legacy reaction/Watchlist
  watched sources;
- bounded parallel Taste Profile hydration preserves ascending movie-ID order
  under out-of-order completion;
- cancellation propagates through every hydration child task;
- one or several reaction-metadata failures never invoke P1 with partial
  evidence, select the deterministic lowest-ID diagnostic, and retain only a
  proven-safe prior set;
- all four reactions retain P1 values;
- `Not interested` is absent from Taste evidence;
- reaction-driven signature transition preserves complete and recent history
  while retaining only recomputed valid visible cards;
- Watchlist/watched/`Not interested` repairs preserve cycle identity;
- multi-field reaction transitions take the new-cycle path exactly once;
- semantic no-op transitions never invoke repair, regeneration, persistence, or
  `Recommendations updated.` feedback;
- stale Viewer State snapshot identity before persistence and after persistence cannot
  publish;
- valid Decision Set v1 migration preserves all shown IDs, handles matching and
  changed cycle signatures, and publishes only a successfully persisted v2 set;
- v1 migration regeneration failure, v2 persistence failure, and corrupt-v1
  no-partial-history behavior;
- current recommendation replacement preserves valid members only when their
  evidence remains valid;
- generation and repair failure retain only safe content;
- M6 Fixtures A–M and real-profile snapshots remain green.
- production-shaped candidates containing unnamed TMDB genre IDs resolve
  anchor and affinity copy from named Taste Profile metadata;
- restored or generated explanations never render `genre <id>` or another
  internal numeric fallback.
- recent suppression stays ordered, unique, and within its accepted bound;
- progressive 6→12→20 recall, never-shown priority, three-ID oldest-first
  rollover, partial results, and typed exhaustion are deterministic;
- typed exhaustion is fresh before 24 hours, expires exactly at 24 hours, and
  never advances its timestamp after failure, cancellation, or stale work;
- the sanitized 93-shown/47-watched blocked-installation fixture migrates and
  recovers without losing any explicit exclusion or complete history;
- a prolonged mixed-feedback and relaunch sequence cannot enter a repeated
  deterministic empty loop.

### Presentation

- Detail loads feedback independently;
- controls match every state and disable invalid actions;
- mutation success, failure, cancellation, and retry;
- `My movies` loading, empty, content, Detail navigation, and failure;
- navigation Settings → My movies → Detail;
- one successful change triggers one Home update;
- `Recommendations updated.` timing and dismissal;
- Home quick-feedback menu content, accessibility, per-card progress, mutation
  success, failure, retry, and separate Detail navigation hit target;
- partial and zero exhausted copy, recovery navigation, and absence of a known
  deterministic no-op refresh;
- refresh restoration on activation or a one-shot visible deadline at the
  24-hour exhaustion boundary, without automatic background network work;
- existing availability, Watchlist, Similar Movies, and nested Detail routes
  remain operational.
- PR7 moves watched rows from the Watchlist compatibility projection to `My
  movies` without an intermediate merged state that hides them.

### Catalog

- schema and every invariant;
- over-size response and duplicate/order failures;
- remote outcome classification;
- two-second deadline;
- remote/cache/bundled precedence;
- shared prefetch and cancellation;
- late remote response affects next flow only;
- frozen draft relaunch;
- cache write failure and bundled-only offline flow;
- no credentials or user state in requests.

Every implementation PR runs focused tests and `make verify` before handoff.

## Required physical-device validation

On the Product Owner's preserved blocked iPhone installation:

- install the final correction over the existing PR #43 build without
  reinstalling or clearing application data;
- verify the v2-to-v3 migration recovers Home automatically while preserving
  profile, services, Watchlist, Search History, watched, reactions, `Not
  interested`, and complete shown history;
- verify profile, services, Watchlist, watched, and Search History survive
  migration, and Home completes v2 reconciliation without publishing a legacy
  v1 recommendation or repeating a trusted shown title;
- rate an unsaved movie from Detail and confirm watched plus no Watchlist;
- change and remove the rating and confirm watched remains;
- set and undo `Not interested` on an unwatched movie;
- save a `Not interested` movie and confirm rejection clears;
- mark a saved movie watched and confirm Watchlist removal;
- mark it unwatched and confirm Watchlist is not restored;
- confirm Watchlist shows future intent only and migrated watched rows appear
  in `My movies`;
- verify current Home recommendations prioritize never-shown titles, never
  repeat an active card, and reuse only older shown titles without explicit
  feedback after the accepted rollover boundary;
- use every quick-feedback action directly from Home;
- verify a reaction normally preserves the other valid cards and watched or
  `Not interested` normally replaces only the affected card;
- exercise repeated refresh and confirm Home either returns a usable set or one
  accepted actionable exhausted state without looping;
- confirm exhaustion blocks only immediate unchanged retries and restores
  `Give me three more` at or after 24 hours;
- exercise a twenty-page expansion and record the final-SHA device, network and
  cache conditions, request counts, maximum concurrency, time to first usable
  set, and total duration without recording movie or Viewer data;
- verify every recommendation reason uses readable genre names and never shows
  a numeric genre identifier;
- verify `Recommendations updated.` appears only after success;
- navigate from `My movies` to Detail, edit state, and confirm the history
  projection agrees after returning;
- start calibration online, offline with cache, and offline with bundled
  fallback when practical;
- terminate and relaunch during calibration and confirm exact-snapshot resume;
- install a later build and confirm envelope compatibility;
- repeat an already-satisfied rating, watched, and Watchlist action and confirm
  `My movies` order, Home content, and Home feedback remain unchanged.
- repeat the household utility checkpoint with the enriched Taste Profile.

PR4 and PR10 supplied valid historical migration evidence. PR10's later final
physical run exposed the P0 exhaustion, so M7 approval now requires the new
P0-4 integration build to pass this entire checklist on the preserved blocked
installation plus the qualitative household utility checkpoint. Automated and
simulator evidence do not substitute for that confirmation.

## Delivery slices

Each implementation PR branches from current `develop` after its dependency is
merged. No implementation PR is stacked by default. A new agent can implement
one slice from this specification and its ADR without chat history.

### D0 — Canonical specification

Deliver:

- this milestone;
- Product Language Glossary;
- ADR-012 and ADR-013;
- PRODUCT, roadmap, backlog, ADR-010, ADR-011, and debt reconciliation;
- no application code or behavior change.

D0 is accepted after M6 closure and authorizes PR1 only once this documentation
branch merges.

### PR1 — Pure Viewer Movie State

Dependencies: D0.

Deliver values, invariants, pure transition reducer, projections, change-impact
classification, idempotent no-op semantics, and exhaustive Domain tests.
Exclude persistence, existing Watchlist migration, Decision Engine, remote
catalog, and UI.

### PR2 — Local envelope, recovery, and migration

Dependencies: PR1.

Deliver the actor-owned Application Support envelope, active/previous/quarantine
recovery, legacy migration, async repository implementations, injected file-
failure seams, and exhaustive Data tests. Keep the implementation uncomposed so
the running app still uses its M6 stores. Exclude production cutover, Decision
Engine behavior, remote catalog, and new UI.

### PR3 — Local viewer-state cutover

Dependencies: PR2.

Deliver repository adapters, profile/calibration whole-envelope transactions,
Watchlist and `My movies` projections, root migration/recovery routing, app
composition, and compatibility tests while preserving existing visible
behavior. Remove production writes to the legacy profile and Watchlist stores;
retain their bytes as read-only recovery inputs. Exclude Decision Engine
changes, feedback controls, and catalog networking.

### PR4 — Decision Set v2 migration

Dependencies: PR3.

Deliver `DecisionSetEnvelopeV2`, source snapshot identity validation, supported
v1 decoding, exact legacy-byte preservation, shown-history transfer, matching
and successor-cycle migration, regeneration-before-publication, and focused
repository/coordinator tests. Cut production Decision Set persistence over to v2
without adding feedback controls, Home update copy, or catalog networking.

Delivered in PR #36 and validated on the Product Owner's iPhone.

### PR4.5 — Human-readable recommendation evidence

Dependencies: PR4.

Correct the observed production-data path where TMDB Discover candidates carry
genre IDs without names and Home renders copy such as `genre 28`. Resolve
positive-anchor and positive-affinity genre labels deterministically from the
complete hydrated Taste Profile, remove every numeric Presentation fallback,
repair or regenerate unrenderable persisted evidence without clearing shown
history, and add production-shaped Domain, persistence/orchestration, and
Presentation regression tests. Do not change P1 scoring, thresholds, roles,
Viewer Movie State input ownership, Home reconciliation, feedback controls, or
catalog networking.

### PR5 — Decision Engine and Home reconciliation

Dependencies: PR4.5.

Deliver Viewer Movie State input assembly, snapshot-identity checks,
reaction-driven successor cycles with inherited history, eligibility repair,
impact-precedence handling, coordinator collaborator extraction, transient Home
update feedback, bounded four-wide deterministic Taste Profile hydration,
all-or-nothing hydration failure behavior, and orchestration tests. Exclude
feedback controls and catalog networking.

### PR6 — Movie Detail feedback

Dependencies: PR5.

Deliver independent feedback loading, reaction/watched/`Not interested`/
Watchlist controls, typed Home change handoff, offline metadata preservation,
and focused Presentation/UI tests. Exclude Settings history.

### PR7 — `My movies`

Dependencies: PR6.

Deliver Settings navigation, deterministic history projections, current-state
labels, retry behavior, Detail route, and tests. Remove the temporary watched
section from Watchlist in the same PR. Keep editing in Detail and exclude remote
catalog work.

### PR8 — Remote catalog source, cache, and fallback

Dependencies: PR3. Delivered after PR7 to preserve the accepted sequential
workflow and avoid concurrent edits to composition/persistence.

Deliver HTTPS client, DTOs, validation, repository actor, explicit cache,
bundled resource, deadline behavior, configuration, security checks, and Data/
Domain tests. Add the initial remote JSON and publication checklist. Do not
switch onboarding or provision external infrastructure yet.

### PR9 — Calibration integration

Dependencies: PR7 and PR8.

Deliver prefetch entry points, two-second Presentation state, draft snapshot
freeze, resume, reaction reuse, recalibration upsert, fallback behavior, and
integration/UI tests.

### PR10 — Milestone integration and closure

Dependencies: PR9.

Deliver final upgrade and end-to-end coverage, documentation completion record,
roadmap/backlog/debt closure, `make verify`, green CI, physical-device evidence,
and enriched household utility checkpoint. Exclude deferred product features.

PR10 merged as PR #43 on `2026-08-31`. Its final device validation exposed the
P0 Home exhaustion defect and invalidated milestone closure. It remains useful
historical evidence and is not reverted.

### Corrective D0 — P0 exhaustion recovery

Dependencies: current `develop` at merge commit `546c24e`.

Deliver ADR-014, the executable P0 correction specification, and reconciliation
of this milestone, PRODUCT, ADR-011, ADR-012, glossary, roadmap, and backlog.
Documentation only. Acceptance and merge authorize corrective P0-1.

### P0-1 — v3 history, epoch, and migration

Dependencies: accepted corrective D0.

Deliver bounded recent history, complete diagnostic history, the suppression
epoch, typed exhausted outcome, Viewer State and Decision Set v3 schemas,
v2-to-v3 migrations, exact-byte preservation, and focused tests. Do not change
visible Home behavior yet.

### P0-2 — Progressive recovery and stable reconciliation

Dependencies: P0-1.

Deliver staged recall, never-shown priority, deterministic rollover, stable
reaction reconciliation, title-local eligibility repair, preference-reset
epoch handling, 24-hour exhaustion freshness, terminal Home behavior, a
privacy-safe request/latency diagnostics seam, and focused tests. Exclude quick
feedback controls.

### P0-3 — Home quick feedback

Dependencies: P0-2.

Deliver the accessible per-card feedback menu, local mutation progress,
retryable failure, the existing Viewer Movie State transition handoff, and UI
coverage. Do not introduce another feedback model.

### P0-4 — New integration and final closure

Dependencies: P0-3.

Deliver the sanitized prolonged-feedback regression, complete upgrade and
relaunch coverage, documentation closure, repository verification, CI evidence,
physical installation over the preserved blocked pilot state, and recorded
twenty-page device request/latency evidence. M7 and its utility checkpoint can
close only in this new PR after Technical Lead review and Product Owner
acceptance of the observed wait.

## Dependency graph

```text
Original M7 PR1–PR10 merged, ending at PR #43 / 546c24e
  ↓
Corrective D0 specification
  ↓
P0-1 v3 history, epoch, and migration
  ↓
P0-2 progressive recovery and stable reconciliation
  ↓
P0-3 Home quick feedback
  ↓
P0-4 integration, preserved-device validation, and final M7 closure
  ↓
M8 may begin
```

Corrective slices are sequential and each branches from current `develop` only
after its dependency merges. The narrower order protects shared persistence,
coordinator, Home, and migration fixtures.

## Physical-module decision

No physical module, target, or Swift package is approved for Milestone 7.

Reasons:

- persistence and Decision Engine contracts change during PR1–PR5;
- there is no external reuse requirement;
- current verification remains fast;
- folder boundaries and narrow protocols are sufficient while the contracts
  stabilize.

Reevaluate after PR5 only if compiler-enforced isolation, measurable build/test
cost, or repeated ownership conflicts provide evidence. Extraction requires a
separate ADR and PR.

## Risks and mitigations

- **Migration loses pilot state:** fail closed, preserve legacy bytes, and
  validate active replacement before publication.
- **Viewer Profile becomes a monolith:** keep Viewer Movie State as a separate
  Domain aggregate behind narrow capabilities.
- **Cross-surface contradictions:** one transition reducer and persistence
  owner serve Detail, Watchlist, calibration, Settings, and Home.
- **Stale recommendations publish after feedback:** capture and recheck the
  non-reusable state snapshot identity before persistence and publication.
- **Recovered numeric revision revives old recommendations:** use an opaque fresh
  identity for every recovery publication and compare only for equality.
- **Decision Set migration repeats active or recent titles:** preserve complete
  history, seed only trustworthy v2 recency, and exclude the active set plus
  bounded recent window.
- **Permanent shown exclusion exhausts recall:** separate diagnostic history
  from bounded suppression, expand recall, and deterministically roll over only
  older shown titles without explicit feedback.
- **Reaction refresh destabilizes every card:** rebuild evidence but retain
  unaffected titles that remain eligible, credible, and explainable.
- **Async hydration changes deterministic output:** bound work to four child
  tasks, retain sorted indices, and assemble only the complete ordered result.
- **Missing genre labels expose TMDB internals:** resolve names from trusted
  hydrated Taste Profile metadata and make Presentation reject numeric
  fallbacks.
- **Remote catalog breaks onboarding:** cap visible wait, validate all-or-
  nothing, then fall back to cached or bundled.
- **External endpoint is unavailable:** PR1–PR8 may proceed against injected
  test transport and bundled fallback, but PR9 physical remote validation and
  PR10 closure require a separately authorized read-only pilot endpoint.
- **Catalog changes an active flow:** persist the exact snapshot in its draft.
- **Coordinator and profile files grow further:** extract focused collaborators
  in the slice that adds the new responsibility.
- **UserDefaults scale and recovery become unsafe:** move bounded viewer state
  to an actor-owned Application Support envelope with previous-valid recovery.

## Final approval record

The original Milestone 7 implementation merged through PR #43, but the final
physical run invalidated its approval by reproducing the P0 Home exhaustion.
Milestone 7 is formally reopened and Milestone 8 is blocked.

The product direction and corrective D0 contract are accepted. The exact
30-title window, 6→12→20 recall stages, three-title rollover increment,
terminal copy/actions, 24-hour exhaustion freshness, quick-feedback menu,
v2-to-v3 migration, and twenty-page device evidence contract were accepted by
the Product Owner on `2026-09-01`. After D0 merges, P0-1 through P0-4 execute
sequentially. Final approval requires P0-4 validation over the untouched
blocked installation, Technical Lead review and Product Owner acceptance of
the recorded latency, and the repeated household utility checkpoint.

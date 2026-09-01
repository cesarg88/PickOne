# Milestone 7 P0 — Home Exhaustion Recovery

## Status

`Proposed — product direction accepted; D0 details awaiting final approval`

- Milestone 7 reopened: `2026-09-01`
- Trigger: final physical-device validation on the Product Owner's retained
  pilot installation
- Parent milestone: [Milestone 7 — Continuous Taste Learning](milestone-7-continuous-taste-learning.md)
- Architecture proposal:
  [ADR-014 — Bounded Recommendation Suppression and Exhaustion Recovery](../decisions/adr-014-bounded-recommendation-suppression-and-recovery.md)
- Backlog: IMP-025
- Milestone 8 remains blocked.

## Goal

Recover every existing and future installation from deterministic Home
exhaustion without deleting explicit feedback, profile, Watchlist, Search
History, or diagnostic recommendation history. Make feedback from Home fast and
keep unaffected recommendations visually stable when they remain trustworthy.

## Incident evidence

The final M7 physical validation reproduced:

- repeated recommendations for movies the Viewer knew they had watched but had
  not necessarily recorded yet;
- high friction because feedback required navigating through Movie Detail;
- complete visible-set replacement after reaction feedback;
- a persisted zero-result Home after prolonged feedback;
- repeated `Give me three more` operations with the same zero result;
- no Home recovery after `Reset preferences` and a new calibration.

A read-only device capture established the deterministic root cause:

- 93 distinct shown IDs;
- 47 watched IDs;
- 113 IDs in the union of permanent and current shown exclusions;
- an empty Decision Set bound to the current Viewer State snapshot;
- a normal recall boundary of at most 120 raw titles before exact availability
  and credibility.

The original device state remains untouched for upgrade validation. Raw pilot
state is diagnostic evidence only and must not enter source control, fixtures,
PR descriptions, analytics, or logs. Automated regression uses a sanitized
structurally equivalent fixture.

## Accepted product requirements

- watched, all Movie reactions, and `Not interested` remain permanent title
  exclusions;
- current active cards never repeat as the result of replacement refresh;
- complete shown history remains available for diagnostics;
- only bounded recent history suppresses otherwise eligible titles;
- never-shown titles have priority;
- recall expands progressively when normal recall cannot fill the set;
- older shown titles without feedback may return outside recent suppression;
- a reaction recalculates Taste Profile but retains other eligible, credible,
  explainable cards;
- watched and `Not interested` normally repair only the affected card;
- preference reset clears recent suppression while preserving watched,
  Watchlist, Search History, and complete shown history;
- one refresh cannot repeat a hidden deterministic zero-result operation;
- honest zero is valid only after the full strategy and must be explainable and
  actionable;
- availability, credibility, and explicit exclusions never relax;
- every Home card offers the four reactions, `Already watched`, and `Not
  interested` without requiring Detail navigation.

## D0 decisions proposed for acceptance

ADR-014 defines the executable proposal:

- 30 most-recent distinct IDs as temporary suppression;
- pages 1–6 normal, 7–12 first expansion, and 13–20 final expansion;
- oldest-first rollover in groups of three after full expansion;
- complete distinct-ID diagnostic history separated from ordered recent
  suppression;
- v3 Viewer State suppression epoch and Decision Set v3 history/outcome;
- direct `Review My movies` and `Review streaming services` terminal actions;
- a trailing per-card ellipsis menu for quick feedback.

These values remain Proposed until the Product Owner approves D0. No
implementation slice is Engineering Ready before that approval and merge.

## Domain contracts

### Recommendation history

Domain introduces validated values equivalent to:

```text
RecommendationHistory
├── allShownMovieIDs: Set<MovieID>
├── recentlyShownMovieIDs: ordered unique MovieIDs, maximum 30
└── suppressionEpochID: RecommendationSuppressionEpochID
```

The complete set only grows. The recent list is bounded, ordered oldest to
newest, and resets only when the suppression epoch changes. Active
recommendations are explicit Decision Set members rather than inferred from the
recent list.

### Generation policy

Domain owns a versioned `RecommendationSearchPolicy` with the accepted page
stages, window size, rollover step, and never-shown priority. The policy is an
input to orchestration and persisted exhaustion compatibility. It does not
enter P1 score.

After final expansion, the unchanged P1 selector first chooses from the
never-shown credible pool. Rollover fills only vacant slots and cannot displace
one of those selected titles; roles and explanation evidence are then rebuilt
for the composed set. This makes priority executable without adding a score
bonus or changing P1 fixtures.

### Outcomes

Generation distinguishes:

- usable three-title set;
- usable exhausted smaller set;
- exhausted without recommendations;
- retryable failure with an optional proven-safe retained set.

An exhausted outcome contains no fabricated recommendation and is invalidated
only by a relevant trusted-input or search-policy change.

### Reconciliation

Reaction reconciliation evaluates current unaffected members against the new
complete Taste Profile, rebuilds their evidence, and fills only missing slots.
Eligibility-only reconciliation keeps its title-local repair path. Every path
checks the immutable source snapshot before persistence and publication.

## Data and persistence

- `LocalViewerStateEnvelopeV3` adds the suppression epoch and supports explicit
  v2 migration through active/previous/quarantine recovery.
- `DecisionSetEnvelopeV3` replaces permanent shown exclusion with complete
  history, bounded recent suppression, source epoch, search-policy version, and
  typed exhaustion.
- exact valid v2 bytes remain the active migration source until v3 replacement
  succeeds;
- unsupported/corrupt input is quarantined exactly and never partially decoded;
- normal v2 sets preserve valid current recommendations;
- empty v2 sets trigger automatic recovery;
- reset changes the epoch atomically with Viewer State preference reset and
  never performs a second fallible cross-store reset write.

## Presentation

### Quick feedback

Each card exposes a separate trailing ellipsis menu:

- `Love it`
- `Like it`
- `It was okay`
- `Didn't like it`
- `Already watched`
- `Not interested`

The menu has an explicit movie-title accessibility label. One card owns local
mutation progress; failure preserves the card and supports retry. Successful
feedback publishes only after Viewer State and the reconciled Decision Set are
safe.

### Exhaustion

Zero-result copy and actions are canonical in ADR-014. A one- or two-title
exhausted set remains visible with honest secondary copy. `Give me three more`
is absent once the current policy is exhausted. Transport or persistence
failure continues to expose Retry and never masquerades as exhaustion.

When refresh exhausts without replacing a still-safe active set, its cards stay
visible with the accepted `No more picks available right now` explanation and
the same recovery navigation. It is not presented as a successful new set.

## Error, cancellation, and concurrency

- one coordinator actor owns paging, rollover, reconciliation, Decision Set
  persistence, and publication;
- one viewer-state actor owns the reset epoch transaction;
- repeated user operations cancel obsolete work;
- page, availability, hydration, and persistence failures remain typed failure;
- cancellation is silent and never persists exhausted state;
- an obsolete snapshot cannot publish, advance history, or consume rollover;
- persistence failure retains the previous valid v2/v3 envelope and feedback;
- Home never offers destructive recommendation reset.

## Acceptance criteria

- the diagnosed v2 shape recovers in place to at least one recommendation when
  the deterministic fixture contains an eligible credible title outside hard
  exclusions;
- every explicit feedback ID remains excluded through refresh, rollover,
  relaunch, migration, and preference reset according to its accepted reset
  semantics;
- all historical shown IDs remain in diagnostic history after rollover and
  reset;
- recent suppression never exceeds 30 unique IDs and active IDs never return on
  replacement refresh;
- never-shown candidates win before rollover candidates;
- one refresh runs every required stage once and never repeats an unchanged
  zero operation;
- released recent-window state advances only with a successfully persisted set
  or exhausted outcome and never after failure, cancellation, or stale work;
- a typed exhausted outcome survives relaunch and becomes invalid after a
  relevant input, epoch, or policy change;
- a reaction normally preserves the two unaffected current titles when their
  recomputed evidence remains valid;
- watched and `Not interested` preserve unaffected current titles and do not
  mutate Taste Profile incorrectly;
- quick feedback persists exactly the selected transition without navigating to
  Detail;
- failure preserves Viewer State and the last proven-safe visible set;
- P1 fixtures A–M, score, thresholds, roles, availability gates, and explanation
  truth remain unchanged.

## Required automated tests

### Pure Domain

- recent-window validation, ordering, uniqueness, and 30-ID bound;
- complete history monotonicity and recent reset without complete-history loss;
- active-set hard suppression;
- never-shown priority and three-ID oldest-first rollover;
- deterministic 6→12→20 staging and early empty-page termination;
- hard exclusions surviving every stage;
- reaction retention with rebuilt explanation and roles;
- watched and `Not interested` title-local repair;
- typed smaller and zero exhaustion distinct from failure.

### Persistence and migration

- Viewer State v2-to-v3 round trip with a fresh epoch and all semantic data
  unchanged;
- Decision Set v2 normal migration preserving current set and all shown IDs;
- blocked empty-v2 migration preserving 93 shown/47 watched equivalent
  sanitized evidence and enabling recovery;
- valid v2 bytes preserved until successful v3 replacement;
- v3 relaunch, unsupported schema, corruption, quarantine, encoding,
  replacement, and recovery failure;
- preference reset atomically changes epoch, removes reactions and `Not
  interested`, and preserves watched, Watchlist, complete history, and Search
  History.

### Orchestration

- prolonged mixed sequence of at least 40 reaction, watched, `Not interested`,
  refresh, and relaunch operations;
- no explicit exclusion ever selected;
- no active title returned by replacement refresh;
- no repeated unchanged empty generation;
- adaptive paging is deduplicated, cancellable, and bounded;
- stale work cannot persist history or exhaustion;
- reaction preserves valid unaffected cards and replaces only invalid/missing
  slots;
- reset plus new onboarding recovers with complete history intact.

### Presentation and UI

- card menu content, labels, Dynamic Type, VoiceOver, and separate navigation
  hit targets;
- every quick action success/failure/retry path;
- per-card progress without blocking other cards;
- partial and zero exhausted copy and navigation actions;
- retained-safe-set exhaustion copy and disabled deterministic refresh;
- `Give me three more` hidden after exhaustion and Retry shown only for failure;
- Home → quick feedback → reconciled cards without Detail navigation.

## Physical-device validation

Install the final correction build over the untouched blocked pilot app. Do not
reinstall or clear application data.

Verify:

- v2 state migrates and Home recovers automatically;
- the 47 watched facts, current reactions, profile, services, Watchlist, Search
  History, and complete shown history survive;
- no persisted watched title appears;
- each quick action works from Home;
- one reaction keeps the other valid cards;
- watched and `Not interested` replace only their card when possible;
- repeated refresh never loops silently and eventually shows the accepted
  actionable exhaustion state if the full strategy truly exhausts;
- relaunch preserves the recovered set, history, and exhaustion semantics;
- existing Detail, `My movies`, Watchlist, Search, onboarding, recalibration,
  availability, and catalog fallback remain operational;
- the household utility checkpoint is repeated before final M7 approval.

## Delivery slices

Every slice branches from the latest `develop` after its dependency merges and
opens ready for review. The existing merged PR #43 is not reverted.

### D0 — P0 specification and ADR

Documentation only. Deliver this specification, ADR-014, and reconciliation of
PRODUCT, ADR-011, ADR-012, glossary, roadmap, backlog, and parent M7 status.

Approval and merge make the correction Engineering Ready.

### P0-1 — v3 history, epoch, and migration

Dependencies: accepted D0.

Deliver Domain history/epoch/outcome values, Viewer State v3 and Decision Set
v3 DTOs, semantic validation, v2 migrations, exact-byte preservation,
repository support, and focused tests. Preserve current visible behavior and
exclude adaptive recall, stable reconciliation, and new UI.

### P0-2 — progressive recovery and stable reconciliation

Dependencies: P0-1.

Deliver staged recall, never-shown priority, oldest-first rollover, persisted
exhaustion, preference-reset epoch handling, stable reaction reconciliation,
title-local watched/`Not interested` repair, terminal Home copy/actions, stale-
work protection, and focused Domain/Data/Presentation tests. Exclude quick
feedback controls.

### P0-3 — Home quick feedback

Dependencies: P0-2.

Deliver the accessible per-card menu, four reactions, `Already watched`, `Not
interested`, per-card progress, retryable write failure, reconciliation handoff,
and UI tests. Reuse the existing Viewer Movie State transitions and do not add a
second feedback model.

### P0-4 — integration and final M7 closure

Dependencies: P0-3.

Deliver the sanitized prolonged-feedback regression, full upgrade/relaunch UI
journey, documentation closure, `make verify`, green CI, and the Product Owner's
physical update validation on the preserved blocked installation. This is a new
PR; merged PR #43 remains historical evidence.

## Dependency graph

```text
develop at PR #43 merge (546c24e)
  ↓
D0 P0 specification
  ↓
P0-1 v3 persistence and migration
  ↓
P0-2 recovery and stable reconciliation
  ↓
P0-3 Home quick feedback
  ↓
P0-4 integration, physical validation, and M7 closure
  ↓
M8 may begin
```

## Explicit non-goals

- P1 score, fixtures, thresholds, roles, or explanation semantics;
- relaxing exact availability or credibility;
- deleting explicit feedback or watched history;
- passive feedback, impressions, analytics, or event telemetry;
- a catalog-wide watched importer;
- `Not tonight`, `Watch this`, rewatch intent, trailers, or M8 work;
- backend, AI, accounts, sync, or a physical module;
- unrelated visual polish.

# Milestone 6 — Three for Tonight

## Status

`Accepted — Engineering Ready for implementation`

- Product acceptance: `2026-08-11`
- Engineering acceptance: `2026-08-11`
- Implementation authorization becomes effective when the D0 documentation PR
  containing this specification is merged into `develop`.

## Identifiers and authority

- Roadmap: Milestone 6
- Backlog: IMP-002 and IMP-003
- Architecture: [ADR-011 — Deterministic Decision Engine v1](../decisions/adr-011-deterministic-decision-engine-v1.md)
- Product authority: [`PRODUCT.md`](../../PRODUCT.md)
- Engineering authority: [`ENGINEERING.md`](../../ENGINEERING.md)
- Fixture contract: [Decision Engine v1 — Product Fixtures](../recommendation/decision-engine-v1-product-fixtures.md)
- Calibration evidence: [Decision Engine v1 — Real Movie Sanity Check](../recommendation/decision-engine-v1-real-movie-sanity-check.md)
- Formula evidence: [Decision Engine v1 — Scoring Prototype](../recommendation/decision-engine-v1-scoring-prototype.md)

If this specification conflicts with `PRODUCT.md` about product behavior,
`PRODUCT.md` wins. If it conflicts with `ENGINEERING.md` about a current
technical invariant, `ENGINEERING.md` wins. ADR-011 is canonical for the P1
model and Decision Engine architecture.

## Goal

Make Home deliver a persistent, deliberate set of up to three personalized
movies that are verified as included with the viewer's selected services in
Spain.

The result must be deterministic for the same complete snapshot, exclude known
watched and already-shown movies, explain each fit honestly, survive relaunch,
and refresh only through deliberate or accepted invalidation behavior.

## User outcome

A completed-profile user opens PickOne and sees zero to three current
recommendations. Each recommendation communicates:

- Safe Choice, Stretch Choice, or Discovery Choice role;
- title and artwork;
- one evidence-backed fit reason;
- every verified selected provider;
- runtime when known;
- release year and genre context;
- current saved state.

The user can open Movie Detail or request `Give me three more`. A smaller or
empty honest result is valid when fewer than three candidates satisfy every
credibility, watch-history, cycle-history, and availability rule.

## Current baseline

The repository already provides:

- one completed local Viewer Profile with region, selected services, and
  calibration reactions;
- Watchlist saved and watched state;
- TMDB movie detail, search, discovery-style list mapping, and image support;
- movie-level availability evidence with freshness, caching, and exact
  selected-provider verification;
- Movie Detail navigation and the regional TMDB handoff;
- a five-tab shell currently exposing Discover, Search, Ask, Watchlist, and
  Settings;
- Swift 6 strict concurrency, repository checks, and `make verify`.

Known boundary debt that Milestone 6 must address is that current Watchlist
reads can collapse a decoding failure into an empty list. That behavior is not
safe for watched exclusion and is corrected in PR4 without redesigning all
local persistence.

## Accepted product behavior

### Main navigation

The main tabs, in order, are:

1. Home
2. Search
3. Discover
4. Watchlist
5. Settings

Home replaces the current first Discover surface. Discover moves into the
current Ask tab position. Existing Ask source code, tests, and composition are
preserved, but Ask is not exposed as a tab in Milestone 6. Removing or
redesigning Ask is out of scope.

### Home lifecycle

- On first Home load with no usable persisted Decision Set, generate one.
- On relaunch with a compatible persisted set and matching cycle identity,
  first compare current local Watchlist eligibility, then render it without
  requiring a network refresh when no repair is needed.
- Do not expire the set automatically in the pilot.
- `Give me three more` is always visible for a loaded or honest-empty state.
- Pull to refresh may call the same use case but is optional.
- A refresh failure preserves and continues showing the previous usable set
  with a non-destructive retry affordance.
- A generation failure without a usable set shows Retry.
- Exhausted eligible candidates produce a successful empty state, not an error.

### Eligibility

A movie is eligible only when all of these are true:

- no informative calibration reaction proves it was watched;
- Watchlist does not mark it watched;
- its ID is absent from current-cycle shown history;
- its P1 score satisfies the normal or sparse credibility rule;
- current movie-level evidence verifies at least one selected, allowlisted
  provider under the active region's `flatrate` entries.

`unknown` and `ineligible` availability both fail closed, while retaining their
distinct Domain meanings. A saved but unwatched movie remains eligible and may
receive the accepted `+2` intent bonus.

### Roles and explanations

The pure selector assigns at most one movie to each role in this order:

1. Safe Choice
2. Stretch Choice
3. Discovery Choice

The role communicates set composition. It is not the primary recommendation
reason. The primary explanation uses the first supported evidence class in
this precedence:

1. saved Watchlist intent plus a genuine taste match;
2. a named positive `Love it` or `Like it` anchor;
3. learned positive genre affinity;
4. general quality evidence for a sparse profile.

Diversity can provide secondary role context only when a supported fit reason
exists. Presentation must not display scores, confidence percentages, inferred
themes, mood, pacing, creators, or certainty that the viewer will enjoy the
movie.

### Cycle identity and mutable eligibility

`DecisionCycleIdentity` is a stable deterministic signature of:

- engine model version;
- complete relevant profile and reactions;
- region;
- sorted selected provider IDs;
- versioned explicit viewing context.

Milestone 6 has no context controls, so it uses a named versioned default
context rather than omitting context from the signature. The version-1
signature DTO contains engine version, profile schema version, calibration
catalog version, region, providers sorted by ID, reactions sorted by movie ID,
and viewing context. Data encodes it as JSON with sorted keys and hashes the
bytes with SHA-256 from CryptoKit. It must not use Swift's process-randomized
`Hasher`.

Watchlist saved and watched state is deliberately not part of cycle identity.
It is current mutable eligibility and intent evidence.

- A profile, reaction, region, provider, context, or engine-version change
  starts a new cycle with empty shown history.
- App relaunch does not start a new cycle.
- Watchlist changes reevaluate, invalidate, or repair the current set without
  changing the cycle identity or erasing shown history.
- Every movie is appended to shown history when a set containing it is safely
  persisted for presentation, including replacements.
- A repaired or removed movie cannot reappear later in the same cycle.

### Persistence and recovery

The current set and cycle state live in one versioned recommendation envelope
owned by one serialized repository. It is separate from Viewer Profile,
Watchlist, and Search History storage.

If the active recommendation envelope is corrupt or incompatible:

1. preserve the original bytes in a dedicated diagnostic quarantine value;
2. do not interpret the bytes as an empty set;
3. capture current trusted inputs and attempt fresh generation;
4. replace the active envelope only after the complete replacement encodes and
   saves successfully;
5. keep the diagnostic bytes after successful recovery;
6. show Retry if regeneration or persistence fails.

Because corrupt or incompatible bytes cannot provide trustworthy shown
history, successful regeneration starts a new cycle under the current identity
rather than pretending the previous history was recovered.

There is no `Reset recommendations` action. Recovery never modifies or deletes
Viewer Profile, Watchlist, or Search History.

## P1 model contract

ADR-011 defines the complete formula. Implementations must use its unrounded
values and exact constants for:

- reaction values;
- evidence shrinkage;
- normalized genre and era affinity;
- positive genre coverage;
- directional profile confidence and adaptive weights;
- strongest positive-anchor metadata similarity;
- rating and vote-evidence quality confidence;
- Watchlist `+2` bonus;
- normal `rankScore >= 50` admission;
- sparse `profileConfidence < 1/3` and `qualityComponent >= 0.60` admission;
- ten-point maximum genre-overlap diversity penalty;
- quality then lower-TMDB-ID tie-breaking.

TMDB popularity may order recall but must not cross into the Domain scoring or
explanation input.

## Architecture

The dependency direction remains:

```text
Presentation -> Domain <- Data
```

The feature has two deliberately separate execution boundaries:

```text
Async repositories and coordinator
            ↓ immutable snapshot
Pure synchronous P1 Decision Engine
            ↓ deterministic selection
Async persistence and Presentation publication
```

The pure engine never performs network access, persistence, cancellation,
cache lookup, task creation, UI mapping, or time acquisition.

### Domain values

The implementation may refine spelling while preserving these meanings:

- `DecisionEngineModelVersion`
- `DecisionGenre`
- `TasteReactionEvidence`
- `DecisionCandidate`
- `DecisionAvailability`
- `DecisionCycleIdentity`
- `DecisionEngineInput`
- `DecisionRole`
- `RecommendationEvidence`
- `DecisionRecommendation`
- `DecisionSelection`
- `DecisionCycle`
- `PersistedDecisionSet`

Values crossing asynchronous boundaries are immutable and `Sendable`.
Invalid scores, incomplete identity, malformed movie identity, unsupported
roles, and unverifiable availability must be rejected at their boundary rather
than represented as normal eligible candidates.

### Domain capabilities

Capability protocols use no `Protocol` suffix:

```swift
protocol DecisionSelecting: Sendable {
    func select(from input: DecisionEngineInput) -> DecisionSelection
}

protocol DecisionCandidateRepository: Sendable {
    func discoverPage(
        _ page: Int,
        context: DecisionCandidateContext
    ) async throws -> [DecisionCandidateSeed]
}

protocol DecisionSetRepository: Sendable {
    func load() async -> DecisionSetLoadResult
    func replace(_ envelope: PersistedDecisionSet) async throws
}

protocol ThreeForTonightUseCase: Sendable {
    func load() async -> ThreeForTonightResult
    func refresh() async -> ThreeForTonightResult
    func repairAfterEligibilityChange() async -> ThreeForTonightResult
}
```

`P1DecisionEngine` is the concrete pure selector. The existing
`RecommendationRepository` remains the contract for the later Ask experience
and must not be repurposed for Home.

The coordinator reuses the existing `ViewerProfileRepository`,
`WatchlistRepository`, `MovieRepository`, and `AvailabilityRepository` through
Domain contracts. Presentation never constructs a Data implementation.

### Trusted input snapshot

One generation captures a coherent immutable snapshot containing:

- completed Viewer Profile, reactions, region, and selected services;
- informative calibration movie IDs as watched evidence;
- Watchlist watched IDs;
- Watchlist saved-but-unwatched IDs;
- current cycle identity and shown IDs;
- hydrated calibration-anchor metadata;
- deduplicated candidate metadata;
- movie-level verified availability and verification time.

Profile and Watchlist reads must distinguish missing, valid, corrupt,
unsupported, and detectable failure states where relevant. A corrupt Watchlist
cannot become an empty watched set.

### Data boundaries

TMDB candidate recall:

- requests pages `1...6` for normal generation;
- uses Spanish localization and active region `ES`;
- sets `include_adult=false` and `include_video=false`;
- may use selected providers joined with OR and `watch_region=ES` to improve
  recall, but never as final proof;
- uses deterministic page ordering and keeps the first occurrence when
  deduplicating by TMDB ID;
- maps only accepted metadata into Domain;
- does not map popularity into scoring or explanation values.

Availability verification reuses cached movie-and-region evidence when fresh.
Domain reevaluates that evidence against the current selected services. A
bounded task group may verify candidates concurrently; the initial bound is
eight requests and remains an implementation constant covered by orchestration
tests rather than a product promise.

Candidate-specific hydration or availability failure excludes that candidate
as unknown when the remaining snapshot is usable. A source-wide failure with a
usable retained set is a refresh failure; without a retained set it is a
generation failure.

### Decision Set envelope

The storage DTO uses one versioned envelope and contains at least:

- schema version;
- Decision Set ID and generation date;
- P1 engine model version;
- cycle ID and stable cycle-identity signature;
- all shown movie IDs for the cycle;
- ordered zero-to-three recommendations;
- movie ID, role, structured evidence, and display snapshot per item;
- matching provider IDs, verification date, and returned regional TMDB URL;
- enough title, artwork, runtime, year, and genre data to render after relaunch.

Domain values and Data storage DTOs remain separate. The repository encodes the
whole envelope before one replacement operation. Readers observe complete
envelopes produced by PickOne logic. As with existing UserDefaults use, this
does not claim physical-write confirmation that the API cannot expose.

### Concurrency and orchestration

One `actor` owns generation, refresh, repair, cancellation, and persistence
publication ordering.

- Only one authoritative generation mutates Decision Set state at a time.
- A newer explicit request cancels or supersedes older work.
- Cancellation is checked between pages, enrichment, availability, selection,
  and persistence.
- Cancelled or stale work never replaces the persisted or visible set.
- The coordinator captures one cycle identity per operation and discards a
  result if identity-defining input changed before persistence.
- It reevaluates current Watchlist eligibility before persistence without
  resetting cycle history.
- Loading a retained envelope also checks current local Watchlist eligibility
  before publishing it; a newly watched item is repaired first.
- Presentation receives a set only after successful persistence.
- Failure preserves the last successfully persisted usable set.

### Presentation

`HomeDecisionViewModel` is `@MainActor`, owns at most one task, and exposes
observable states equivalent to:

- `loading`
- `loaded(set, isRefreshing, refreshError)`
- `empty`
- `failure(error, previousSet)`

Home behavior:

- render retained content while refresh is in progress;
- render zero to three cards without placeholder recommendations;
- render role separately from the primary reason;
- render provider logos from verified evidence;
- route through existing Movie Detail navigation;
- expose `Give me three more` in loaded and empty states;
- expose Retry for initial generation, persistence, and recovery failures;
- preserve existing Search, Discover, Watchlist, Settings, and hidden Ask code.

Milestone 7 feedback controls and quick viewing-context controls are not added.

## Failure semantics

- `unknown` availability is never converted to `ineligible`.
- Corrupt Watchlist or recommendation data is never converted to empty valid
  state.
- Honest zero-candidate selection is success.
- Retrieval or persistence failure is failure, not honest empty.
- Refresh failure retains prior content and does not advance cycle history.
- Persistence failure retains the previous envelope and does not publish the
  newly calculated set.
- Unsupported recommendation schema follows the same quarantine and recovery
  path as corruption.
- A failed repair retains every still-valid previous recommendation and exposes
  retry rather than silently showing known-ineligible content.

## Acceptance criteria

### Decision Engine

- Identical complete inputs produce byte-for-byte equivalent ordered Domain
  outcomes, excluding generated storage identifiers and dates.
- All P1 formulas and thresholds match ADR-011.
- Calibration and Watchlist watched movies are excluded.
- Current-cycle IDs are excluded.
- Saved-unwatched state changes rank only by the accepted bonus and never
  changes Taste Profile.
- `unknown` and `ineligible` availability cannot enter the set.
- Zero, one, two, and three-item selections are valid.
- Roles are ordered and never backfilled with below-threshold candidates.
- Tie-breaking is deterministic and excludes popularity.
- Explanation evidence and precedence match the accepted hierarchy.

### Recall and input assembly

- A normal generation requests exactly six Discover pages.
- Results are deterministically ordered and deduplicated by TMDB ID.
- Candidate mapping uses only accepted P1 metadata.
- Every final candidate has exact movie-level selected-provider `flatrate`
  evidence.
- One coherent profile, Watchlist, cycle, metadata, and availability snapshot
  reaches the pure engine.
- Corrupt Watchlist evidence blocks unsafe generation rather than pretending no
  movies are watched.

### Persistence, refresh, and repair

- A compatible persisted set renders after relaunch without automatic refresh.
- Initial generation, refresh, and repair publish only after successful save.
- Refresh excludes all previously shown IDs and retains that history after
  relaunch.
- Profile/reaction, region, provider, context, or engine-version change starts
  a new cycle.
- Watchlist saved/watched change repairs current state without changing cycle
  identity or losing shown history.
- Availability invalidation replaces only affected titles when possible.
- Corrupt or unsupported recommendation bytes are quarantined before recovery.
- Successful recovery replaces only the recommendation envelope.
- Failed recovery shows Retry and does not modify profile, Watchlist, or Search
  History.

### Presentation

- Main tabs are Home, Search, Discover, Watchlist, and Settings in that order.
- Ask is absent from tab navigation while its implementation remains in the
  target.
- Home renders loading, retained-refresh, smaller, empty, and retryable failure
  states.
- Every card renders its role and an independently supported primary reason.
- Provider logos reflect the verified provider snapshot.
- `Give me three more` is visible without relying on pull to refresh.
- Existing Movie Detail, Search, Discover, Watchlist, Settings, and onboarding
  behavior remains operational.

## Required automated tests

### Synthetic fixtures A–L

- A: exact raw order `C1 > C2 > C5 > C3 > C4`.
- B: `C1` leads while unrelated high-quality alternatives remain credible and
  one disliked Comedy does not become a ban.
- C: one negative Science Fiction observation does not suppress the positive
  Science Fiction candidates.
- D: only eligible `C3` and `C4` survive.
- E: calibration-watched and Watchlist-watched candidates are excluded while a
  saved-unwatched candidate remains eligible.
- F: the `+2` Watchlist bonus changes only a close result.
- G: low vote evidence does not make a recent high-fit movie impossible.
- H: exact diversified role order is `C1`, `C3`, `C4`.
- I: refresh excludes `C1`, `C2`, and `C3` from the next set.
- J: personalized `C1` and `C3` outrank unrelated popular `C2`.
- K: `It was okay` is watched evidence and produces zero directional affinity.
- L: exhausted credible eligibility returns successful empty selection.

### Additional pure tests

- every reaction value and observation rule;
- shrinkage and neutral unknown affinities;
- weights sum to `1` within numerical tolerance;
- similarity and era boundaries;
- missing metadata rules;
- normal and sparse credibility admission;
- unrounded comparison and exact tie-breaks;
- explanation evidence precedence, including Watchlist plus fit;
- role evidence never substitutes for a fit reason;
- frozen original and augmented real-profile P1 snapshots.

### Repository and orchestration tests

- Discover request parameters, six-page behavior, ordering, deduplication,
  partial candidate failure, source-wide failure, and cancellation;
- popularity absent from Domain inputs;
- profile and calibration hydration failure;
- throwing Watchlist read and corruption propagation;
- current-context availability reevaluation and cache reuse;
- bounded concurrent verification and cancellation;
- signature stability and reset inputs;
- Watchlist repair preserving cycle history and preventing repeats;
- atomic envelope replacement, relaunch, encoding failure, and prior-set
  preservation;
- corrupt and unsupported quarantine, successful regeneration, failed
  regeneration, and failed persistence;
- no recovery mutation of Viewer Profile, Watchlist, or Search History;
- stale operation cannot persist or publish.

### Presentation and UI tests

- tab order and Ask absence;
- initial loading to loaded, smaller, empty, and Retry states;
- retained set during refresh and non-destructive refresh failure;
- role and explanation mapping;
- provider-logo mapping;
- explicit refresh intent;
- Home card to Movie Detail navigation;
- existing onboarding root routing and supporting-tab smoke coverage.

Every implementation PR runs focused tests while iterating and `make verify`
before handoff.

## Delivery slices

Each PR branches from current `develop` after its required dependencies are
merged. Stacking is allowed only when the child cannot compile or be verified
independently. PRs must remain buildable and green.

### D0 — Canonical specification and Engineering Ready state

Outcome:

- version ADR-011 and its four support documents;
- reconcile `PRODUCT.md`, roadmap, and IMP-002;
- add this executable specification;
- contain no application behavior or production code change.

D0 authorizes PR1 only after merge.

### PR1 — Pure P1 scoring primitives

Dependencies: D0.

Deliver:

- immutable Domain input primitives;
- reaction, affinity, confidence, adaptive weight, similarity, quality, base
  score, Watchlist bonus, and credibility calculations;
- formula tests for Fixtures A, B, C, F, G, J, and K;
- frozen real-profile raw scoring regression checks.

Exclude async work, repositories, availability orchestration, persistence, and
UI.

### PR2 — Pure eligibility, diversity, roles, and explanations

Dependencies: PR1.

Deliver:

- eligibility filtering over already-resolved Domain evidence;
- deterministic diversification and role assignment;
- structured explanation evidence and accepted semantic precedence;
- tests for Fixtures D, E, H, I, and L, smaller sets, empty sets, ties, and
  reason honesty.

Exclude networking, storage, and Presentation.

### PR3 — TMDB Discover candidate recall

Dependencies: PR1. May proceed in parallel with PR2 after PR1 merges if agents
do not edit shared Domain contract files.

Deliver:

- candidate client DTOs and Data mapping;
- `DecisionCandidateRepository` implementation;
- six-page request, stable page ordering, deduplication, localization, region,
  provider recall filters, cancellation, and error tests;
- proof that popularity does not enter Domain scoring inputs.

Exclude final movie-level eligibility, engine selection, and UI.

### PR4 — Trusted Decision Engine input assembly

Dependencies: PR2 and PR3.

Deliver:

- coherent profile, Watchlist, candidate, calibration-anchor, and availability
  snapshot assembly;
- safe throwing Watchlist reads for Decision Engine use, eliminating silent
  corruption-as-empty behavior at this boundary;
- reusable pure availability evaluation against selected services;
- calibration metadata hydration through existing movie capabilities;
- exclusion and partial-failure integration tests.

Exclude Decision Set persistence and Home.

### PR5 — Decision Set and cycle persistence

Dependencies: PR2 and accepted persistence values; may proceed beside late PR4
work only when shared Domain files are no longer changing.

Deliver:

- stable cycle signature;
- versioned Decision Set envelope and actor-owned repository;
- shown-history semantics;
- atomic logical replacement;
- relaunch compatibility;
- corrupt/unsupported byte quarantine and recovery states;
- storage and migration tests.

Exclude network orchestration and UI.

### PR6 — Asynchronous generation, refresh, and repair coordinator

Dependencies: PR2, PR3, PR4, and PR5.

Deliver:

- one actor-owned orchestration path for load, initial generation, refresh,
  Watchlist repair, availability repair, persistence, cancellation, and retry;
- bounded availability concurrency and cache reuse;
- AppContainer composition without changing main navigation;
- full orchestration tests, including stale work and recovery.

Exclude Home presentation.

### PR7 — Home, navigation, and Milestone closure

Dependencies: PR6.

Deliver:

- Home view model and screen;
- final tab order and hidden Ask tab;
- cards, roles, reasons, providers, states, explicit refresh, and Detail route;
- Presentation and UI smoke tests;
- final roadmap, backlog, milestone completion record, CI, and requested
  physical-device validation evidence.

This PR closes Milestone 6 only after its final SHA passes `make verify`, CI,
and the required device checks.

## Dependency graph

```text
D0
↓
PR1 Pure score
├── PR2 Selection and evidence ──┬──→ PR4 Input assembly
│                                └──→ PR5 Persistence
└── PR3 TMDB recall ────────────────→ PR4 Input assembly
PR2 + PR3 + PR4 + PR5 ────────────→ PR6 Orchestration
PR6 ───────────────────────────────→ PR7 Home and closure
```

## Physical-module decision

No new target, Swift package, or physical module is approved for Milestone 6.
The Decision Engine starts under explicit `Domain/DecisionEngine` and focused
test boundaries in the existing application target.

Reevaluate extraction after PR2 and again after the household utility
checkpoint only if evidence shows at least one of:

- stable contracts benefit from compiler-enforced dependency isolation;
- focused engine test time is materially impaired by the app target;
- repeated agent ownership conflicts occur at the boundary;
- reuse outside the application target becomes real rather than hypothetical;
- build measurements justify independent compilation.

Extraction would require a separate accepted ADR and PR. It must not be folded
into a Milestone 6 implementation slice.

## Security, privacy, rollout, and rollback

- No new user data leaves the device beyond existing TMDB requests.
- Do not log profile reactions, Watchlist contents, or full candidate snapshots
  as production analytics.
- Diagnostic quarantine remains local and is not uploaded.
- No new dependency, backend, AI framework, target, or minimum-iOS change.
- Release uses the existing TMDB attribution and credential boundaries.
- Each merged PR is independently buildable; rollback is the normal revert of
  the latest coherent slice.
- PR7 does not merge until the full feature is safe as the first tab. No remote
  feature flag is required for the household pilot.

## Required physical-device validation

On the Product Owner's pilot iPhone:

- install over the current Milestone 5 build;
- verify Viewer Profile, Watchlist, watched state, and Search History remain;
- confirm tab order and that Ask is not exposed;
- confirm initial Home generation and a relaunch retain the same set;
- confirm zero-to-three cards remain usable and route to Movie Detail;
- confirm provider logos agree with Spanish service availability;
- use `Give me three more` and verify no title from the prior set repeats;
- change a current title to watched and confirm repair does not reintroduce an
  earlier cycle title;
- change saved state and confirm the app remains coherent;
- exercise Retry using the implementation's controlled failure path when
  practical;
- install a later build and confirm the persisted set remains compatible.

After Milestone 6 closes, perform the separate required household utility
checkpoint before authorizing Milestone 7.

## Explicit non-goals

- feedback actions from Milestone 7;
- quick viewing-context controls;
- natural-language Ask exposure or implementation;
- trailers;
- analytics;
- automatic freshness expiration;
- catalog-wide rating;
- global unified watch history;
- Foundation Models, LLMs, embeddings, backend, accounts, or sync;
- runtime ranking or session intent;
- physical module extraction;
- tuning P1 from live behavior during implementation.

## Known accepted limitations

- Six Discover pages are bounded recall, not the full eligible catalog.
- TMDB genres and eras cannot represent themes, pacing, creator preference,
  categorical no-musical intent, or uncertain viewing memory.
- Incomplete watched evidence can still produce already-seen false positives.
- Deterministic templates are intentionally less expressive than generated
  prose.
- P1 constants require a reviewed later model revision; agents must not tune
  them to repair individual titles.

None of these limitations blocks implementation or authorizes hidden
title-specific rules.

## Engineering Ready record

There are no unresolved product or technical decisions that materially change
Milestone 6 contracts, persistence, migration, concurrency, failure behavior,
test strategy, or PR sequencing.

After D0 merges, an autonomous implementation agent may start PR1 from
`develop`. It must read this specification, ADR-011, `PRODUCT.md`,
`ENGINEERING.md`, and the repository delivery and verification policies before
changing production code.

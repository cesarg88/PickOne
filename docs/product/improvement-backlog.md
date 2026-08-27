# PickOne Product & Engineering Improvement Backlog

The product itself is defined canonically in [`PRODUCT.md`](../../PRODUCT.md).
This file tracks work; it must not become a competing product definition.

## Purpose

This is the living follow-up document for the product and engineering
recommendations identified during the initial CTO audit.

It contains only work that remains pending after Milestone 3.3. Completed work
should remain in this file with its status changed to `Completed` and a link to
the implementing PR or milestone.

Last reviewed: 2026-08-27, after Milestone 7 PR4 validation and PR4.5/PR5
engineering clarification.

## Product Direction

PickOne should not become another movie catalog. Its differentiating promise is
to:

> Give people a few personalized movie recommendations they can actually watch,
> so they can stop browsing and start watching.

Recommendation-first Home is the primary product surface. Onboarding,
availability, Detail, Watchlist, Search, Discovery, and the later Ask experience
support that decision.

## Status and Priority

Statuses:

- `Proposed`: identified but not yet accepted into the roadmap
- `Planned`: accepted and ready to be shaped into a milestone
- `Accepted — Engineering Ready`: executable milestone and architecture are
  approved; implementation may start after its documentation gate merges
- `In Progress`: implementation has started
- `Pilot Validation`: implemented but awaiting real-user validation
- `Completed`: merged and validated
- `Deferred`: intentionally outside the current product stage

Priorities:

- `P0`: validate before expanding the product or infrastructure
- `P1`: necessary for a credible recommendation beta
- `P2`: necessary before broader external distribution or scale

## P0 — Validate the Decision Product

### IMP-001 — Complete the two-person physical-device pilot

- Status: `Completed`
- Priority: `P0`
- Evidence: the pilot build installed and ran successfully on both target
  iPhones after PR #12.
- Implementation:
  - basic physical-device validation is complete
  - the reusable exhaustive checklist remains in
    `docs/pilot/pilot-checklist.md` for later release stages

### IMP-012 — Complete the Swift 6 concurrency migration

- Status: `Completed`
- Priority: `P0`
- Evidence: PR #13 and Milestone 3.4
- Reference: `docs/decisions/adr-008-swift-concurrency-baseline.md`
- Why now:
  the current product baseline and CI are stable, while upcoming backend and
  provider work will add more asynchronous boundaries. Migrating now is cheaper
  and safer than migrating after that complexity arrives.
- Completed result:
  - Swift 6 language mode and complete strict-concurrency checking are enabled
  - default global `MainActor` isolation was removed
  - UI and Presentation are explicitly `@MainActor`
  - mutable persistence and repositories have deliberate ownership
  - unchecked sendability suppressions were removed
  - the full suite and CI remained green
- Completion evidence:
  - strict concurrency builds without project warnings
  - unchecked conformances are removed
  - no user-visible behavior changes

### IMP-002 — Define Decision Engine v1

- Status: `Completed`
- Priority: `P0`
- Roadmap relationship: Milestone 6
- Accepted specification:
  [`Milestone 6 — Three for Tonight`](../milestones/milestone-6-three-for-tonight.md)
- Accepted architecture:
  [`ADR-011 — Deterministic Decision Engine v1`](../decisions/adr-011-deterministic-decision-engine-v1.md)
- Why: provider integration should implement an accepted product reasoning
  model rather than define the product accidentally.
- Completed result:
  - accepted the deterministic P1 affinity, similarity, quality, confidence,
    credibility, Watchlist-bonus, diversity, role, and tie-breaking rules
  - defined exact watched, cycle-history, and movie-level availability gates
  - separated pure scoring and selection from asynchronous candidate,
    availability, persistence, and refresh orchestration
  - accepted structured explanation evidence and semantic precedence
  - defined persistent Decision Sets, cycle identity, mutable eligibility,
    recovery, and deliberate refresh
  - translated synthetic fixtures A–M and frozen real-profile snapshots into
    mandatory automated regression coverage
  - kept Apple Foundation Models, runtime intent, feedback, backend, and
    physical module extraction outside Milestone 6
- Completion evidence:
  - accepted ADR-011 and its fixture, sanity-check, scoring, and AI-feasibility
    support documents
  - an Engineering Ready Milestone 6 specification with dependency-ordered PRs
    and no unresolved implementation decision

### IMP-019 — Define Viewer Profile & Onboarding v1

- Status: `Completed`
- Priority: `P0`
- Roadmap relationship: Milestone 5
- Depends on: IMP-009 availability identity and entitlement decisions
- Specification state: `Completed`
- Implementation: [PR #20](https://github.com/cesarg88/PickOne/pull/20)
- Automatic-completion correction:
  [PR #21](https://github.com/cesarg88/PickOne/pull/21)
- Validation evidence:
  local repository verification and GitHub Actions passed; the Product Owner
  reported satisfactory real-device pilot validation on 2026-08-04.
- Accepted specification:
  [`Milestone 5 — Viewer Profile & Onboarding`](../milestones/milestone-5-viewer-profile-onboarding.md)
- Accepted architecture:
  [`ADR-010 — Local Viewer Profile and Dynamic Viewing Context`](../decisions/adr-010-local-viewer-profile-and-dynamic-context.md)
- Why:
  PickOne cannot personalize or enforce watchability without a small, editable
  source of viewer context.
- Completed result:
  - define the two-minute onboarding flow
  - store Spain (`ES`) as the pilot region without exposing a country selector
  - capture the supported services without exposing TMDB internals
  - map the Product Owner's confirmed plan entitlements internally instead of
    presenting plan-variant choices
  - define the fixed 12-title primary calibration block, three-title normal
    reserve, optional low-signal extension, and response semantics
  - include neutral `It was okay` alongside positive and negative watched
    reactions, and calculate confidence from reactions rather than persist a
    derived counter
  - show Spain-localized movie titles with original or English title and year,
    backed by deterministic bundled fallback metadata
  - suppress a duplicate secondary title when both forms differ only by case
    and trivial whitespace
  - define skip, retry, edit, reset, migration, and failure behavior
  - persist one versioned local profile per installation
  - keep services in first-onboarding progress and out of recalibration drafts;
    recalibration completion uses the current active profile selection
  - keep calibration-derived seen knowledge separate from Watchlist in
    Milestone 5, then combine both sources for Milestone 6 exclusions
  - complete onboarding automatically after the last valid action, without a
    confirmation screen or save button; retain the completed draft and show
    retry if final persistence fails
  - keep accounts, sync, and household profiles out of the first version
- Done when:
  - every onboarding state and stored field has accepted behavior
  - the output is sufficient for availability and deterministic ranking
  - an implementation agent has no unresolved product decision

### IMP-020 — Validate household utility after Three for Tonight

- Status: `Completed`
- Priority: `P0`
- Roadmap relationship: Utility Checkpoint after Milestone 6
- Depends on: Milestones 4, 5, and 6
- Why:
  a working recommendation flow does not prove that PickOne reduces decision
  fatigue or gives the Product Owner credible, watchable choices.
- Validation:
  - use the complete flow on the physical pilot iPhone during real household
    movie decisions
  - assess whether recommendations make sense for the Product Owner
  - verify reported availability against the Product Owner's Spanish services
  - observe whether PickOne enables a confident choice quickly
  - record concise qualitative findings without adding external research or an
    analytics system
- Done when:
  - the Product Owner has accepted the flow as useful enough to continue, or
    the next refinement has been identified
  - Milestone 7 is confirmed, revised, or deferred from observed household use
- Evidence to date:
  - the complete Milestone 6 flow passed functional validation on the Product
    Owner's iPhone
  - validation identified the positive-anchor explanation correction, which
    merged with M6 in PR #31
  - the checkpoint confirmed Milestone 7 as the next investment and repeats
    after M7 with the enriched Taste Profile

### IMP-003 — Make recommendations the primary Home experience

- Status: `Completed`
- Priority: `P0`
- Depends on: IMP-002, IMP-009, and IMP-019
- Implementation specification:
  [`Milestone 6 — Three for Tonight`](../milestones/milestone-6-three-for-tonight.md)
- Implementation: [PR #31](https://github.com/cesarg88/PickOne/pull/31)
- Why: opening on a generic Top Rated grid communicates that PickOne is a
  catalog, while opening on Ask requires effort before the product demonstrates
  value.
- Implementation:
  - introduce onboarding for region, subscriptions, and taste calibration
  - make persistent `Three for Tonight` recommendations the first screen
  - add a visible `Give me three more` action
  - keep optional quick-context controls deferred; Milestone 6 uses one
    versioned default context without adding another user decision
  - expose `Home`, `Search`, `Discover`, `Watchlist`, and `Settings` in that
    order; retain Ask code without exposing its later-milestone tab
  - design first-use, returning-use, loading, empty, and failure states
- Done when:
  - a fresh launch exposes the core decision proposition immediately
  - a returning user receives three eligible recommendations without composing
    a request
- Implemented result:
  - Home is the first tab and presents a persistent zero-to-three Decision Set
    with roles, supported reasons, verified providers, explicit refresh, repair,
    Retry, and Movie Detail navigation
  - direct and Watchlist-wrapped positive anchors enumerate only their actual
    shared genre and supported era signals
  - P1 scoring remains unchanged and Fixture M protects the visible-evidence
    boundary
- Completion evidence:
  - local verification, CI, technical review, and functional iPhone validation
    passed
  - final M6 positive-anchor correction, Fixture M, and documentary closure
    merged in PR #31

### IMP-004 — Add continuous taste learning and unified movie state

- Status: `In Progress`
- Priority: `P0`
- Roadmap relationship: Milestone 7
- Accepted specification:
  [`Milestone 7 — Continuous Taste Learning`](../milestones/milestone-7-continuous-taste-learning.md)
- Accepted architecture:
  [`ADR-012 — Unified Local Viewer Movie State`](../decisions/adr-012-unified-local-viewer-movie-state.md)
- Why:
  static calibration cannot learn from deliberate later feedback, while the
  current independent calibration and Watchlist representations allow watched
  and preference meanings to diverge.
- Implementation:
  - introduce one Viewer Movie State for watched, reaction, `Not interested`,
    and Watchlist intent with the accepted transition table
  - derive Taste Profile from current reactions instead of persisting it
  - add rating, watched, Watchlist, and `Not interested` controls to Detail
  - expose ratings, watched-only movies, and `Not interested` through the
    accepted `My movies` Settings history
  - regenerate Home after reaction changes, inherit shown IDs, repair mutable
    eligibility, and reject stale snapshot identities
  - migrate and recover profile and Watchlist state without fabricating empty
    data or losing Search History
  - migrate valid Decision Set v1 data to v2 without publishing legacy
    recommendations, preserving exact bytes and all trusted shown IDs
  - prevent internal numeric genre IDs from appearing in recommendation copy
    by resolving readable explanation evidence before PR5
  - hydrate all current reaction metadata with bounded structured concurrency,
    deterministic ordering, cancellation, and no partial Taste Profile
- Progress:
  - PR1–PR4 merged as PR #33–#36
  - PR4 migration passed physical validation on the Product Owner's iPhone
  - PR4.5 human-readable recommendation evidence is the next slice; PR5 depends
    on it
- Done when:
  - Detail, Watchlist, calibration, Settings history, and Home agree for every
    movie state
  - deliberate reactions change future taste while `Not interested` remains a
    title-only exclusion
  - recommendation explanations never expose internal genre IDs
  - a failed current-reaction hydration never produces a silently incomplete
    personalized set
  - installed pilot state survives migration and all-source failure requires
    explicit destructive recovery

### IMP-022 — Deliver a remotely updateable calibration catalog

- Status: `Accepted — Engineering Ready`
- Priority: `P0`
- Roadmap relationship: Milestone 7
- Accepted architecture:
  [`ADR-013 — Remote Calibration Catalog`](../decisions/adr-013-remote-calibration-catalog.md)
- Why:
  improving recognition and diversity should not require an application
  release, but a network dependency must never make onboarding unreliable or
  change a flow already in progress.
- Implementation:
  - prefetch before calibration and bound visible unresolved waiting to two
    seconds
  - validate a complete versioned snapshot before use
  - resolve remote, last valid cache, then bundled fallback
  - freeze and persist the exact snapshot used by a draft
  - keep transport, hosting, credentials, and cache details outside Domain and
    Presentation
- Done when:
  - a valid remote catalog can update a later flow without an app release
  - cached and bundled flows work offline
  - relaunch and late responses cannot change an active flow

### IMP-005 — Define the product measurement contract

- Status: `Proposed`
- Priority: `P0`
- Why: UI polish and model changes cannot be evaluated without success
  criteria.
- Implementation:
  - define time-to-decision
  - measure sessions ending in `Watch this`
  - measure confirmed viewing after a decision
  - measure Detail, trailer, and Watchlist actions originating from Home
  - measure new-set requests, context refinements, and distinct negative
    feedback
  - record unresolved candidates, duplicates, already-watched results, and
    violated constraints
  - define latency and cost budgets before integrating a provider
  - document event names and allowed properties without collecting sensitive
    prompt data by default
- Done when:
  - each product hypothesis has a metric and expected signal
  - privacy boundaries and data retention are explicit

## P1 — Build a Credible Recommendation Beta

### IMP-021 — Define onboarding UX polish

- Status: `Proposed`
- Priority: `P1`
- Roadmap relationship: dedicated future UX-polish milestone, not Milestone 5
- Why:
  automatic onboarding completion should feel immediate, but progress and
  motion must be designed deliberately rather than added as part of the
  completion-flow correction.
- Future definition:
  - onboarding progress visualization
  - animations
  - transitions
  - completion feedback
- Constraint:
  Milestone 5 removes the redundant completion confirmation without adding a
  new progress indicator or prescribing these treatments.
- Done when:
  the Product Owner and CTO accept an executable UX specification grounded in
  physical-device use.

### IMP-006 — Use real Watchlist state in recommendation cards

- Status: `Proposed`
- Priority: `P1`
- Proposed roadmap relationship: Milestone 7
- Verified gap:
  `RecommendationCard` still keeps `didAddToWatchlist` as local UI state.
- Why:
  - an already-saved movie can still show `Add to Watchlist`
  - state can become stale after changes from Detail or Watchlist
- Implementation:
  - derive Watchlist membership and watched status from unified Viewer Movie
    State rather than presentation-local state
  - support add and remove rather than a one-way local flag
  - refresh state after navigation or centralize the source of truth
  - use watched state in recommendation filtering
- Done when:
  - Recommendation, Detail, and Watchlist always agree for the same movie
  - already-watched movies are excluded unless explicitly requested

### IMP-007 — Preserve domain movie data through Movie Detail presentation

- Status: `Proposed`
- Priority: `P1`
- Proposed roadmap relationship: Milestone 7
- Verified gap:
  `MovieDetailViewModel` reconstructs `MovieSummary` from formatted year,
  rating, and poster URL strings.
- Why: reverse-mapping presentation strings can lose precision and break under
  localization.
- Implementation:
  - retain the original `MovieSummary` or required domain values in the
    presentation model
  - remove `extractPosterPath`, `extractYear`, and `extractRating`
  - add mapping and localized-format regression tests
- Done when:
  - Watchlist mutations never reconstruct Domain from UI-formatted values

### IMP-023 — Define explicit decision-outcome actions

- Status: `Deferred`
- Priority: `P1`
- Why:
  Milestone 7 learns from explicit ratings, watched facts, Watchlist intent,
  and `Not interested`, but those signals do not prove that PickOne helped the
  Viewer choose and start a movie in the current session.
- Future definition:
  - distinguish `Watch this` intent from verified viewing
  - define temporary `Not tonight` behavior without learning a stable dislike
  - decide whether and when to ask for lightweight viewing confirmation
  - preserve recommendation-cycle history and avoid passive-event inference
- Constraint:
  do not add these actions to Milestone 7 or infer outcomes from Detail opens,
  trailer plays, or impressions.
- Done when:
  accepted product copy, state transitions, measurement semantics, and failure
  behavior distinguish intent from outcome.

### IMP-008 — Integrate one real recommendation provider behind a backend

- Status: `Deferred`
- Priority: `P1`
- Roadmap relationship: Deferred Intelligence Infrastructure
- Why: the local stub validates UI stability but cannot validate
  recommendation quality.
- Implementation:
  - build a small PickOne-owned backend or proxy
  - integrate one provider through the existing candidate contract
  - keep provider credentials out of the iOS application
  - return TMDB identifiers and short recommendation reasons
  - retain movie enrichment in the existing Domain/Data boundary
  - add a stub/real feature flag
  - enforce timeout, cancellation, result limit, cost budget, and fallback
  - add structured, privacy-safe request diagnostics
- Done when:
  - selected pilot users can use real recommendations
  - provider failure does not affect Discovery, Detail, Search, or Watchlist
  - cost, latency, resolution rate, and failure rate are observable

### IMP-009 — Add regional availability and a path to watch

- Status: `Completed`
- Priority: `P0`
- Evidence:
  [`TMDB Spain Streaming Availability Findings`](../research/tmdb-es-streaming-availability-findings.md)
- Implementation: [PR #16](https://github.com/cesarg88/PickOne/pull/16)
- Specification:
  [`Milestone 4 — Availability Foundation`](../milestones/milestone-4-availability-foundation.md)
- Architecture:
  [`ADR-009 — Availability Boundary and Verification`](../decisions/adr-009-availability-boundary-verification.md)
- Roadmap relationship: Milestone 4
- Why: a good movie recommendation is less useful if it is not available in
  the user's country or services.
- Completed result:
  - use Spain and the accepted provider allowlist: Netflix `8`, Amazon Prime
    Video `119`, Disney Plus `337`, and HBO Max `1899`
  - require the exact selected provider in movie-level `ES.flatrate`
  - model selected entitlement as included without additional payment
  - reject rent, buy, stores, and unselected add-on channels
  - distinguish eligible, ineligible, and unknown evidence
  - show every verified selected provider directly in Movie Detail
  - load availability independently from the rest of Movie Detail
  - show availability with freshness and coverage caveats and provider-logo
    fallback text
  - revalidate before a handoff when evidence is older than 24 hours
  - attribute TMDB and JustWatch
  - use the returned country-specific TMDB watch page only as a secondary pilot
    handoff
- Done when:
  - the Domain contract exposes only current eligible evidence as acceptable
    for future primary recommendations
  - Detail communicates every verified included service without requiring a tap
  - source failure cannot silently become an unavailable result
  - no handoff is constructed or presented as a provider deep link

### IMP-010 — Implement privacy-safe analytics and operational observability

- Status: `Proposed`
- Priority: `P1`
- Depends on: IMP-005 and IMP-008
- Implementation:
  - implement the accepted product events and funnels
  - add crash and non-fatal error reporting
  - observe provider latency, cost, timeout, and resolution failures
  - avoid sending raw prompts or personal state unless explicitly justified
  - document consent, retention, deletion, and production access
- Done when:
  - product outcomes and production failures can be evaluated without exposing
    unnecessary user data

## P2 — Harden for Distribution and Scale

### IMP-011 — Version and observe local persistence

- Status: `Proposed`
- Priority: `P2`
- Current baseline: corrupt Watchlist bytes are preserved and mutation errors
  are surfaced, but reads can still collapse into an empty list.
- Implementation:
  - deliver the Milestone 7 versioned viewer-state envelope, previous-valid
    recovery, exact-byte quarantine, and legacy profile/Watchlist migration
  - distinguish missing, corrupt, unsupported, recovered, and all-source failure
  - define explicit destructive recovery only when no trusted source remains
  - make Search history writes observable where failure matters
  - add migration and recovery tests
- Done when:
  - upgrades cannot silently discard or replace recoverable user state
- Scope note:
  Milestone 7 resolves viewer profile, Movie reaction, watched, and Watchlist
  recovery. Search History remains independent follow-up work.

### IMP-013 — Complete external-distribution readiness

- Status: `Proposed`
- Priority: `P2`
- Current baseline:
  temporary icon, privacy manifest, TMDB attribution, Release build, and bundle
  inspection are complete.
- Implementation:
  - replace the temporary codename icon with accepted brand assets
  - create privacy policy and terms appropriate to actual data collection
  - prepare App Store metadata, screenshots, support URL, and release notes
  - validate signing, Archive, export, and TestFlight
  - review TMDB and watch-provider attribution after feature changes
  - establish semantic versioning and a release process
- Done when:
  - an archived build passes App Store validation and beta distribution checks

### IMP-014 — Decide supported devices, accessibility, and localization

- Status: `Proposed`
- Priority: `P2`
- Why: the target currently declares iPhone and iPad support without a
  documented iPad QA commitment.
- Implementation:
  - choose iPhone-only or define supported iPad layouts and test coverage
  - validate Dynamic Type, VoiceOver, contrast, Reduce Motion, and keyboard
    behavior
  - externalize user-facing copy and define the first supported languages
  - localize dates, ratings, region, and availability correctly
- Done when:
  - every declared platform, orientation, and language has an explicit quality
    bar

### IMP-015 — Decide the product name and brand

- Status: `Deferred`
- Priority: `P2`
- Why: `PickOne` remains an effective codename but has weak differentiation as
  a commercial brand.
- Implementation:
  - revisit naming after the decision experience is validated
  - perform App Store, domain, social, and trademark screening
  - define visual identity and replace temporary pilot assets
- Done when:
  - the product has an accepted name with practical availability checks

### IMP-016 — Align roadmap sequencing with learned architecture

- Status: `Proposed`
- Priority: `P2`
- Why: the roadmap currently places `AI Provider Abstraction` before the first
  provider, which risks designing a hypothetical abstraction.
- Implementation:
  - move the first real provider vertical before generalized multi-provider
    abstraction
  - extract a broader abstraction only after a second implementation creates
    real variation
  - update architecture diagrams to distinguish control flow
    (`Presentation → Domain → Data`) from dependency direction
    (`Presentation → Domain ← Data`)
- Done when:
  - roadmap and architecture documentation reflect the chosen sequence

### IMP-017 — Continue repository and CI hygiene

- Status: `Proposed`
- Priority: `P2`
- Implementation:
  - confirm the historically exposed token was revoked, not only removed
  - prune obsolete temporary remote branches
  - mark the old CTO context-transfer document as historical or remove it
  - decide whether CI should publish test results and coverage artifacts
  - introduce a coverage policy only for critical business and state logic,
    not a vanity global percentage
- Done when:
  - repository history, active branches, and operational documentation have
    clear ownership and no misleading state

### IMP-018 — Decide the long-term Search scope

- Status: `Deferred`
- Priority: `P2`
- Current baseline: Search correctly promises title search only.
- Decision:
  - retain a focused title-only search, or
  - implement a deliberate multi-entity experience for people and directors
- Done when:
  - product copy, endpoint behavior, result types, and navigation agree

## Intentionally Deferred

The following should not be implemented merely because they are technically
interesting:

- multi-provider abstraction before a second provider exists
- streaming responses
- long-term conversation memory
- authentication and cross-device sync
- social features, user reviews, and ratings
- push notifications
- heavy personalization or collaborative filtering

Move an item out of this section only when a validated product need justifies
the added complexity.

## Suggested Sequence

1. Merge the accepted Milestone 7 D0 specification, glossary, ADR-012, and
   ADR-013.
2. Implement Milestone 7 through its eleven small, sequential PR slices for
   pure state, storage/migration, production cutover, Decision Set v2 migration,
   human-readable recommendation evidence, Home, Detail, `My movies`, remote
   catalog, calibration integration, and closure.
3. Repeat the household utility checkpoint with continuous taste learning.
4. Define explicit decision outcomes, trailers, and the minimum pilot
   measurement contract from observed use.
5. Introduce a backend or AI provider only if product validation demonstrates
   a need that deterministic recommendation cannot meet.
6. Complete distribution, accessibility, and persistence hardening as the
   audience expands.

## Update Rules

When work starts:

1. change the item status to `In Progress`
2. link the milestone, issue, or PR
3. keep the original rationale and completion criteria

When work is merged:

1. change the status to `Completed`
2. add the merge PR and validation evidence
3. record follow-up work as a new item instead of silently expanding scope

# PickOne Product & Engineering Improvement Backlog

The product itself is defined canonically in [`PRODUCT.md`](../../PRODUCT.md).
This file tracks work; it must not become a competing product definition.

## Purpose

This is the living follow-up document for the product and engineering
recommendations identified during the initial CTO audit.

It contains only work that remains pending after Milestone 3.3. Completed work
should remain in this file with its status changed to `Completed` and a link to
the implementing PR or milestone.

Last reviewed: 2026-07-27, after PR #12.

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

- Status: `Planned`
- Priority: `P0`
- Next implementation milestone: Milestone 3.4
- Reference: `docs/decisions/adr-008-swift-concurrency-baseline.md`
- Why now:
  the current product baseline and CI are stable, while upcoming backend and
  provider work will add more asynchronous boundaries. Migrating now is cheaper
  and safer than migrating after that complexity arrives.
- Verified gap:
  the project remains in Swift 5 language mode with default `MainActor`
  isolation and several `@unchecked Sendable` conformances.
- Implementation:
  - enable Swift 6 language mode in a dedicated milestone
  - remove default global `MainActor` isolation
  - keep UI and presentation explicitly `@MainActor`
  - isolate mutable persistence and repositories deliberately
  - remove `@unchecked Sendable` case by case
  - keep the full suite green throughout the migration
- Done when:
  - strict concurrency builds without project warnings
  - unchecked conformances are removed or individually justified
  - no user-visible behavior changes

### IMP-002 — Define Decision Engine v1

- Status: `Planned`
- Priority: `P0`
- Roadmap relationship: Epic 2.2
- Why: provider integration should implement an accepted product reasoning
  model rather than define the product accidentally.
- Implementation:
  - define stable preference, current-context, region, subscription,
    availability, and watched-state inputs
  - define supported intent dimensions: mood, genre, pace, runtime, company,
    era, references, and exclusions
  - define behavior for sparse, conflicting, and impossible constraints
  - default to three strong recommendations
  - define how one item becomes the best choice
  - specify diversity, constraint, duplicate, and already-watched policies
  - turn Home, quick-context, and future Ask strategy into executable
    acceptance cases
- Done when:
  - representative prompt fixtures and expected decisions are documented
  - the rules can be tested independently of an AI provider

### IMP-003 — Make recommendations the primary Home experience

- Status: `Proposed`
- Priority: `P0`
- Why: opening on a generic Top Rated grid communicates that PickOne is a
  catalog, while opening on Ask requires effort before the product demonstrates
  value.
- Implementation:
  - introduce onboarding for region, subscriptions, and taste calibration
  - make persistent `Three for Tonight` recommendations the first screen
  - add a visible `Give me three more` action
  - provide optional quick context without requiring free text
  - keep Discovery and Search available as supporting paths
  - design first-use, returning-use, loading, empty, and failure states
- Done when:
  - a fresh launch exposes the core decision proposition immediately
  - a returning user receives three eligible recommendations without composing
    a request

### IMP-004 — Add explicit decision and feedback actions

- Status: `Proposed`
- Priority: `P0`
- Why: showing recommendations does not prove that PickOne helped the user
  decide.
- Implementation:
  - identify one result as `Best pick` or equivalent product copy
  - add explicit `Watch this`, `Save for later`, `Not tonight`,
    `Not interested`, and `Already watched` actions
  - define which actions affect temporary context and which affect stable taste
  - confirm viewing later without treating intention as verified consumption
  - preserve a small result set instead of expanding into an infinite feed
- Done when:
  - the product can distinguish recommendation impressions from decisions
  - negative feedback can refine or replace a recommendation

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

### IMP-006 — Use real Watchlist state in recommendation cards

- Status: `Proposed`
- Priority: `P1`
- Verified gap:
  `RecommendationCard` still keeps `didAddToWatchlist` as local UI state.
- Why:
  - an already-saved movie can still show `Add to Watchlist`
  - state can become stale after changes from Detail or Watchlist
- Implementation:
  - provide membership and watched status through the recommendation snapshot
    or a dedicated use case
  - support add and remove rather than a one-way local flag
  - refresh state after navigation or centralize the source of truth
  - use watched state in recommendation filtering
- Done when:
  - Recommendation, Detail, and Watchlist always agree for the same movie
  - already-watched movies are excluded unless explicitly requested

### IMP-007 — Preserve domain movie data through Movie Detail presentation

- Status: `Proposed`
- Priority: `P1`
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

### IMP-008 — Integrate one real recommendation provider behind a backend

- Status: `Planned`
- Priority: `P1`
- Roadmap relationship: Epic 2.4 should precede a generalized provider
  abstraction.
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

- Status: `Proposed`
- Priority: `P1`
- Why: a good movie recommendation is less useful if it is not available in
  the user's country or services.
- Implementation:
  - define how the active country/region is selected and changed
  - collect and maintain the user's selected subscription services
  - evaluate TMDB watch-provider data and its attribution requirements
  - show availability with freshness and coverage caveats
  - require subscription-included regional availability for primary
    first-version recommendations
  - distinguish included, ads, free, rent, and buy availability
  - provide a clear next action to open an available service when supported
- Done when:
  - recommendation decisions enforce active region, selected provider, and
    accepted monetization type
  - the user can understand where a selected movie may be watched

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
  - define a versioned persistence envelope and migration policy
  - distinguish missing, corrupt, and unsupported data
  - define safe recovery UX instead of silently presenting an empty list
  - make Search history writes observable where failure matters
  - add migration and recovery tests
- Done when:
  - upgrades cannot silently discard or replace recoverable user state

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

1. Run the Swift 6 migration as the next isolated technical milestone.
2. Define the first-version onboarding, Home, availability, feedback, and
   measurement specifications from `PRODUCT.md`.
3. Define Decision Engine v1 against preferences, viewing context, and
   availability.
4. Implement onboarding, regional subscription eligibility, persistent
   `Three for Tonight`, and explicit decision actions in bounded milestones.
5. Fix recommendation Watchlist state and Detail domain preservation.
6. Build one real backend/provider vertical only where the accepted decision
   strategy needs it.
7. Add privacy-safe analytics and operational observability.
8. Complete distribution, accessibility, and persistence hardening as the
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

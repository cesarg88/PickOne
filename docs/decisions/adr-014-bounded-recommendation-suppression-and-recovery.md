# ADR-014 — Bounded Recommendation Suppression and Exhaustion Recovery

## Status

Proposed — accepted product direction; exact D0 policy awaiting Product Owner
approval

Milestone 7 was reopened after final physical-device validation found that
normal explicit feedback could exhaust the bounded recall pool permanently.
This ADR proposes the persistence and orchestration correction. It changes no
P1 score, credibility threshold, availability rule, reaction meaning, or
explicit Viewer Movie State exclusion.

## Context

The final Milestone 7 implementation stores every previously presented movie
ID in one inherited `shownMovieIDs` set. Input assembly excludes that complete
set from six TMDB Discover pages on every generation. The same set is reused by
`Give me three more`, inherited after a reaction, and preserved after
`Reset preferences`.

The Product Owner's blocked pilot installation provided the decisive evidence:

- 93 distinct shown movie IDs;
- 47 persisted watched movie IDs;
- 113 IDs in their union;
- zero recommendations in the active Decision Set;
- repeated deterministic refreshes returning the same empty result;
- preference reset preserving the valid watched facts but not recovering Home.

Six Discover pages contain at most 120 raw candidates before exact
availability, credibility, and malformed-candidate removal. The implementation
therefore exhausted its own search space even though older shown titles without
feedback remained legitimate future options.

The correction must preserve explicit feedback and complete diagnostic history
while making temporary repeat suppression bounded and recoverable.

## Decision

### Hard exclusions and temporary suppression

These remain non-negotiable hard gates:

- watched, including every Movie reaction;
- `Not interested`;
- malformed identity;
- unknown or ineligible exact movie-level availability;
- failed P1 credibility admission.

The active recommendation IDs are also excluded from an explicit replacement
request. They are never offered as the result of `Give me three more`.

Previously shown without feedback is not a permanent eligibility exclusion. It
is a temporary suppression policy applied after hard gates and before final
selection. P1 score and tie-breaking do not change.

### Complete history and recent suppression

Decision Set v3 stores two separate concepts:

1. `allShownMovieIDs`: every distinct movie ID ever presented by this
   installation. IDs are never removed by refresh, feedback, rollover, profile
   reset, or migration. This is diagnostic history, not a hard gate.
2. `recentlyShownMovieIDs`: an oldest-to-newest ordered list containing at most
   the 30 most recently presented distinct IDs. This is the normal temporary
   suppression window.

Thirty IDs represent ten complete three-movie sets. This prevents near-term
repetition while leaving substantially more room than the unbounded policy in
the diagnosed 93-shown/47-watched installation. If an older title is presented
again after rollover, it moves to the newest end. The active Decision Set is
tracked separately and remains excluded even if rollover has released its ID
from the bounded window.

`allShownMovieIDs` is complete distinct-ID history, not an unbounded analytics
event log. PickOne does not add impression timestamps or passive analytics in
this correction.

### Progressive recall and rollover

One generation request uses these deterministic stages against one immutable
trusted Viewer State snapshot:

1. **Normal recall:** pages 1 through 6, hard exclusions, active-set exclusion,
   and the full recent window.
2. **First expansion:** add pages 7 through 12 and recompute from the cumulative
   pool under the same gates.
3. **Final expansion:** add pages 13 through 20 and recompute from the cumulative
   pool. An empty page may terminate further paging early.
4. **Rollover:** if fewer than three recommendations survive, release the three
   oldest non-active IDs from recent suppression, recompute against the
   cumulative pool, and repeat until three survive or every non-active recent
   ID has been released.

Rollover mutates a working copy of the recent window. A successful Decision Set
or typed exhausted outcome persists that released window plus any newly
presented IDs. Failure, cancellation, or stale-work rejection persists no
history change. This prevents a later operation with unchanged inputs from
secretly repeating the same rollover stages.

Never-shown titles are always preferred over previously shown titles that
rollover makes available. After the final page expansion, orchestration first
runs the unchanged P1 selection over the never-shown credible pool. Any
selected never-shown titles are protected while rollover fills only its vacant
slots from newly released candidates; Domain then reassigns roles and rebuilds
evidence over the composed set. A higher-scoring rollover title cannot displace
an already selected never-shown title. Normal deterministic P1 ordering applies
within each tier. This is an orchestration admission policy, not a score bonus
or P1 formula change.

Availability work remains bounded and cancellable under the coordinator's
single actor owner. Pages are fetched once per operation, candidates are
deduplicated across stages, and existing fresh availability evidence is reused.
A transport, hydration, persistence, or cancellation failure is not exhaustion
and follows the existing retryable-failure contract.

`Give me three more` executes the complete progressive strategy in one action.
It cannot require repeated taps to advance hidden stages.

### Smaller and exhausted outcomes

If the full strategy yields one or two recommendations, PickOne publishes the
honest smaller set and marks the strategy exhausted for the current trusted
inputs. It does not continue presenting an operation known to be a deterministic
no-op.

If it yields zero:

- an existing non-empty set that remains provably safe is retained rather than
  replaced by empty content;
- without a retained set, PickOne persists a typed exhausted outcome bound to
  the current Viewer State snapshot, cycle signature, suppression epoch, and
  search policy version, together with `exhaustedAt` from the injected clock;
- relaunch restores that outcome without repeating the same network and
  scoring work;
- a relevant Viewer State, services, context, engine, or search-policy change
  invalidates the outcome and permits generation again.

The exhausted state is successful and distinct from failure. It never relaxes
hard gates.

### Exhaustion freshness

Exhaustion suppresses an unchanged deterministic retry for exactly 24 hours;
it is not permanent. Domain calculates freshness from persisted `exhaustedAt`
and the injected current wall-clock time:

- age less than 24 hours remains fresh and blocks the same explicit refresh;
- age equal to or greater than 24 hours is expired and permits one new complete
  progressive strategy;
- a relevant input, epoch, engine, or search-policy change still invalidates it
  immediately, without waiting for expiry;
- relaunch, backgrounding, and foregrounding do not extend the original
  timestamp;
- failure, cancellation, or stale-work rejection never advances
  `exhaustedAt`;
- another successful exhausted evaluation records the new completion time and
  begins a new 24-hour suppression interval.

An expired outcome remains diagnostic history but is no longer a compatibility
gate. Home does not retry automatically in the background. While visible, it
re-evaluates freshness on activation/foreground and at the one-shot expiry
deadline; it then restores `Give me three more`. The next user action executes
the complete strategy and revalidates stale availability through the existing
availability policy.

### Reset preferences

The local Viewer State envelope gains an opaque
`recommendationSuppressionEpochID`:

- it is created for a fresh installation and during v2-to-v3 migration;
- ordinary reactions, watched, `Not interested`, Watchlist, service edits, and
  recalibration preserve it;
- a successful `Reset preferences` transaction assigns a fresh value while it
  removes reactions and `Not interested` and preserves watched and Watchlist;
- the Decision Set records the source epoch.

An epoch mismatch clears only `recentlyShownMovieIDs` and an exhausted outcome.
It preserves `allShownMovieIDs`. Because the epoch changes in the same
actor-owned Viewer State transaction as preference reset, no second best-effort
write to recommendation storage is required.

The non-reusable Viewer State snapshot identity remains the stale-publication
guard. The suppression epoch expresses reset semantics; it does not replace the
snapshot identity.

### Stable reconciliation after feedback

A reaction still derives a new Taste Profile and cycle signature. Before
filling the affected slot, the coordinator reevaluates the other visible
recommendations against the complete new Taste Profile and current availability:

- retain each title that remains hard-eligible and credible;
- rebuild its role and structured explanation from the new snapshot;
- never retain stale explanation evidence merely to preserve visual stability;
- remove the reacted title because a reaction means watched;
- fill only missing slots through the progressive strategy.

The expected result is that one reaction replaces one card. Additional cards
change only when the new evidence proves they are no longer eligible, credible,
or explainable.

Watched and `Not interested` remain title-local eligibility repairs. They
normally remove only the affected card, retain the other valid cards, and fill
the open slot through the same progressive strategy. `Not interested` remains
absent from Taste Profile computation.

## Persistence and migration

### Viewer State v2 to v3

The migration adds one valid suppression epoch while preserving profile,
draft, reactions, watched, `Not interested`, Watchlist, migration record,
display metadata, state times, and Search History. Active/previous recovery,
semantic validation, quarantine, and non-reusable snapshot identity continue
to follow ADR-012.

### Decision Set v2 to v3

For a semantically valid v2 envelope:

- copy every v2 `shownMovieID` into `allShownMovieIDs`;
- initialize `recentlyShownMovieIDs` only from the current recommendation IDs in
  their displayed role order, because v2 has no trustworthy earlier chronology;
- do not fabricate order for the other legacy shown IDs;
- record the current suppression epoch and source Viewer State snapshot;
- do not invent an `exhaustedAt` value for a non-empty v2 set;
- persist a valid v3 replacement before publishing it;
- preserve the exact v2 bytes until replacement succeeds.

A valid non-empty v2 set may remain visible only when its snapshot, signature,
eligibility, availability, and explanation evidence are still current. A valid
empty v2 set has no trustworthy exhaustion timestamp and triggers automatic
progressive recovery instead of being restored as a permanent terminal result.

For the diagnosed blocked installation, all 93 legacy shown IDs remain in
diagnostic history, its valid watched and reaction exclusions remain hard, its
recent window starts empty because the v2 set has no recommendations, and the
progressive strategy may reuse only older shown titles without explicit
feedback when never-shown recall is insufficient.

Corrupt and unsupported v2 bytes retain the existing exact-byte quarantine
behavior. No partial history is guessed from invalid data, and no failure
manufactures an empty envelope.

## Presentation contract

### Exhausted copy and actions

When no current set exists after the complete strategy:

- title: `No picks available right now`
- description: `We've checked more movies and revisited older suggestions, but
  couldn't find an unseen match we can confidently recommend from your
  services.`
- primary action: `Review My movies`
- secondary action: `Review streaming services`

The actions navigate directly to the relevant existing surfaces. A fresh
exhausted state does not show `Give me three more` or `Retry`. Retry remains
reserved for transient failure. At the 24-hour boundary, `Give me three more`
becomes the primary action without removing either recovery action. This rule
applies equally to zero, partial, and retained-safe-set exhausted presentation.

If an explicit refresh cannot replace a still-safe non-empty active set, Home
keeps those cards and shows:

- title: `No more picks available right now`
- description: `We couldn't find a different unseen match we can confidently
  recommend from your services. Your current picks are still available.`

It exposes the same two recovery actions and hides `Give me three more` until a
relevant input or suppression epoch changes or the 24-hour exhaustion interval
expires.

An exhausted one- or two-title set keeps its cards and shows secondary copy:

> We found only {count} strong match(es) right now.

It exposes the same two recovery actions instead of another deterministic
refresh while exhaustion is fresh. `Give me three more` returns after expiry.

## Request and latency evidence

The twenty-page path is rare but potentially expensive. P0-2 adds an injected,
privacy-safe diagnostics sink around one generation operation. It records no
movie IDs, titles, profile data, providers, or feedback. For debug and test
evidence it reports:

- highest recall stage reached and total wall-clock duration;
- duration to the first usable set and duration of each recall stage;
- Discover page requests and unique recalled candidates;
- candidate availability checks, actual availability network misses, and cache
  hits;
- reaction-metadata hydration requests;
- maximum simultaneous Discover, availability, and Taste hydration work.

The deterministic cold-cache ceiling attributable to the search policy is 20
Discover requests plus at most 400 candidate availability network requests:
420 outbound requests. Reaction metadata hydration is recorded separately
because its count is the current number of reactions rather than a search-
policy constant. Existing limits remain at most eight simultaneous availability
checks and four simultaneous Taste hydrations. Discover requests remain
sequential unless measured device evidence justifies a separate concurrency
change.

P0-4 must exercise a real twenty-page expansion on a physical iPhone and record
the exact final-SHA values in its PR and milestone closure: device, network
condition, cold/warm cache condition, stage reached, each request count,
maximum concurrency, time to first usable set, and total duration. If the
preserved blocked installation recovers before page 20, a debug-only,
non-persisting injected scenario must force the same production orchestration
through page 20 without modifying application data. No numeric UX latency SLA
is accepted before this first measurement; final M7 approval requires Technical
Lead review and Product Owner acceptance of the observed wait.

The diagnostics value is immutable and `Sendable`; one operation-local owner
updates its counters. An injected nonthrowing sink receives the final snapshot,
while production composition uses a no-op sink. Diagnostics cannot alter
selection, persistence, cancellation, or visible error behavior, and its output
is never stored in the viewer-state or Decision Set envelopes.

### Quick feedback interaction

Each Home card adds one trailing ellipsis `Menu` whose accessibility label is
`Feedback for {movie title}`. The card body remains the Movie Detail navigation
target; the menu is a separate control and does not create nested button
semantics.

The menu contains:

- a `Rate` section with `Love it`, `Like it`, `It was okay`, and `Didn't like
  it`;
- `Already watched`, which records watched without a reaction;
- `Not interested`.

A rating implies watched. Every successful action removes the affected current
card and starts the accepted reconciliation. While its write is in progress,
that card's menu is disabled and shows local progress without blocking the
other cards. On write failure, the card and Decision Set remain unchanged and
PickOne presents:

- title: `Couldn't save feedback`
- message: `Your feedback wasn't saved. Please try again.`
- actions: `Try again` and `Cancel`.

Undo and editing remain in Movie Detail and `My movies`; the quick menu does not
duplicate a full state editor.

## Architecture and concurrency

- Domain owns hard exclusions, recent suppression, search stages, rollover,
  stable reconciliation, typed exhaustion, and v3 semantic invariants.
- Data owns v2/v3 decoding, mapping, exact-byte preservation, TMDB paging, and
  persistence.
- Presentation owns menu state, progress, copy, navigation, and retry intent.
- an operation-local diagnostics owner and injected no-op-by-default sink
  observe request/latency evidence without entering product state;
- `ThreeForTonightCoordinator` remains the single actor owner of generation and
  Decision Set publication.
- `LocalViewerStateRepository` remains the single actor owner of the suppression
  epoch and preference-reset transaction.
- Every stage captures and rechecks Viewer State snapshot identity; cancellation
  stops paging, enrichment, persistence, and Presentation publication.
- P1 remains pure and synchronous. No physical module or new dependency is
  introduced.

## Consequences

### Positive

- explicit feedback is never sacrificed to recover Home;
- near-term repetition remains bounded and deterministic;
- an installation blocked under v2 can recover in place;
- refresh advances one complete strategy instead of looping invisibly;
- reactions normally preserve unaffected cards;
- persisted exhaustion is explainable and does not repeat expensive work.
- an exhausted result can observe later TMDB catalog or availability changes
  after its bounded 24-hour freshness interval.

### Costs

- Viewer State and Decision Set both require supported v3 migrations;
- rare recovery operations may request up to twenty Discover pages;
- worst-case cold search may perform up to 420 outbound candidate-discovery and
  availability requests and therefore requires measured device evidence;
- preserving stable cards requires rebuilding current recommendation evidence;
- v2 cannot reconstruct historical presentation order, so migration must treat
  non-current legacy shown IDs as old without fabricating recency.

## Alternatives rejected

### Clear all shown history when empty

Rejected because it loses diagnostic evidence, can cause immediate repeats,
and cannot distinguish normal refresh from recovery.

### Increase six pages but keep permanent suppression

Rejected because any finite recall boundary can eventually be exhausted again.

### Relax watched, Not interested, availability, or credibility

Rejected because it breaks explicit user intent or the core watchability and
trust promises.

### Make Reset preferences delete watched history

Rejected because watched is an independent fact and the Product Owner explicitly
requires it to survive preference reset.

## Approval gate

Implementation may begin only after the Product Owner accepts together:

- the 30-title recent window;
- 6→12→20 page expansion;
- three-ID oldest-first rollover;
- exhausted copy and navigation actions;
- 24-hour exhaustion freshness and restored refresh behavior;
- required twenty-page physical request/latency evidence;
- the trailing quick-feedback menu;
- Viewer State v3 and Decision Set v3 migration behavior.

## Related documents

- [`PRODUCT.md`](../../PRODUCT.md)
- [Product Language Glossary](../product/product-language-glossary.md)
- [Milestone 7 — Continuous Taste Learning](../milestones/milestone-7-continuous-taste-learning.md)
- [Milestone 7 P0 — Home Exhaustion Recovery](../milestones/milestone-7-p0-home-exhaustion-recovery.md)
- [ADR-011 — Deterministic Decision Engine v1](adr-011-deterministic-decision-engine-v1.md)
- [ADR-012 — Unified Local Viewer Movie State](adr-012-unified-local-viewer-movie-state.md)

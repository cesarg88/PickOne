# ADR-015 — Local Decision Sessions, Measurement, and Viewing Provenance

## Status

Proposed — Ready for D0 review

Product behavior was accepted on `2026-09-14`. This ADR and
[Milestone 8](../milestones/milestone-8-pilot-measurement.md) must be reviewed
and accepted together before implementation begins.

## Context

Milestone 7 owns three established local authorities:

- Viewer Movie State owns watched, Movie reaction, `Not interested`, and
  Watchlist intent;
- Decision Set persistence owns current recommendations and recommendation-
  cycle history;
- Viewer Profile owns region, services, and calibration lifecycle.

None can answer whether PickOne helped the Viewer choose and then watch a movie.
A Detail open, passive impression, existing rating, or Watchlist action is not
a decision outcome. Adding session events to Decision Set persistence would
mix recommendation generation with measurement. Adding them to Viewer Movie
State would mix mutable per-movie state with bounded session history.

Milestone 8 also needs two different retention rules:

- completed pilot-measurement sessions expire after 180 days and may be
  exported or deleted;
- confirmed PickOne viewing provenance must remain visible independently from
  metric retention while the watched fact remains current.

The confirmation flow crosses session measurement and Viewer Movie State. The
stores cannot commit atomically, so interruption between writes must converge
after relaunch without undoing an accepted watched fact or inventing
provenance.

All pilot measurement remains local. The design should permit a future remote
analytics projection without coupling Domain to Mixpanel, Firebase, or a
generic property dictionary.

## Decision

### Separate local authorities

Maintain two explicit authorities.

#### Viewer Movie State

`ViewerMovieStateRepository` remains the source of current per-movie meaning
and gains optional durable PickOne viewing provenance equivalent to:

```text
PickOneViewingProvenance
├── source = homePick
├── confirmationOperationID
└── confirmedAt
```

The provenance is admitted only by an idempotent transition that confirms a
specific Pick as watched. It:

- implies watched;
- is not a Movie reaction or satisfaction value;
- does not affect Taste Profile, score, eligibility, credibility, availability,
  Watchlist, or recommendation-cycle identity;
- survives Reset preferences and pilot-measurement deletion while watched
  remains current;
- is shown by `My movies` only while watched is current.

Marking the movie unwatched removes the current provenance together with its
watched meaning and hides the badge. It never deletes or rewrites retained
session history. Marking the movie watched again does not infer or restore
provenance.

The accepted Viewer Movie State reducer remains the only mutation boundary.
Presentation cannot write provenance independently.

#### Viewing Decision

A new `ViewingDecisionRepository` owns recommendation sessions, decision
history, pending confirmations, measurement retention, and report inputs. It
does not own current watched, reaction, Watchlist, or recommendation state.

Domain exposes semantic values and operations rather than
`track(name:properties:)`. Working concepts are:

- `DecisionSessionID` and `ViewingDecisionID`: opaque non-reusable identities;
- `RecommendationSession`: foreground timing, activity boundary, observed
  Decision Set identities, explicit refresh count, bounded search evidence, and
  one decision chain;
- `ViewingDecision`: movie ID, source Decision Set/cycle/role, Pick timing,
  active/superseded/cancelled state, confirmation schedule and outcome, and
  optional Satisfaction snapshot;
- `PilotMeasurementSummary`: a derived projection, never persisted as a second
  source of truth.

Movie titles, posters, provider payloads, and full recommendation content are
not duplicated. Presentation joins current metadata through existing movie and
Viewer Movie State boundaries.

### Recommendation-session lifecycle

A session begins when active Home displays at least one usable recommendation.
The start operation records the surface-visible timestamp and first observed
Decision Set identity. Related Movie Detail navigation remains inside the same
session.

`Give me three more` records one explicit request. A resulting Decision Set is
added only when visible and is deduplicated by identity. It never starts a new
session.

Timing follows these rules:

- only foreground intervals accumulate;
- background closes the current foreground interval;
- wall-clock `lastMeaningfulActivityAt` still determines inactivity;
- after 30 minutes without activity, an undecided session becomes
  `abandoned`; a session with an active Pick finalizes with that decision;
- returning after the boundary starts another session when a usable Home or
  related surface becomes visible;
- an older Decision Set may be observed and selected in the new session.

The session records foreground time to the first successful Pick and the final
active Pick. Replacing a Pick marks the previous decision `superseded`;
cancelling marks it `cancelled`. These statuses carry no watched or
satisfaction meaning.

App lifecycle and surface events may arrive out of order. A Pick operation
first attempts to start or resume from trustworthy visible-surface evidence.
If no such evidence exists, Domain persists the decision with timing
`unavailable`. That decision remains confirmable but is excluded from every
time-to-decision denominator. Zero is never used as recovery data.

### Pick validation and idempotence

The Pick use case receives the visible recommendation identity, movie ID,
Decision Set ID, cycle identity, and role. It validates their consistency with
the current Presentation snapshot without rerunning the Decision Engine.

Every mutation carries a stable operation ID. Repeating an accepted operation
returns the committed result without adding events, changing timestamps, or
inflating counters. Stale Presentation completion cannot replace a newer active
decision.

Pick persistence is part of success. If it fails, the card remains unpicked and
retryable. No watched or recommendation state changes.

### Confirmation lifecycle

The active Pick becomes automatically eligible when Home is entered at least
12 hours after its latest selection time.

Accepted outcomes are:

- `watched`: continue through the reconciliation operation;
- `notYet`: increment postponement count and set the next eligibility time to
  24 hours after the answer;
- `notWatched`: close the decision without Viewer Movie State mutation.

After three `notYet` answers, automatic presentation stops. The decision stays
pending and is available from `My movies` until resolved or cancelled.

After `watched` succeeds, Presentation offers an optional reaction. The
existing Viewer Movie State transition applies that reaction. Only after that
transition succeeds does the decision record copy it as an immutable
Satisfaction snapshot. `Not now` leaves satisfaction absent. Later current-
reaction edits do not rewrite the snapshot.

### Persisted reconciliation operation

Confirmation cannot atomically commit across repositories. The
`ViewingDecisionRepository` therefore journals a stable confirmation operation
before changing Viewer Movie State:

```text
prepared
  -> applyingViewerMovieState
  -> viewerMovieStateCommitted
  -> completed
```

The coordinator executes:

1. persist `prepared` with decision, movie, and operation identities;
2. persist `applyingViewerMovieState`;
3. ask the Viewer Movie State reducer to atomically set watched and provenance;
4. persist `viewerMovieStateCommitted`;
5. close the decision as confirmed watched and mark the operation `completed`.

The provenance stores the confirmation operation identity. Repeating step 3
with the same operation is a semantic no-op. On launch or repository activation,
the coordinator resumes the first incomplete stage.

Once Viewer Movie State commits, later measurement failure never rolls back
watched or provenance. Presentation may show the durable provenance while the
journal retries completion. A corrupt measurement store never causes inferred
provenance; only the Viewer Movie State record authorizes the badge.

Optional satisfaction uses a second stable operation so a reaction committed
before interruption can be copied once into the session snapshot during
reconciliation.

### Local measurement contract

The repository records only accepted semantic evidence:

- session start/end and foreground first/final Pick durations;
- observed Decision Set identities and explicit `Give me three more` count;
- Pick, replacement, cancellation, confirmation, and postponement;
- optional immutable Satisfaction snapshot;
- successful `Already watched` actions originating from Home;
- recommendation-search duration, expansion stage, and terminal outcome.

The Home already-watched denominator is distinct movie IDs observed per
session. Redraw, restoration, and reconciliation never count the same movie
twice in one session.

Search measurement consumes a semantic outcome from the existing Home
coordinator. It launches no request and exposes no new long-search UI.

`PilotMeasurementSummary` derives funnel counts, confirmation rate,
satisfaction distribution, timing, refresh/observed-set counts, Home already-
watched rate, and search outcomes from the retained valid records.

### Persistence and retention

Data implements `ViewingDecisionRepository` as an actor and sole mutable owner
of one independently versioned JSON envelope in Application Support.

The envelope contains:

- schema version and non-reusable envelope identity;
- active or pending decision state;
- terminal sessions and immutable outcomes;
- incomplete reconciliation operations;
- bounded technical evidence.

It follows the repository recovery policy established in PickOne:

- encode and validate a complete envelope before replacement;
- retain one previous valid copy;
- migrate only explicitly supported schemas;
- quarantine exact corrupt or unsupported bytes;
- never fabricate empty history after failed decoding;
- serialize pruning, mutation, recovery, and deletion under the actor.

Completed terminal sessions become eligible for pruning 180 days after their
terminal time. Active Picks, unresolved confirmations, postponed confirmations,
and incomplete reconciliation operations do not expire.

The explicit Settings deletion clears eligible measurement history and starts
a new valid measurement generation. It preserves active/pending product state,
incomplete reconciliation, Viewer Movie State provenance, Viewer Profile,
Watchlist, Search History, and Decision Sets. Export is a read-only snapshot of
the same locally retained measurement records and derived summary.

Viewer Movie State moves from its current v3 persistence to v4. Migration
preserves every v3 field and assigns absent provenance. It never infers
provenance from watched, reactions, Watchlist, Decision Sets, or shown history.
Existing active/previous/quarantine recovery guarantees remain in force.

### Privacy boundary

The measurement envelope may contain only:

- opaque local IDs;
- TMDB movie IDs and recommendation set/cycle/role identities;
- timestamps or foreground durations required by the accepted funnel;
- explicit Viewer actions and bounded semantic search evidence.

It must not contain:

- person, account, household-member, or advertising identity;
- raw Search text, Ask prompts, or natural-language requests;
- title, synopsis, poster, full movie, or provider payloads;
- exhaustive passive navigation or unrelated UI actions;
- credentials, remote tokens, or vendor analytics identifiers.

Measurement failure cannot block Home recommendations, Search, Watchlist,
existing feedback, or `My movies`. A failed Pick remains retryable because the
product must not claim an unpersisted decision. An unavailable report shows an
explicit unavailable state, not invented zeroes.

### Concurrency and dependency direction

Dependency direction remains `Presentation → Domain ← Data`.

- Presentation view models are `@MainActor` and own structured task lifetime.
- Repository mutable state is actor-isolated.
- Domain values crossing isolation boundaries are `Sendable`.
- Wall and foreground clocks are injected for deterministic tests.
- Cancellation is not recorded as failure or outcome unless the Viewer
  explicitly cancels a Pick.
- Late work cannot overwrite a newer decision, journal stage, or Viewer Movie
  State snapshot.

No physical Swift module or new dependency is introduced. The boundary remains
inside the modular monolith until stability or measured build cost justifies
extraction.

### Future remote measurement

Local repositories remain authoritative. Semantic records use stable IDs,
timestamps, and schema versions so future Data infrastructure can derive an
outbox from committed local changes.

A future ADR may add:

- a typed vendor-neutral delivery port;
- an outbox committed with local state;
- asynchronous idempotent retry and delivery checkpoints;
- adapter-specific mapping and an explicit property allowlist.

Milestone 8 adds none of these. Domain never depends on Mixpanel, Firebase,
vendor event names, SDK types, or `track(name:properties:)`. Remote delivery
will require a separate privacy, retention, deletion, consent, and failure
decision.

## Failure and recovery

| Failure | Required result |
|---|---|
| Pick write fails | Keep Pick available and retryable; show no false success |
| Session timing cannot be recovered | Preserve decision with unavailable timing |
| Viewer Movie State confirmation fails | Keep journal pending; claim neither watched nor provenance |
| Measurement finalization fails after Viewer Movie State commits | Preserve watched/provenance and resume journal later |
| Satisfaction snapshot fails after reaction commits | Preserve current reaction and reconcile snapshot once |
| Active measurement envelope is invalid | Try previous valid/migration, quarantine exact bytes |
| All measurement recovery fails | Keep core app usable; report measurement unavailable |
| Export fails | Preserve source and permit retry; mutate nothing |
| Measurement deletion fails | Preserve prior complete envelope; mutate no other repository |

## Verification consequences

Implementation must prove:

- session foreground timing, inactivity boundary, old-set reuse, and unavailable
  timing fallback;
- idempotent Pick/replace/cancel and first/final timing;
- 12-hour eligibility, 24-hour postponement, three-postponement manual path,
  and every confirmation outcome;
- cross-repository interruption and relaunch at every journal stage;
- v3-to-v4 Viewer Movie State migration with no inferred provenance;
- 180-day retention and measurement deletion isolation;
- exact metric fixtures with no passive or duplicate counting;
- English/Spanish Presentation, VoiceOver, Dynamic Type, and discoverability;
- final-M7 upgrade without losing profile, movie state, recommendations,
  Watchlist, Search History, or recovery history;
- no analytics SDK, remote request, generic event dictionary, or extra
  recommendation request.

## Consequences

### Positive

- Pick, watched, satisfaction, and provenance retain distinct meanings.
- User-visible provenance survives metric lifecycle operations.
- Local measurement is privacy-bounded and independently recoverable.
- Interrupted confirmation converges without rolling back watched state.
- Stable semantic records allow future vendor adapters without current vendor
  coupling.
- The four implementation slices remain vertical and independently reviewable.

### Costs

- Viewer Movie State requires a v4 migration.
- One confirmation uses a small persisted journal because local stores are not
  transactionally shared.
- The actor repository and previous-copy/quarantine policy add code for a local
  household pilot.
- Local export is required because no remote analytics system reads the data.

These costs are accepted because incorrect attribution or silent data loss
would invalidate the pilot and erode user trust.

## Alternatives rejected

### Store sessions in Decision Set persistence

Rejected because recommendation lifecycle, suppression, and regeneration have
different retention and mutation semantics from decisions and confirmation.

### Store all measurement in Viewer Movie State

Rejected because session history is time-bounded, cross-movie, and explicitly
deletable, while Viewer Movie State is current per-title authority.

### Derive provenance from retained sessions

Rejected because 180-day pruning or measurement deletion would remove a
user-visible fact from `My movies`.

### Treat confirmation writes as best effort

Rejected because interruption could permanently disagree about watched state,
provenance, and session outcome.

### Add a generic analytics facade now

Rejected because it loses semantic type safety, invites arbitrary properties,
and couples current architecture to hypothetical remote delivery.

### Add an outbox and vendor port in Milestone 8

Rejected as premature. Stable local records provide the migration boundary;
remote transmission has no accepted product or privacy scope.

### Create a physical module

Rejected because the new boundary is not stable and current build evidence
does not justify package/module overhead.

## Approval gate

Implementation may begin only after:

- the Product Owner and Technical Lead accept this ADR and Milestone 8
  together;
- the documentation-only D0 PR is merged;
- Milestone 8 and this ADR are marked accepted;
- PR1 is explicitly authorized.

## Related documents

- [`PRODUCT.md`](../../PRODUCT.md)
- [Milestone 8 — Local Pilot Measurement](../milestones/milestone-8-pilot-measurement.md)
- [Product Language Glossary](../product/product-language-glossary.md)
- [ADR-012 — Unified Local Viewer Movie State](adr-012-unified-local-viewer-movie-state.md)
- [ADR-014 — Bounded Recommendation Suppression and Exhaustion Recovery](adr-014-bounded-recommendation-suppression-and-recovery.md)
- [Product and Engineering Agent Delivery Model](../process/agent-delivery-model.md)

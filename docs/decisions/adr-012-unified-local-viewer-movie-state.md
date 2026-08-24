# ADR-012 — Unified Local Viewer Movie State

## Status

Accepted

The Product Owner accepted the product transitions and the general architecture
on 2026-08-19 and accepted `My movies` as the final history label on
2026-08-24. The persistence identity and Decision Set migration clarifications
were accepted with the final Milestone 7 D0 specification after Milestone 6
merged.

## Context

Milestone 5 persists calibration reactions inside `ViewerProfile`. Watch state
is currently stored only on Watchlist records, which means a movie must be in
Watchlist before it can be marked watched and removing it also loses that fact.
Milestone 6 combines those independent sources for recommendation exclusion.

Milestone 7 needs one coherent current state for every movie while preserving
four distinct meanings:

- watched fact;
- post-viewing Movie reaction;
- stable `Not interested` rejection for an unwatched title;
- future Watchlist intent.

Adding more fields to `ViewerProfile`, or persisting each meaning under a
separate owner, would create contradictory states and non-atomic transitions.
The new state must also migrate the installed household pilot without losing
Viewer Profile, Watchlist, watched, Search History, or calibration evidence.

The canonical meanings are defined by the
[Product Language Glossary](../product/product-language-glossary.md).

## Decision

### Per-movie Domain aggregate

Domain introduces values equivalent to:

```text
ViewerMovieState
├── movieID
├── displayMetadata
├── watchState
├── preference? = reaction(MovieReaction) | notInterested
├── watchlistIntent?
└── stateChangedAt
```

`MovieReaction` has exactly four cases:

- `loveIt`;
- `likeIt`;
- `itWasOkay`;
- `didNotLikeIt`.

`ViewerMovieState` is independent from `ViewerProfile`. The profile remains the
persisted source for region, selected services, profile lifecycle, and the last
completed catalog reference. The draft owns current calibration progress.
After v1 migration, `ViewerProfile` no longer contains reactions; current Movie
reactions live only in `ViewerMovieState`. `TasteProfile` is calculated in
Domain from those current reactions and is never persisted as an independent
source of truth.

Domain exposes one capability equivalent to `ViewerMovieStateRepository` for
loading snapshots and applying validated transitions. Presentation does not
mutate Watchlist, watched, reaction, or `Not interested` through separate
repositories.

Focused read use cases may expose Watchlist and feedback-history projections,
but they derive from the same repository snapshot.

The final Watchlist projection contains only `watchlistIntent`. Watched-only and
reaction states belong to the `My movies` projection; they are never encoded as
saved rows merely to remain visible.

### Invariants

- identity is a positive TMDB movie ID;
- only one current Movie reaction may exist;
- Movie reaction implies watched;
- removing a reaction preserves watched;
- `Not interested` implies unwatched;
- `Not interested` and Movie reaction are mutually exclusive;
- Watchlist intent implies unwatched;
- Watchlist intent retains its own `addedAt` for existing Watchlist ordering;
- explicit rewatch intent is unsupported;
- `Not interested`, watched, and Movie reaction cannot coexist with Watchlist
  intent;
- metadata is sufficient to show a history row without an immediate request;
- `stateChangedAt` changes only after a successful explicit state transition;
  metadata refresh never reorders activity;
- a mutation replaces one fully validated record or does not publish a change.

An unwatched movie with no preference and no Watchlist intent has no persisted
Viewer Movie State record. Undoing its final explicit state removes the record
instead of retaining an empty tombstone. A watched movie without a reaction is
meaningful and remains persisted.

### Accepted transitions

| Action | Watch state | Preference | Watchlist intent |
| --- | --- | --- | --- |
| Assign rating | watched | replace with rating | remove |
| Change rating | watched | replace rating | unchanged, necessarily absent |
| Remove rating | remain watched | none | unchanged |
| Set `Not interested` | unwatched | replace with `notInterested` | remove |
| Undo `Not interested` | remain unwatched | none | unchanged |
| Mark watched | watched | remove `notInterested` | remove |
| Mark unwatched | unwatched | remove rating | do not restore |
| Save to Watchlist | unwatched | remove `notInterested` | save |
| Remove from Watchlist | unchanged | unchanged | remove |

`Not interested` is not offered for a watched movie. Domain rejects the same
invalid transition if another caller attempts it. A newer valid action replaces
the conflicting older intent as defined by the table; implicit restoration is
never performed.

### Recommendation-impact precedence

One atomic transition may change reaction, watched, `Not interested`, and
Watchlist intent together. Domain classifies the complete before-and-after
result once; Presentation and Data do not infer impact from individual field
writes.

Impact precedence is:

1. `tasteChanged` when the current Movie reaction was added, replaced, or
   removed;
2. `eligibilityChanged` when watched or `Not interested` changed without a
   reaction change;
3. `watchlistIntentChanged` when only Watchlist intent changed;
4. `none` when recommendation inputs did not change.

Therefore assigning a rating to a saved unwatched movie is `tasteChanged`, even
though the same transition also marks it watched and removes Watchlist intent.
It starts a successor recommendation cycle and inherits every shown movie ID.
The lower-priority effects are still persisted atomically; they do not trigger a
second repair or permit the old cycle to publish.

### Calibration semantics

- informative first-onboarding responses become current Movie reactions and
  watched facts;
- recalibration upserts only its informative responses;
- `Haven't seen it` and `Don't know it` update calibration progress but never
  remove existing Movie reaction, watched, `Not interested`, or Watchlist
  state;
- a recalibration never deletes feedback for movies absent from its frozen
  catalog;
- historical v1 calibration responses remain available to migration and are
  not discarded merely because current state has a newer value.

Completing onboarding or recalibration updates Viewer Profile state and the
affected Viewer Movie States in one serialized persistence replacement.

The draft's informative-response count is calculated from responses recorded
in that flow for completion rules. Decision Engine confidence is calculated
separately from the complete current Movie-reaction projection. Neither count
is persisted as a derived field.

An existing Movie reaction may be presented as context during recalibration,
but it is not copied into the new draft or counted as a response until the
Viewer answers for that movie in the current flow.

### Reset semantics

Normal `Reset preferences`:

- removes every Movie reaction and `Not interested` value;
- preserves watched facts;
- preserves Watchlist intent;
- removes the Viewer Profile and draft under its existing confirmed flow;
- does not delete Search History.

Removing reactions does not make their movies unwatched.

The destructive recovery reset described below is separate, appears only when
all recoverable sources fail, and clearly identifies the broader data loss.

## Persistence

### Envelope and owner

Data stores one versioned local viewer-state envelope under Application
Support. One actor owns reads, migration, transitions, rollback publication,
and complete-file replacement.

Conceptually:

```text
LocalViewerStateEnvelopeV2
├── envelopeSchemaVersion
├── committedStateSnapshotID
├── viewerProfileState
│   ├── completedProfile?
│   └── profileDraft?
├── viewerMovieStates[]
└── migrationRecord
```

`completedProfile` contains no Movie reactions. A first-onboarding draft owns
its selected services and calibration responses; a recalibration draft owns
only its frozen catalog, responses, position, and extension state. Completion
upserts informative responses into `viewerMovieStates` and removes the draft in
the same complete-envelope replacement.

`committedStateSnapshotID` is an opaque Domain value backed by a repository-
generated UUID. It changes whenever current completed-profile inputs or Viewer
Movie State changes successfully. Draft-only progress and display-metadata
hydration preserve it because they do not change current recommendation inputs.
Service edits, calibration completion, ratings, watched, Watchlist, `Not
interested`, and preference reset receive a fresh identity when their persisted
result changes recommendation inputs.

The identity is compared only for equality. It is never an incrementing counter,
timestamp, or ordering signal. Callers cannot choose it. A newly committed
state, successful legacy migration, and recovery publication each receive a
fresh identity that has never represented an earlier active snapshot. In
particular, republishing the previous valid copy must replace its former
identity before it becomes active, so an old Decision Set can never appear
current merely because numeric state repeated after rollback.

The persistence DTO is not a Domain aggregate. The actor may implement multiple
narrow Domain repository capabilities while preserving one physical
transaction boundary.

The complete candidate envelope is encoded and semantically validated before
replacement. File writes stage a uniquely named item on the destination volume
and use Foundation's item-replacement API. The design does not claim physical
durability beyond errors exposed by the file API.

### Active, previous, and quarantine

The store manages:

- one active envelope;
- one previous envelope known to have decoded and validated successfully;
- exact quarantined bytes for corrupt or unsupported active/previous data;
- read-only legacy sources used for migration recovery.

Each unread corrupt or unsupported source is copied byte-for-byte to a unique
quarantine item before a recovery step would replace that source. Quarantine
never overwrites an earlier diagnostic item. If that preservation cannot be
completed and the original would otherwise be replaced, recovery stops and
keeps the original source in place.

Before replacing a valid active envelope, its exact bytes become the previous
valid copy. The newly encoded active envelope is then written atomically.
A failed candidate encoding, validation, previous-copy update, or active
replacement leaves the last readable state available.

### Load and recovery order

1. Decode and validate the active envelope.
2. If active is corrupt or incompatible, preserve its exact bytes in
   quarantine and try the previous valid copy.
3. If previous succeeds, validate its content, assign a fresh snapshot identity,
   and republish it as active without deleting quarantine.
4. If no current envelope can be used, attempt deterministic legacy migration.
5. If all three sources fail, preserve every unread byte and expose recovery.
6. Only that final state may offer an explicit destructive local-viewer-data
   reset. No path manufactures an empty Watchlist, watched history, feedback,
   or profile.

Unsupported schema and corrupt data remain distinct diagnostic outcomes even
though both fail closed.

Previous and recovery-time legacy sources may represent an older saved
snapshot. Successful recovery returns its source and new active identity
explicitly; Presentation does not describe the content as the latest state.
First migration on a normal M6-to-M7 upgrade is not a rollback and needs no
warning.

A genuinely fresh installation, where active, previous, and legacy bytes are
all absent, is not a recovery failure. It creates the explicit valid
profile-absent envelope needed to start first onboarding. The presence of any
corrupt, unsupported, or failed source prevents this clean-install path.

### Legacy migration

Migration reads the existing Viewer Profile envelope and Watchlist v2 bytes
without mutating them.

A legacy source may be legitimately absent and the other source may still be
migrated. If any present legacy source is corrupt, unsupported, or invariant-
invalid, the complete migration fails and preserves all inputs; it never
publishes a partial profile or Watchlist projection.

For each TMDB movie ID:

- informative calibration response becomes the matching Movie reaction and
  watched fact;
- Watchlist `isWatched` becomes an independent watched fact;
- unwatched Watchlist membership becomes Watchlist intent with its original
  metadata and `addedAt`;
- when reaction or watched conflicts with legacy Watchlist membership, watched
  wins and no Watchlist intent is migrated;
- metadata is selected deterministically from the strongest valid local source;
- Search History is untouched.

Legacy catalog references are mapped only through an explicit registry. The
accepted M5 catalog maps to the equivalent bundled v2 snapshot. A legacy first-
onboarding or recalibration draft freezes that complete snapshot while
preserving its responses, position, extension state, and—only for first
onboarding—selected services. Draft responses do not become current Movie
reactions until normal completion. An unknown legacy catalog version fails the
complete migration instead of guessing a current remote version.

Migrated Watchlist-derived state uses its legacy `addedAt` as
`stateChangedAt`. Legacy calibration reactions have no event timestamp, so one
injected migration date is used for that group and lower TMDB ID provides the
documented deterministic display tie-break. Later metadata hydration does not
alter that timestamp.

The migrated v2 completed profile retains region, selected services, and the
last completed calibration reference but does not retain its legacy reaction
map. Reactions exist only in the migrated `viewerMovieStates` collection.

The migration is idempotent. Legacy bytes remain available throughout
Milestone 7 and are never deleted as part of a successful import.

## Concurrency and publication

- the repository actor is the only mutable owner;
- persisted and Domain snapshots are immutable and `Sendable`;
- every successful committed-state mutation returns the new state plus the
  persisted `ViewerStateSnapshotID`;
- Presentation publishes success only after persistence completes;
- cancellation or a stale caller never rolls back a newer committed identity;
- Decision Engine operations capture an identity and validate it immediately
  before persistence and publication;
- no unchecked sendability or global mutable cache is introduced.

## Presentation recovery

Movie Detail distinguishes loading, usable state, saving, and retryable
failure. `My movies` is a read projection with loading, content, empty, and
retryable failure; it navigates to Detail for editing. A failed Detail mutation
keeps the last successfully persisted state visible and never reports the
requested state as saved.

After recovering from previous or from legacy after a v2 failure, root routing
enters the app with the non-blocking notice:

> We recovered an earlier saved version of your movie data. Please review it
> in Settings.

The notice appears only after a valid recovered envelope is active. It does not
claim that every last mutation survived.

If the complete local viewer state is unrecoverable, root routing presents a
blocking recovery state. Retry is primary. A destructive reset is secondary,
requires confirmation, states that preferences, watched history, Watchlist, and
movie feedback will be lost, and does not silently clear Search History.

After confirmation, destructive recovery removes the unusable active,
previous, quarantine, and legacy viewer-state sources, then creates a new
explicit profile-absent envelope. That user-authorized reset is the only failed-
recovery path allowed to start empty; Search History remains untouched.

## Consequences

### Positive

- Watchlist and watched become genuinely independent;
- one transition owner prevents contradictory states;
- Movie Detail, history, Home, and calibration share one current truth;
- the Taste Profile can evolve without turning Viewer Profile into a monolith;
- migration and recovery preserve real pilot data rather than treating it as
  disposable;
- later persistence extraction has one explicit boundary.

### Costs

- existing synchronous Watchlist contracts must become actor-safe asynchronous
  operations;
- Viewer Profile and Watchlist persistence move behind a new envelope and
  migration path;
- root loading gains a migration/recovery phase;
- more local state is rewritten per transaction, which is acceptable for the
  bounded household pilot but must be measured before scale-out.

## Alternatives considered

### Add feedback fields to Viewer Profile

Rejected. It mixes stable viewer context, calibration workflow, and an
unbounded per-movie collection in one Domain aggregate.

### Keep separate Watchlist, watched, and feedback stores

Rejected. Accepted actions cross those meanings and require one coherent
transaction. Compensation between independent UserDefaults keys would expose
partial state and fragile recovery.

### Persist a derived Taste Profile

Rejected. It would create a second source of truth that can disagree with the
current reactions or P1 version.

### Introduce SwiftData

Rejected for this milestone. The bounded local dataset, exact-byte recovery,
and deterministic legacy migration are simpler with a versioned file envelope.
SwiftData would add a persistence framework and migration model without an
observed scale or query need.

## Verification obligations

- exhaustive pure transition table and invalid-transition tests;
- idempotent migration from profile-only, Watchlist-only, overlapping, and
  empty valid legacy inputs;
- first-onboarding and recalibration draft migration with exact bundled
  snapshot freeze, plus unsupported legacy catalog failure;
- exact byte preservation for corrupt and unsupported active and previous data;
- unique quarantine retention and preservation-failure behavior;
- recovery order tests for active, previous, legacy, and total failure;
- normal first migration versus disclosed older-snapshot recovery;
- encoding and replacement failures preserve the prior active state;
- snapshot identities are never reused, including after previous-copy recovery;
- concurrent mutations serialize and stale identities cannot publish;
- multi-field transitions use taste, eligibility, then Watchlist impact
  precedence exactly once;
- `Reset preferences` preserves watched and Watchlist;
- destructive recovery reset exists only after every source fails;
- installation over the final Milestone 6 build preserves profile, Watchlist,
  watched state, Search History, exact legacy recommendation bytes, and trusted
  shown history until normal M7 reconciliation produces a v2 Decision Set.

## Related documents

- [Milestone 7 — Continuous Taste Learning](../milestones/milestone-7-continuous-taste-learning.md)
- [Product Language Glossary](../product/product-language-glossary.md)
- [ADR-010 — Local Viewer Profile and Dynamic Viewing Context](adr-010-local-viewer-profile-and-dynamic-context.md)
- [ADR-011 — Deterministic Decision Engine v1](adr-011-deterministic-decision-engine-v1.md)

## Primary platform references

- [Apple — Application Support directory](https://developer.apple.com/documentation/foundation/url/applicationsupportdirectory)
- [Apple — `FileManager.replaceItemAt`](https://developer.apple.com/documentation/foundation/filemanager/replaceitemat%28_%3Awithitemat%3Abackupitemname%3Aoptions%3A%29)

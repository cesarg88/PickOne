# Milestone 8 — Local Pilot Measurement

## Status

`Draft — Product Definition`

- Product Ready: **No**. The Product Owner decisions listed under
  [Open product questions](#open-product-questions) remain unresolved.
- Engineering Ready: **No**. Technical contracts and the delivery slices are
  proposals until the product behavior is accepted.
- Implementation authorized: **No**.
- Milestone 7 is complete and no longer blocks product definition.
- This document defines no production-code change and authorizes no
  implementation pull request.

## Authority and purpose

- Product authority: [`PRODUCT.md`](../../PRODUCT.md)
- Engineering authority: [`ENGINEERING.md`](../../ENGINEERING.md)
- Delivery model:
  [Product and Engineering Agent Delivery Model](../process/agent-delivery-model.md)
- Product language:
  [Product Language Glossary](../product/product-language-glossary.md)
- Related backlog items: IMP-005 and IMP-023

If this draft conflicts with `PRODUCT.md`, `PRODUCT.md` wins. If it conflicts
with `ENGINEERING.md`, `ENGINEERING.md` wins. Accepted product decisions in
this draft must be promoted to the canonical documents before implementation.

Milestone 8 must determine whether PickOne helps the household pilot make and
complete a movie decision. It adds the minimum explicit product interactions
and local evidence needed to evaluate that question. It does not optimize for
engagement and does not introduce remote analytics.

## Product problem

Milestone 7 proved that PickOne can present useful, available recommendations
and recover under prolonged feedback. It does not prove that a recommendation
caused a decision, that the selected movie was watched, or that the result was
satisfying.

Current signals are insufficient:

- opening Detail is not a decision;
- adding a title to Watchlist is future intent;
- rating an already-seen recommendation is feedback about past viewing;
- marking `Already watched` exposes a recommendation-quality problem, not a
  PickOne-assisted decision;
- a passive impression proves none of these outcomes.

Milestone 8 therefore introduces an explicit `Pick` and a later explicit
viewing confirmation. It records only the local pilot evidence needed to
interpret the resulting decision funnel.

## Accepted decisions

The following product direction is accepted for this draft.

### Measurement before trailers

- Milestone 8 measures the decision experience first.
- Trailer implementation is outside this milestone.
- Trailers may be reconsidered only if pilot evidence shows that missing
  confidence-building content is preventing decisions.

### Local-only pilot measurement

- All Milestone 8 measurement remains on the device during the household
  pilot.
- There is no backend, external analytics SDK, account, cloud sync, or remote
  event transmission.
- Measurement must remain usable without network access.

### Explicit Pick action

- Every Home recommendation has a compact action with a selection icon.
- The label is `Pick` in English and `Elegir` in Spanish.
- After successful persistence, the selected recommendation shows `Picked` in
  English and `Elegida` in Spanish.
- A Pick records a session decision.
- A Pick does not mark the movie watched, change its Movie reaction, update the
  Taste Profile, or imply Watchlist intent.
- Persistence is part of success. Presentation must not show `Picked` before
  the decision is durably accepted.

### First-use explanation

- The first Home that contains recommendations presents a dismissible,
  non-blocking coach mark explaining the Pick action.
- The coach mark is shown once and its presented state is persisted.
- It must be accessible with VoiceOver, Dynamic Type, Reduce Motion, and
  keyboard or switch-control dismissal where supported.
- Failure to show or persist the coach mark must never block Home or the Pick
  action.

### Viewing confirmation

- PickOne later asks explicitly whether the selected movie was actually
  watched.
- No passive behavior is interpreted as viewing confirmation.
- The exact timing, wording, choices, and state transitions remain a Product
  Owner decision.

### My movies provenance

- `My movies` visually distinguishes a movie only when PickOne contributed to
  it being watched.
- Attribution requires both:
  1. an explicit Pick from a Home recommendation; and
  2. a later explicit confirmation that the selected movie was watched.
- Rating or marking an already-seen Home recommendation does not create this
  attribution.
- The distinction communicates provenance, not satisfaction. The current
  Movie reaction continues to communicate satisfaction.

### Staged success semantics

Success is interpreted as a funnel rather than one boolean:

1. **Picked** — the Viewer made an explicit session decision.
2. **Confirmed watched** — the Viewer later confirmed that the Pick was
   watched.
3. **Satisfaction** — the confirmed viewing has an explicit Movie reaction.

The accepted interpretation is:

| Outcome | Evidence | Interpretation |
|---|---|---|
| Pick only | Explicit Pick | PickOne supported a decision; viewing is unknown |
| Confirmed watched | Pick + explicit confirmation | PickOne contributed to a completed viewing |
| `Love it` / `Like it` | Confirmed viewing + reaction | Strong product and recommendation-quality success |
| `It was okay` | Confirmed viewing + reaction | Decision utility with neutral satisfaction |
| `Didn't like it` | Confirmed viewing + reaction | Decision/viewing occurred, but recommendation quality was negative |

The absence of a later reaction is not silently interpreted as neutral or
negative satisfaction.

### Existing Home feedback evidence

- Milestone 8 records locally how often recommendations are marked `Already
  watched` directly from Home.
- This evidence informs whether a later `Improve recommendations` experience is
  justified.
- Milestone 8 does not expand onboarding, infer additional watched state, or
  change the accepted Viewer Movie State transition.

### Long-search feedback

- Home must provide honest visual feedback while a prolonged progressive
  search is still running.
- The treatment must not expose internal page numbers, fabricate a percentage,
  or promise a result.
- The exact copy, timing, and interaction remain open.

## Desired product outcomes

Milestone 8 should let the household pilot answer:

- How often does a recommendation session produce an explicit Pick?
- How long does it take to Pick after usable recommendations first appear?
- How often is a Pick later confirmed as watched?
- How satisfying are confirmed PickOne-assisted viewings?
- How often does Home recommend a title the Viewer has already watched?
- How often does a decision require another set or the extreme expanded-search
  path?
- Where does the flow fail: no Pick, no viewing, or negative satisfaction?

These are diagnostic pilot questions, not claims of statistical significance.
The Product Owner's qualitative account remains part of the evidence.

## Open product questions

Implementation must not begin until the Product Owner resolves the following
questions. The Technical Lead recommendation is included to make each choice
concrete; it is not accepted behavior.

### 1. Recommendation-session definition

**Decision required:** define when a session begins, resumes, and ends, and how
an abandoned session is represented.

**Technical Lead proposal:** a session begins when a non-empty Home Decision
Set first becomes visible while the app is active. It spans Home and Movie
Detail navigation. It ends on a successful Pick, explicit abandonment if one
is introduced, or 30 minutes without foreground interaction. A relaunch or
brief background transition resumes the same session inside that limit.

This provides a defensible time-to-decision denominator without treating app
launch, onboarding, network recovery, or background time as decision time.

### 2. Viewing-confirmation timing and choices

**Decision required:** define when the question appears, whether it may be
dismissed, and the exact answer choices.

**Technical Lead proposal:** ask before the next independent Home decision
attempt, after a reasonable viewing window. Offer `Watched`, `Not yet`, and
`Didn't watch`. `Not yet` postpones the prompt; `Didn't watch` closes the
decision without attribution. The prompt must not block use of other tabs.

The waiting period and final localized copy require Product Owner acceptance.

### 3. Changing or cancelling a Pick

**Decision required:** decide whether a Viewer may undo a Pick or replace it
with another recommendation from the same session.

**Technical Lead proposal:** allow at most one active Pick per session. Picking
another card requires an explicit replacement action and preserves the earlier
record as superseded. The selected card offers a discreet cancel/change path.
Cancellation removes pending confirmation but never deletes diagnostic
history.

### 4. Retention, deletion, and export

**Decision required:** define how long local pilot records are kept, whether
the Viewer can delete them independently, and how the pilot evidence is read.

**Technical Lead proposal:** retain at most 180 days of completed sessions,
keep the active pending decision regardless of age, expose a Settings `Pilot
insights` summary, and provide an explicit share/export action for a
human-readable report. Deletion requires confirmation and affects measurement
only, never Viewer Profile, Viewer Movie State, Watchlist, Search History, or
Decision Sets.

### 5. My movies attribution treatment

**Decision required:** accept the exact badge/icon and localized copy.

**Technical Lead proposal:** show a compact provenance badge `Chosen with
PickOne` / `Elegida con PickOne` only after confirmed viewing. Keep the Movie
reaction adjacent and visually independent.

### 6. Availability feedback scope

**Decision required:** decide whether Milestone 8 includes an explicit
`Availability is wrong` action and how it affects metrics.

**Technical Lead proposal:** keep it out of the initial slice unless the pilot
needs an explicit way to distinguish a bad recommendation from stale provider
evidence. Continue recording existing eligibility loss and unknown evidence as
technical diagnostics, not Viewer feedback.

### 7. Localization scope

**Decision required:** decide whether partial English/Spanish localization is
acceptable or whether every affected Home, confirmation, `My movies`, and
Settings surface must be localized together.

The app currently has English as its development region and no existing string
catalog. Adding only `Pick` and `Picked` would create a mixed-language
experience.

**Technical Lead proposal:** introduce one `Localizable.xcstrings` catalog and
localize every new or changed Milestone 8 string in English and Spanish. Do not
silently expand the milestone into whole-app translation; track remaining
legacy hardcoded strings as separate localization debt.

### 8. Local measurement readout

**Decision required:** define who reads the evidence and through which product
surface.

**Technical Lead proposal:** add `Pilot insights` under Settings with aggregate
counts and medians plus an explicit local export/share action. A developer log
alone is not a usable pilot measurement system, while an always-visible
consumer dashboard would overstate the feature's importance.

### 9. Long-search feedback

**Decision required:** accept exact copy, delay thresholds, and whether the
message changes as the search expands.

**Technical Lead proposal:** retain the existing immediate loading state, then
switch to non-numeric copy such as `Still checking more options…` after a short
foreground delay. The state disappears on result, exhaustion, cancellation,
or failure. Do not show paging or request counts.

### 10. Satisfaction evidence over time

**Decision required:** decide whether a completed session reports the Movie
reaction at confirmation time or the current reaction when the report is read.

**Technical Lead proposal:** preserve the reaction explicitly provided during
or after confirmation as the immutable historic outcome. Later edits continue
to update the current reaction in `My movies` and Taste Profile but do not
rewrite what the pilot recorded for the earlier session.

## Technical Lead proposal

This section is an engineering proposal conditioned on the open product
decisions. It is not yet an accepted contract.

### Boundary and ownership

Pick and pilot measurement are not Viewer Movie State:

- a Pick is a time-bounded decision, not watched state;
- viewing confirmation is historical attribution, not current preference;
- a measurement record must not change recommendation eligibility or Taste
  Profile;
- a Decision Set remains the recommendation result, not an analytics/event
  container.

Create a dedicated Domain boundary, provisionally named
`ViewingDecisionRepository`, for typed local decision records. Do not expose a
generic `track(name:properties:)` analytics API.

```text
Presentation ──> Domain use cases ──> ViewingDecisionRepository
     │                    │                       ▲
     │                    │                       │
     └──────── reads existing Decision Set        Data actor + local envelope

ViewerMovieStateRepository ──> current reaction/watched projection
```

Dependency direction remains `Presentation → Domain ← Data`. The repository
protocol and semantic values belong to Domain; DTOs, encoding, recovery, and
storage belong to Data; coach marks, buttons, prompts, and reporting views
belong to Presentation.

No physical Swift module or package is justified. The boundary is new and its
product semantics are still evolving. Keep it isolated by folders and
protocols inside the current modular monolith, then reconsider a module only
after the contract is accepted and stable or build measurements justify it.

### Proposed Domain concepts

Names are semantic working names and must not contain milestone or PR labels.

#### `DecisionSession`

Represents one bounded attempt to choose from Home. Its final fields depend on
the accepted session definition, but should use:

- opaque, non-reusable `DecisionSessionID`;
- start and optional end timestamps;
- foreground decision duration rather than unqualified wall-clock duration;
- zero or more Decision Set identities observed in that session;
- number of explicit `Give me three more` actions;
- Home-originated `Already watched` corrections;
- optional active or terminal viewing decision.

#### `ViewingDecision`

Represents an explicit Pick and its later outcome:

- opaque, non-reusable `ViewingDecisionID`;
- source Decision Set ID and recommendation-cycle identity;
- TMDB movie ID and recommendation role;
- selected timestamp;
- pending, superseded, cancelled, watched, or not-watched outcome as accepted
  by Product;
- optional confirmation timestamp;
- optional satisfaction evidence with its capture timestamp.

Persist identities and semantic evidence, not duplicated full movie metadata.
Presentation obtains current display metadata through existing movie and Viewer
Movie State boundaries.

#### `HomeRecommendationCorrection`

Records only a successful `Already watched` action that originated from a Home
recommendation. Detail actions, calibration answers, passive appearances, and
pre-existing watched state do not count.

The Product Owner must define the denominator before a rate is reported: card
appearances, distinct recommended titles, or recommendation sessions. The
Technical Lead recommends distinct recommended titles per session to prevent
reconciliation redraws from inflating the metric.

#### `PilotMeasurementSummary`

A calculated Domain projection rather than a persisted second source of truth.
It may include:

- sessions started and completed with Pick;
- median foreground time to Pick;
- Picks confirmed watched;
- confirmed outcomes by satisfaction class;
- Home already-watched correction rate;
- new-set requests per session;
- prolonged-search and exhausted-result counts.

Summary values must be derived from valid retained records.

### Proposed use cases

- `StartOrResumeDecisionSession`
- `PickRecommendation`
- `ReplaceOrCancelPick` if accepted
- `GetPendingViewingConfirmation`
- `ConfirmViewingOutcome`
- `RecordHomeAlreadyWatchedCorrection`
- `RecordDecisionSearchOutcome`
- `GetPilotMeasurementSummary`
- `DeletePilotMeasurementHistory` if accepted
- `ExportPilotMeasurementReport` if accepted

These are semantic boundaries, not mandated concrete type names. One focused
use case may own more than one operation when doing so keeps invariants atomic.

### Pick sequence

```mermaid
sequenceDiagram
    participant V as Viewer
    participant H as Home Presentation
    participant U as PickRecommendation
    participant D as ViewingDecisionRepository

    V->>H: Pick recommendation
    H->>U: Decision Set ID, cycle, movie ID, role
    U->>D: Persist validated session decision
    alt Persisted
        D-->>U: Current decision snapshot
        U-->>H: Success
        H-->>V: Picked / Elegida
    else Persistence unavailable
        D-->>U: Typed failure
        U-->>H: Retryable failure
        H-->>V: Pick remains available; no false success
    end
```

The use case verifies that the recommendation belongs to the current accepted
Decision Set and that the source identity is internally consistent. It does
not re-run scoring or mutate Home.

### Viewing confirmation and attribution

Confirmation must orchestrate two separate meanings:

1. persist the historical viewing outcome for the Pick; and
2. apply the accepted current Viewer Movie State transition when the Viewer
   confirms watched or supplies a reaction.

These repositories cannot be committed atomically as one transaction under
the current architecture. The final specification must define retry and
reconciliation before implementation. The Technical Lead proposal is an
idempotent coordinator with stable operation identity:

- first ensure the Viewer Movie State transition is accepted;
- then persist confirmation attribution;
- on relaunch, reconcile any durable incomplete operation;
- never show provenance until both meanings are durable;
- never roll back an already-accepted watched fact solely because attribution
  persistence failed.

This decision likely merits a short ADR together with the local persistence
boundary.

### Presentation state

Home should extend its existing deterministic view state rather than create a
parallel screen model:

- each visible card derives `canPick`, `isPicking`, and `isPicked` from the
  active local decision;
- only the selected card shows in-flight progress;
- other feedback actions remain available according to current M7 behavior;
- stale Pick completions from replaced Home state are ignored by Presentation,
  while the persisted historical decision remains valid if Domain accepted it;
- cancellation propagates through Swift concurrency and never fabricates
  failure or success;
- write failure leaves the action retryable and announces an accessible error.

The coach mark should prefer native TipKit when it can satisfy exact one-time
presentation, dismissal, accessibility, and deterministic test control. Its
datastore should remain local. If those conditions cannot be verified, use a
small custom Presentation component backed by the same persisted local
preference; do not introduce a third-party coach-mark dependency.

Long-search feedback should be driven by elapsed foreground time or a semantic
Domain progress state. Presentation must not infer TMDB page numbers from
incidental implementation details.

### Concurrency

- The Data repository is an actor and the sole mutable owner of its envelope.
- Domain values crossing isolation boundaries are `Sendable`.
- A session mutation is serialized and idempotent under a stable operation or
  decision identity.
- Presentation mutation runs from `@MainActor` and does not launch unstructured
  work whose lifetime outlives the owning view model.
- Search diagnostics receive semantic completion events from the existing Home
  coordinator; measurement must not introduce a second recommendation search.
- Late or cancelled work cannot replace a newer session or Pick state.

## Privacy and persistence

### Data minimization

The proposed envelope stores only the evidence required for the accepted
pilot questions:

- opaque local identifiers;
- TMDB movie IDs, Decision Set/cycle identities, and recommendation roles;
- timestamps or foreground durations required for the funnel;
- explicit Pick, confirmation, satisfaction, and Home correction actions;
- bounded technical search outcome and duration evidence;
- persisted coach-mark state.

It must not store:

- names, account identity, device advertising identity, or household-member
  identity;
- raw search text or future Ask prompts;
- synopsis, poster data, provider payloads, or full movie metadata;
- passive navigation histories or every UI interaction;
- credentials or remote analytics identifiers.

### Proposed storage

Use one independently versioned JSON envelope in Application Support, owned by
the actor repository. Do not add measurement fields to Viewer Profile, Viewer
Movie State, Decision Set, Search History, or Watchlist persistence.

The envelope should follow existing repository guarantees:

- encode and validate a complete envelope before replacement;
- preserve one previous valid copy;
- recover from the previous valid copy or a defined legacy migration;
- quarantine exact corrupt or unsupported bytes for diagnosis;
- never fabricate empty measurement history after failed decoding;
- make schema migration explicit and tested;
- apply accepted retention only after successful decoding and validation.

Measurement unavailability must not block recommendations, feedback, Search,
Watchlist, or `My movies`. A failed Pick write cannot claim `Picked`, but Home
remains otherwise usable. A corrupt measurement envelope should preserve bytes,
attempt recovery, and expose a retryable measurement failure without asking the
Viewer to reset unrelated application data.

Deletion and export behavior remain blocked on the Product Owner's retention
decision.

## Failure behavior

| Failure | Proposed behavior |
|---|---|
| Pick persistence fails | Keep card unpicked, show accessible retry, leave Home usable |
| Coach-mark persistence fails | Do not block Home; suppress repeat in memory and retry persistence later |
| Session recovery fails | Preserve bytes, disable measurement mutation, keep core product usable |
| Viewing-state update fails | Keep confirmation unresolved and retryable; do not claim watched attribution |
| Attribution persistence fails after watched succeeds | Preserve watched state; keep pending reconciliation and withhold provenance badge |
| Local report cannot decode | Preserve source bytes and show an unavailable state, never invented zero metrics |
| App backgrounds during timing | Stop foreground decision duration; resume only under accepted session rules |
| Search is cancelled or superseded | Record no failure and no completed search outcome for cancelled work |

## Acceptance criteria

These criteria combine accepted behavior and conditional technical proposals.
They become executable only after the open product questions are resolved.

### Pick and session

- Every Home recommendation exposes an accessible localized Pick action.
- A successful Pick survives relaunch and shows only on its selected card.
- Pick changes no Viewer Movie State, Taste Profile, Watchlist, eligibility,
  score, Decision Set, or recommendation-cycle history.
- A failed write never presents success and remains retryable.
- Session timing excludes background duration and does not start before a
  usable non-empty Decision Set is visible.
- Duplicate taps and retried operations are idempotent.

### Coach mark

- It appears on the first Home with recommendations and never blocks the cards.
- Dismissal/presentation survives relaunch according to the accepted one-time
  rule.
- It does not appear on loading, failure, or honest empty Home.
- VoiceOver explains both the coach mark and the Pick action without relying on
  the icon alone.

### Confirmation and provenance

- Only explicit Pick plus explicit watched confirmation creates PickOne
  provenance.
- Rating or `Already watched` without a Pick never creates provenance.
- `My movies` distinguishes provenance independently of the current reaction.
- Pending, postponed, cancelled, superseded, watched, and not-watched outcomes
  follow the accepted product transition table.
- Partial cross-repository completion is recoverable after relaunch without
  losing the watched fact or inventing attribution.

### Measurement

- The report derives staged success without collapsing neutral or negative
  satisfaction into success or failure.
- Home-originated `Already watched` evidence excludes Detail, calibration, and
  pre-existing state.
- Reconciliation, card redraw, and relaunch do not double-count a recommendation
  or operation.
- Long-search evidence reuses the actual coordinator operation and adds no
  search request.
- All persisted data remains local and contains no forbidden properties.

### Localization and long-search UX

- Accepted Milestone 8 strings exist in English and Spanish in the chosen
  string-catalog scope.
- Duplicate localization keys and hardcoded variants cannot diverge.
- Prolonged search displays honest accessible feedback without percentages,
  page counts, or promises.
- Result, exhaustion, cancellation, and failure remove the prolonged-search
  state deterministically.

## Test strategy

### Domain tests

- session start/resume/end and foreground-duration boundaries;
- Pick validation against the current Decision Set identity;
- repeated Pick idempotency and accepted replacement/cancellation transitions;
- staged outcome classification for Pick, watched confirmation, and each Movie
  reaction;
- provenance requires Pick plus confirmed watched;
- direct reaction and `Already watched` do not create provenance;
- Home correction denominator and deduplication;
- summary calculation from retained records;
- retention and deletion once accepted.

### Data tests

- clean round-trip and deterministic encoding of the versioned envelope;
- actor serialization under concurrent mutations;
- active, previous-valid, migration, unsupported-schema, corrupt-data, and
  quarantine paths;
- exact bytes survive failed recovery and replacement;
- relaunch during pending cross-repository confirmation reconciliation;
- retention never removes an active pending decision;
- no network client or external analytics dependency exists.

### Presentation tests

- first-use coach mark, dismissal, persistence, and no-result suppression;
- Pick/loading/Picked/failure/retry per-card states;
- VoiceOver labels, focus order, Dynamic Type, and Reduce Motion;
- accepted Pick replacement/cancellation interaction;
- viewing-confirmation timing and postponement;
- `My movies` provenance badge with and without a current reaction;
- prolonged-search timing, cancellation, replacement, and terminal states;
- English and Spanish snapshots or semantic string assertions for both equal
  and longer translated labels.

### Integration and regression tests

- launch with an existing final-M7 installation and preserve every current
  repository unchanged;
- Home Pick → relaunch → pending confirmation → confirmed watched → `My movies`
  provenance;
- Home direct rating/`Already watched` without Pick → no provenance;
- Pick does not regenerate Home or change Taste Profile;
- M7 quick feedback, bounded suppression, rollover, exhaustion, Watchlist,
  Search History, and recalibration remain unchanged;
- partial persistence failure recovers after relaunch;
- local summary and export, if accepted, match known event fixtures exactly.

### Physical-device validation

On the Product Owner's retained iPhone installation:

- install over the final M7 build without deleting data;
- confirm existing Home, profile, Viewer Movie State, Watchlist, Search History,
  and `My movies` survive;
- use Pick in English and Spanish device-language configurations as accepted;
- relaunch before confirmation and verify the pending decision survives;
- confirm watched and verify provenance plus independent reaction display;
- rate an already-seen Home card and verify it does not gain provenance;
- exercise one prolonged twenty-page recovery and record the feedback timing
  and total latency without persisting debug-only instrumentation;
- inspect the local report/export against the performed actions;
- validate VoiceOver and the largest supported Dynamic Type size.

## Proposed delivery slices

No slice is authorized until this document is Product Ready and its technical
proposal is accepted as Engineering Ready. Each implementation PR starts from
the latest `develop`, remains independently green where dependencies allow,
uses semantic names, and closes only its own accepted scope.

```text
D0 accepted product + ADR + canonical document updates
 └── PR1 typed local decision contracts and persistence
      └── PR2 Home session, Pick, and coach mark
           ├── PR3 viewing confirmation and My movies provenance
           └── PR4 long-search feedback and Home correction measurement
                └── PR5 local pilot readout/export
                     └── PR6 integration, physical validation, and M8 closure
```

### D0 — Product and engineering acceptance

Outcome:

- resolve every open product question;
- update `PRODUCT.md`, roadmap, IMP-005, and IMP-023;
- extend the Product Language Glossary with `Decision session`, `Pick`,
  `Viewing confirmation`, `PickOne-assisted viewing`, and `Pilot measurement`;
- add an ADR for the separate local decision aggregate, versioned persistence,
  cross-repository confirmation reconciliation, privacy, and recovery;
- mark the milestone Product Ready and Engineering Ready only after joint
  acceptance.

No production code.

### PR1 — Local decision Domain and persistence foundation

Outcome:

- typed Domain identities, records, invariants, summary projection, and
  repository contract;
- actor-owned Data implementation with versioned envelope, recovery,
  quarantine, retention hooks, and test fixtures;
- composition-root wiring without user-visible behavior.

Verification:

- focused Domain/Data suites, concurrency serialization, recovery, migration,
  privacy-schema audit, and full `make verify`.

Deferred: Home UI, coach mark, confirmation, provenance, long-search UI, and
reporting.

### PR2 — Home session, Pick, and coach mark

Depends on PR1.

Outcome:

- accepted session lifecycle around current Home navigation;
- localized per-card Pick interaction and durable Picked state;
- accessible one-time coach mark;
- failure/retry and relaunch behavior.

Verification:

- focused view-model/UI tests, localization, accessibility, cancellation,
  idempotency, M7 Home regression, and physical Pick smoke.

Deferred: viewing confirmation and My movies provenance.

### PR3 — Viewing confirmation and My movies provenance

Depends on PR2.

Outcome:

- accepted confirmation timing, choices, and transitions;
- idempotent cross-repository orchestration and relaunch reconciliation;
- provenance projection and independent `My movies` presentation.

Verification:

- every transition, partial failure, relaunch, direct-rating non-attribution,
  localization, accessibility, and physical confirmation journey.

### PR4 — Long-search and recommendation-correction evidence

Depends on PR2. May be developed after PR2 while PR3 proceeds only if the
branches do not edit the same Home state/coordinator files; otherwise deliver
sequentially.

Outcome:

- accepted prolonged-search feedback driven by semantic coordinator state;
- local Home-originated `Already watched`, new-set, exhaustion, and search
  duration evidence;
- no new candidate or availability requests.

Verification:

- fake-clock thresholds, cancellation/supersession, exact deduplication,
  twenty-page path, accessibility, and preserved M7 latency evidence.

### PR5 — Local pilot readout and controlled lifecycle

Depends on PR3 and PR4.

Outcome:

- accepted local summary/readout;
- export/share and measurement-only deletion if accepted;
- retention enforcement and privacy explanation.

Verification:

- fixed fixture summaries, export content audit, retention boundaries,
  deletion isolation, accessibility, and no external network transmission.

### PR6 — Integration and milestone closure

Depends on PR1–PR5.

Outcome:

- final upgrade/relaunch journey and all-surface integration evidence;
- Product Owner physical-device validation;
- final `PRODUCT.md`, roadmap, backlog, ADR, and milestone status updates;
- explicit pilot findings without claiming statistical validation.

This slice owns no new product behavior.

## Risks and mitigations

| Risk | Consequence | Proposed mitigation |
|---|---|---|
| Ambiguous session boundary | Misleading time-to-decision | Product accepts one explicit lifecycle before schema design |
| Measurement coupled to Viewer Movie State | Preference corruption and difficult migration | Independent aggregate and repository |
| Cross-repository partial write | Watched fact and provenance disagree | Stable idempotent operation plus relaunch reconciliation |
| Local evidence has no readable surface | Pilot cannot evaluate its hypothesis | Accept a Settings summary/export path before implementation |
| Mixed English/Spanish UI | Incoherent experience and duplicated copy | String Catalog plus accepted localization scope |
| Timestamps reveal sensitive habits | Privacy cost exceeds pilot value | Foreground durations, minimization, bounded retention, local-only storage |
| Event-style API becomes generic analytics framework | Premature infrastructure and untyped data | Semantic Domain operations and fixed fields only |
| Reconciliation double-counts cards | Inflated already-watched rate | Stable session/recommendation identity and deduplication |
| Measurement corruption blocks Home | Core product becomes less reliable | Independent failure boundary; never block recommendations |
| Coach mark becomes recurring friction | Pick action feels harder, not clearer | Persist once, non-blocking display, accessible dismissal |
| Long-search UI exposes implementation | Copy breaks when paging changes | Semantic time/progress state, no page numbers |
| Historic satisfaction changes retroactively | Pilot findings become unstable | Accept immutable capture semantics or explicitly choose current-state reporting |

## Non-goals

- trailers, autoplay, or video-provider selection;
- external analytics, backend event ingestion, dashboards, experimentation, or
  remote feature flags;
- accounts, cloud sync, household profiles, or cross-device measurement;
- automatic inference of Pick, watched, satisfaction, or abandonment;
- new onboarding questions or inferred watched-history import;
- changes to P1 scoring, eligibility, credibility, roles, suppression,
  rollover, availability rules, or Taste Profile derivation;
- `Not tonight`, mood/context refinement, or free-text Ask;
- changing Watchlist semantics or introducing rewatch intent;
- full-application localization unless separately accepted;
- a physical Swift module or package;
- statistically valid experimentation from the single-household pilot.

## Documentation required after acceptance

D0 must update, in one documentation-only change:

- `PRODUCT.md` — explicit Pick, staged outcomes, local measurement, privacy,
  localization scope, and accepted non-goals;
- `docs/product/product-roadmap.md` — rename M8 from trailers to measurement and
  record the accepted outcome;
- `docs/product/improvement-backlog.md` — reconcile IMP-005 and IMP-023 with
  accepted measurement semantics and remove trailers from M8;
- `docs/product/product-language-glossary.md` — add the new canonical terms;
- a new ADR — own local decision persistence and reconciliation architecture;
- this milestone — change status only when Product Ready and Engineering Ready
  are both genuinely satisfied.

## Platform references

- [Apple — Localization](https://developer.apple.com/documentation/xcode/localization)
- [Apple — Localizing and varying text with a string catalog](https://developer.apple.com/documentation/xcode/localizing-and-varying-text-with-a-string-catalog)
- [Apple — TipKit configuration options](https://developer.apple.com/documentation/tipkit/tips/configurationoption)
- [Apple — TipKit datastore location](https://developer.apple.com/documentation/tipkit/tips/configurationoption/datastorelocation)

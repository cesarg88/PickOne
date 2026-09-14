# Milestone 8 — Local Pilot Measurement

## Status

`Accepted — Product Ready and Engineering Ready`

- Product decisions: **Accepted**.
- Product Ready: **Yes**.
- Engineering Ready: **Yes**.
- Implementation authorized: **PR1 only**, explicitly by the Product Owner on `2026-09-14`.
- Product Owner acceptance: `2026-09-14`.
- Technical Lead acceptance: `2026-09-14`.
- Milestone 7 is complete.
- D0 merged into `develop` in #50 (`c31e39f`). PR1 is delivered separately;
  PR2+ remains outside its authorization and scope.

## Authority and purpose

- Product authority: [`PRODUCT.md`](../../PRODUCT.md)
- Engineering authority: [`ENGINEERING.md`](../../ENGINEERING.md)
- Delivery model:
  [Product and Engineering Agent Delivery Model](../process/agent-delivery-model.md)
- Product language:
  [Product Language Glossary](../product/product-language-glossary.md)
- Related backlog: IMP-005 and IMP-023
- Architecture:
  [ADR-015 — Local Decision Sessions, Measurement, and Viewing Provenance](../decisions/adr-015-local-decision-measurement-and-provenance.md)

If this draft conflicts with `PRODUCT.md`, `PRODUCT.md` wins. If it conflicts
with `ENGINEERING.md`, `ENGINEERING.md` wins.

Milestone 8 measures whether PickOne helps the household pilot make and
complete a movie decision. It adds explicit Pick and viewing-confirmation
interactions, durable PickOne provenance, and a minimal local report. It does
not optimize engagement or introduce remote analytics.

## Product problem and outcome

Milestone 7 proved that PickOne can produce useful, available recommendations.
It did not prove that a recommendation caused a decision or a completed
viewing. Detail opens, passive impressions, Watchlist intent, and ratings of
previously watched movies cannot establish that outcome.

Milestone 8 should let the pilot answer:

- How often does a recommendation session produce an explicit Pick?
- How much foreground decision time passes before the first and final Pick?
- How often is a Pick later confirmed as watched?
- How satisfying are confirmed PickOne-assisted viewings?
- How often does Home recommend a movie the Viewer already watched?
- How many sets and expanded searches precede a decision?

These are local diagnostic signals for one household, not statistically valid
experimentation. Qualitative Product Owner feedback remains required.

## Accepted product decisions

### Measurement before trailers

- Milestone 8 measures the decision experience first.
- Trailers remain outside M8 and may return only when evidence justifies them.
- Visual long-search feedback is deferred to the visual-improvement milestone.
  M8 may record technical search duration, expansion, and outcome without new
  search UI.

### Staged success

Success is a funnel, not one boolean:

| Stage | Required explicit evidence | Interpretation |
|---|---|---|
| Pick | Pick from a Home recommendation | PickOne supported a decision |
| Confirmed watched | Pick plus `Sí, la vi` / `Yes, I watched it` | PickOne contributed to a completed viewing |
| `Love it` / `Like it` | Optional confirmation reaction | Strong decision and recommendation-quality success |
| `It was okay` | Optional confirmation reaction | Decision utility with neutral satisfaction |
| `Didn't like it` | Optional confirmation reaction | Decision/viewing occurred, but recommendation quality was negative |

No reaction never implies neutral or negative satisfaction.

### Pick interaction

- Every Home recommendation has a visible, compact button with icon and
  `Pick` in English or `Elegir` in Spanish. It is not icon-only.
- After durable success, the active recommendation shows `Picked` / `Elegida`.
- The accessibility label includes the movie title. Its hint explains that the
  action records the choice without marking the movie watched.
- A Pick changes no watched state, Movie reaction, Taste Profile, Watchlist,
  availability, eligibility, score, or Decision Set.
- Only one Pick is active. The Viewer may replace or cancel it.
- Replaced and cancelled Picks remain `superseded` or `cancelled` history.
  Neither means watched, rejected, nor dissatisfied.
- A coach mark is outside M8. Physical validation must test whether the
  self-contained affordance is discovered and understood. A coach mark or
  spotlight may be reconsidered in the visual milestone if evidence requires
  it.

### Recommendation session

A session is one bounded attempt to decide from Home:

- it begins when a valid Home surface displays at least one usable
  recommendation while the app is active;
- Detail opened from a recommendation observed in that session remains part of
  the session;
- `Give me three more` does not restart it: the action count increases and the
  resulting visible Decision Set is recorded once;
- only foreground intervals contribute to decision duration;
- background pauses duration but wall-clock inactivity continues;
- after 30 minutes with no activity, a session without an active Pick closes
  as `abandoned` and is preserved; a session with an active Pick finalizes with
  that decision;
- after the boundary, the next valid Home/related Detail surface creates a new
  session even if its card belongs to a Decision Set generated earlier;
- attribution belongs to the session where the card was observed and selected,
  not where its Decision Set was generated.

The session preserves:

- foreground time to the first successful Pick;
- foreground time to the final active Pick;
- observed Decision Set identities without duplicates;
- explicit `Give me three more` actions;
- superseded and cancelled Pick history.

A Pick received without a trustworthy active session is still preserved. Its
timing is `unavailable`, it is excluded from time-to-decision calculations, and
no zero duration is fabricated. It remains eligible for confirmation and
provenance.

### Viewing confirmation

- A pending Pick becomes eligible for confirmation when the Viewer returns to
  Home at least 12 hours after the active Pick.
- The prompt is non-blocking and offers:
  - `Yes, I watched it` / `Sí, la vi`;
  - `Not yet` / `Todavía no`;
  - `I didn't watch it after all` / `Al final no la vi`.
- `Not yet` postpones automatic presentation for 24 hours.
- After three postponements, the prompt stops appearing automatically and the
  decision remains in a compact pending-confirmations section in `My movies`.
- `I didn't watch it after all` closes the outcome without watched state or
  provenance.
- `Yes, I watched it` commits watched state and durable PickOne provenance,
  then immediately offers an optional second step: `What did you think?` /
  `¿Qué te pareció?` with the four Movie reactions and `Not now` / `Ahora no`.
- Watched confirmation and provenance never depend on answering satisfaction.
- A reaction supplied there updates current Viewer Movie State and is captured
  as the immutable satisfaction snapshot for that session.
- Later reaction edits update current reaction and Taste Profile without
  rewriting the historic snapshot.

### My movies provenance

- A compact `PickOne` badge with icon appears only when an explicit Home Pick
  was later confirmed watched.
- Its accessibility label is `Chosen with PickOne` / `Elegida con PickOne`.
- Provenance is visually and semantically independent from satisfaction.
- `My movies` also exposes compact pending confirmations after their third
  postponement.
- Rating or marking an already-seen recommendation without Pick never creates
  provenance.
- Marking a movie unwatched hides the badge. It does not erase retained session
  history or fabricate a different outcome.

### Local measurement and lifecycle

- Measurement stays on-device. There is no backend, analytics SDK, account,
  sync, or remote transmission.
- Completed sessions are retained for 180 days.
- `Pilot insights` in Settings presents a local aggregate and supports local
  export and deletion of measurement only.
- Deletion or retention never removes Viewer Profile, watched state, reactions,
  Watchlist, Search History, Decision Sets, or durable PickOne provenance.
- Reset preferences preserves provenance while watched remains true.
- M8 records:
  - funnel stage counts;
  - foreground time to first and final Pick;
  - sets observed and `Give me three more` actions;
  - confirmations, postponements, and optional satisfaction snapshots;
  - successful `Already watched` actions originating from Home;
  - semantic technical search duration, expansion, and outcome.
- It does not capture exhaustive passive navigation, raw Search/Ask text, or
  unrelated UI activity.
- The Home already-watched rate uses distinct recommendation movie IDs observed
  per session so redraws and reconciliation do not inflate its denominator.

### Localization and availability feedback

- Every new or modified M8 surface is localized in English and Spanish through
  a String Catalog.
- Whole-app translation is deferred to Milestone 9.
- `Didn't like it` measures dissatisfaction with the movie recommendation.
- A separate `Availability is incorrect` action is outside M8 and remains a
  backlog candidate only if real availability errors justify it. It must never
  alter Taste Profile when introduced.

## Open product questions

None. Product decisions are closed for D0 promotion.

## Technical contract for D0 acceptance

### Authorities and dependency direction

Pick and measurement do not belong in a Decision Set. Keep the existing
dependency direction `Presentation → Domain ← Data` and use semantic Domain
operations rather than a generic analytics API.

Two local authorities have different lifecycles:

1. `ViewerMovieStateRepository` owns current watched, reaction, Watchlist,
   `Not interested`, and the durable per-movie PickOne viewing provenance.
   Provenance does not affect P1, Taste Profile, eligibility, or availability.
2. A new `ViewingDecisionRepository` owns sessions, Pick history, pending
   confirmations, immutable satisfaction snapshots, diagnostic search evidence,
   retention, and local-report inputs.

`PilotMeasurementSummary` is derived, never persisted as a second source of
truth. Existing movie repositories supply display metadata; measurement does
not duplicate titles, posters, or provider payloads.

No physical Swift module or package is justified. Use folders and protocols in
the current modular monolith and reconsider only after the boundary stabilizes
or build measurements justify extraction.

### Semantic model

Working names must remain semantic and contain no milestone or PR identifiers.

- `DecisionSessionID` and `ViewingDecisionID` are opaque, non-reusable IDs.
- A session owns start/end, foreground intervals or accumulated duration,
  wall-clock last activity, observed Decision Set IDs, refresh count, search
  evidence, and its decision chain.
- A viewing decision owns movie ID, source Decision Set/cycle/role, Pick time,
  status, confirmation eligibility, postponements, outcome, and optional
  satisfaction snapshot.
- Every mutation is idempotent under a stable operation identity.
- A recovered Pick with unreliable timing uses an explicit unavailable value.
- Current display state joins these records with existing movie and Viewer
  Movie State repositories.

### Confirmation reconciliation

Confirmation crosses two repositories and therefore requires a persisted,
idempotent operation:

1. record the pending confirmation operation locally;
2. atomically apply watched plus durable provenance in Viewer Movie State;
3. apply an optional reaction through the accepted Viewer Movie State reducer;
4. finalize the session outcome and optional satisfaction snapshot;
5. reconcile any incomplete operation on relaunch.

Presentation shows provenance only after Viewer Movie State accepted it. A
later measurement write failure never rolls back watched/provenance; the
pending operation remains retryable. The D0 ADR must own this ordering,
migration, and recovery contract.

### Presentation and concurrency

- Existing `@MainActor` view models own UI state and structured task lifetime.
- The measurement repository is an actor and the sole mutable owner of its
  envelope.
- Domain values crossing isolation boundaries are `Sendable`.
- Only the affected card shows Pick progress or failure.
- Stale completions cannot replace newer Pick/session state.
- App lifecycle signals start/pause foreground timing; repository timestamps
  remain injectable for deterministic tests.
- Measuring search consumes semantic outcomes from the existing coordinator
  and never launches another candidate or availability request.

### Future remote delivery

Local state remains authoritative. Records use stable semantic IDs, event
meaning, timestamps, and schema versions so a future Data adapter can derive a
typed outbox.

A future integration may add asynchronous, idempotent delivery through a
vendor-neutral port and explicit property allowlist. M8 does **not** add an
outbox, `MeasurementDelivery`, SDK, network request, or
`track(name:properties:)`. Mixpanel/Firebase concerns must never enter Domain.

## Privacy and persistence

Use a separately versioned JSON envelope in Application Support, actor-owned
and independent from other repositories. It stores only opaque IDs, TMDB movie
IDs, recommendation identities/roles, required timestamps/durations, explicit
actions, and bounded search evidence.

It must not store names, account/device advertising identity, raw prompts,
Search text, full movie metadata, provider payloads, or passive navigation.

The Data implementation must:

- encode and validate a complete envelope before replacement;
- retain one previous valid copy;
- migrate only known schemas;
- quarantine exact corrupt or unsupported bytes;
- never fabricate empty history after failed decoding;
- prune eligible completed sessions older than 180 days only after successful
  validation;
- retain active Picks and pending confirmations regardless of age;
- keep measurement deletion isolated from durable provenance and all existing
  repositories.

Measurement failure cannot block Home, Search, Watchlist, feedback, or
`My movies`. A failed Pick write cannot claim `Picked`, but leaves a retryable
action. An unavailable local report shows unavailable, never invented zeroes.

Viewer Movie State requires a versioned migration for durable provenance.
Existing records migrate without provenance; M8 never infers it from watched or
reaction history.

## Acceptance and tests

### Domain and Data

- session start, related Detail, refresh, foreground/background, 30-minute
  boundary, abandonment, old-set reuse, and timing-unavailable fallback;
- first/final Pick timing, replacement, cancellation, and duplicate-operation
  idempotency;
- confirmation eligibility at 12 hours, three 24-hour postponements, manual
  pending access, watched/not-watched outcomes, and optional reaction snapshot;
- provenance requires Pick plus explicit watched confirmation and never affects
  Taste Profile or recommendation gates;
- active/previous/migration/quarantine/relaunch and partial-operation recovery;
- 180-day pruning preserves active work and measurement deletion preserves all
  non-measurement state;
- exact aggregate metrics and already-watched deduplication from fixed fixtures;
- concurrency serialization and cancellation under Swift 6.

### Presentation and integration

- localized visible Pick/Picked control, title-specific accessibility label,
  semantic hint, per-card progress, failure, and retry;
- physical discoverability without coach mark, VoiceOver, Dynamic Type, and
  English/Spanish configurations;
- non-blocking Home confirmation, postponement, optional reaction, and
  `My movies` pending section;
- PickOne badge only for confirmed provenance and hidden while unwatched;
- `Pilot insights` summary, export, and measurement-only deletion;
- Home direct rating or `Already watched` without Pick creates no provenance;
- Pick alone does not regenerate Home or mutate current movie state;
- M7 recovery, quick feedback, Watchlist, Search History, recalibration, and
  existing installed data remain unchanged;
- technical search evidence adds no requests and no long-search UI.

### Physical-device validation

Install over the retained final-M7 app without deleting data. Verify existing
state survives, discover and understand Pick without a tutorial, replace and
cancel choices, relaunch before confirmation, exercise all confirmation paths,
confirm the badge/reaction separation, inspect/export/delete Pilot insights,
and verify deletion preserves provenance and all other repositories.

## Delivery plan

No implementation begins until this accepted documentation-only D0 PR merges
and the Product Owner explicitly authorizes PR1.

```text
D0 canonical documents + ADR
 └── PR1 Pick and session
      └── PR2 confirmation and provenance
           └── PR3 Pilot insights
                └── PR4 integration and closure
```

### PR1 — Pick and session vertical slice

Add typed Domain contracts, actor-owned local persistence, session lifecycle,
Pick/replace/cancel, English/Spanish affordance, recovery, and focused tests.
The outcome is observable and independently validatable. Defer confirmation,
provenance, insights, and remote-delivery abstractions.

PR1 implementation and requirement coverage are recorded in
[`pick-and-session.md`](../engineering/validation/pick-and-session.md).
This partial delivery does not close the milestone or authorize PR2+.

### PR2 — Confirmation and provenance

Add eligibility/postponement behavior, optional satisfaction step, the
idempotent cross-repository operation, Viewer Movie State provenance migration,
`My movies` badge/pending section, and relaunch recovery.

### PR3 — Pilot insights

Add funnel and Home/search evidence, derived summary, Settings presentation,
local export, 180-day retention, and measurement-only deletion. Do not add
availability feedback or long-search UI.

### PR4 — Integration and closure

Add no new behavior. Prove final-M7 upgrade, prolonged/relaunch journeys,
privacy and regression coverage, complete physical validation, and close the
milestone, ADR, roadmap, and backlog documentation.

## Risks

| Risk | Required mitigation |
|---|---|
| Session ambiguity corrupts time-to-decision | Accepted lifecycle, injectable clocks, unavailable rather than zero |
| Measurement couples to current movie state | Separate repositories and explicit authorities |
| Partial confirmation write creates disagreement | Persisted idempotent reconciliation |
| Retention erases user-visible provenance | Provenance lives durably in Viewer Movie State |
| Reconciliation inflates metrics | Stable IDs and per-session deduplication |
| Mixed-language UI | String Catalog for every affected M8 surface |
| Measurement corruption blocks core use | Independent failure boundary and recovery |
| Generic analytics abstraction leaks vendors | Typed semantic records; remote outbox deferred |
| Local evidence cannot be evaluated | Pilot insights plus explicit export |

The four-PR reduction introduces no known technical contradiction. PR2 is the
highest-risk slice because it owns migration and cross-repository recovery; it
must remain isolated and merge before insights work.

## Non-goals

- trailers, autoplay, or video-provider selection;
- coach marks, spotlights, or visual long-search feedback;
- incorrect-availability feedback;
- backend analytics, SDKs, outbox, remote delivery, dashboards, or experiments;
- accounts, sync, household profiles, or cross-device measurement;
- automatic inference of Pick, watched, satisfaction, or abandonment outcome;
- onboarding expansion, rewatch intent, `Not tonight`, context, or Ask;
- P1, availability, eligibility, credibility, suppression, or rollover changes;
- exhaustive navigation tracking or raw user text;
- whole-app localization, deferred to M9;
- a physical Swift module or statistically valid experimentation.

## D0 acceptance checklist

- [x] Update `PRODUCT.md` with accepted M8 behavior and privacy boundaries.
- [x] Rename and update M8 in `docs/product/product-roadmap.md`.
- [x] Reconcile IMP-005 and IMP-023 in the improvement backlog.
- [x] Extend the glossary with session, Pick, confirmation, provenance, and
      pilot-measurement terms.
- [x] Draft the local decision persistence/reconciliation ADR.
- [x] Product Owner and Technical Lead accept this specification and ADR-015.
- [x] Merge the documentation-only D0 PR (#50, `c31e39f`).
- [x] Mark this milestone and ADR-015 accepted after review.
- [x] Authorize PR1 explicitly after D0 is merged (Product Owner, `2026-09-14`).

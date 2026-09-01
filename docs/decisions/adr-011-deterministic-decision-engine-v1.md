# ADR-011 — Deterministic Decision Engine v1

## Status

Accepted baseline — Milestone 7 P0 amendment proposed in ADR-014

The Product Owner accepted this product and architecture decision on
2026-08-11. The Lead Engineer should treat the formula, eligibility rules,
pipeline and test obligations below as the canonical Milestone 6 contract.

On 2026-08-19, the Product Owner accepted a closure correction for visible
positive-anchor explanations. It narrows which computed similarity may be
named to the Viewer but does not change any P1 score, weight, threshold, role,
or ordering rule.

On 2026-08-24, accepted Milestone 7 D0 amended input ownership, successor-cycle
history inheritance, non-reusable Viewer State snapshot identity, and the
Decision Set v1-to-v2 migration path. P1 scoring remains unchanged.

On 2026-08-27, the Product Owner accepted a Milestone 7 clarification for
human-readable genre evidence and complete Taste Profile hydration. Internal
genre IDs remain valid scoring identity but may never appear in copy. Reaction
metadata hydration becomes bounded and parallel while remaining deterministic,
cancellable, and all-or-nothing. P1 scoring remains unchanged.

On 2026-09-01, final physical validation reopened Milestone 7 after permanent
shown-history exclusion exhausted the pilot recall pool. The Product Owner
accepted bounded recent suppression, progressive recall, old-title rollover,
stable card reconciliation, and preservation of every explicit exclusion.
ADR-014 proposes the exact window, paging, persistence, migration, exhaustion,
and quick-feedback policy. Those values require D0 approval before
implementation; P1 scoring remains unchanged.

## Context

PickOne must produce the first implementation of **Three for Tonight** for
Milestone 6. The product needs a small, deliberate, watchable and explainable
Decision Set without depending on an AI service or opaque ranking system.

The accepted product contract requires:

- three purposeful roles: Safe Choice, Stretch Choice and Discovery Choice;
- verified subscription availability in the active region;
- stable results for identical input snapshots;
- honest smaller or empty sets when evidence is insufficient;
- short recommendation reasons supported by evidence PickOne owns;
- persistence across app launches and deliberate refresh;
- room to consume richer feedback later without redesigning the engine.

The scoring model was developed from deterministic synthetic fixtures and then
checked against a frozen real-movie calibration exercise. P1 is the first model
accepted for the household pilot.

This ADR consolidates those product and technical decisions into the canonical
Milestone 6 implementation contract.

## Decision

PickOne will implement Decision Engine v1 as a deterministic domain capability.

Given the same:

- Viewer Profile and calibration reactions;
- Watchlist and watched state;
- current recommendation-cycle history;
- TMDB candidate and metadata snapshot;
- region, selected providers and movie-level availability evidence;
- engine constants and tie-breaking rules;

the engine produces the same Decision Set.

The engine uses TMDB Discover for recall, explicit eligibility gates, the
accepted P1 scoring formula, deterministic greedy diversification and
evidence-backed explanation templates. It does not use an LLM, embeddings,
collaborative filtering or hidden title-specific exceptions.

P1 constants are accepted implementation inputs for the pilot, not permanent
product promises. They may change only through a reviewed model revision that
reruns the accepted fixture pack and household utility check.

## Scope

This ADR defines:

- candidate generation and enrichment;
- input evidence and reaction semantics;
- watch and availability eligibility;
- P1 scoring and quality thresholds;
- diversity and role assignment;
- deterministic tie-breaking;
- explanation evidence and templates;
- Decision Set persistence, invalidation and refresh;
- failure and honest-empty behavior;
- architecture boundaries and test obligations.

It does not define:

- backend, account or cross-device synchronization;
- collaborative or household-profile ranking;
- catalog-wide rating UI;
- natural-language Ask implementation;
- model training or remote AI providers;
- TV-series recommendations;
- automatic tuning from passive behavior.

## Terms

Cross-cutting terms use the canonical
[Product Language Glossary](../product/product-language-glossary.md). The local
definitions below preserve the exact Milestone 6 contract.

### Candidate

A TMDB movie admitted to the recall pool. Candidate status does not imply final
eligibility or recommendation quality.

### Eligible candidate

A candidate that is not known watched, has not already appeared in the current
recommendation cycle, and has verified selected-provider availability under the
active region's `flatrate` evidence.

### Directional reaction

`Love it`, `Like it` or `Didn't like it`. `It was okay` is watched evidence but
not directional taste evidence. `Haven't seen` and `Don't know it` are neither
taste nor watched evidence.

### Decision Set

An ordered set of zero to three recommendations, with at most one item assigned
to each product role: Safe, Stretch and Discovery.

### Recommendation cycle

The sequence of Decision Sets produced by explicit `Give me three more`
actions under one immutable cycle identity. The identity is a deterministic
signature of engine model version, profile and reactions, region, selected
providers, and explicit viewing context. Complete shown history is diagnostic;
the active set and a bounded recent subset are temporarily suppressed.

Watchlist save and watched state is mutable eligibility and intent evidence,
not part of cycle identity. A Watchlist change may invalidate or repair the
current set, but it clears neither complete diagnostic history nor bounded
recent suppression.

## Inputs

Decision Engine v1 may consume only evidence owned or verified by PickOne:

- Viewer Profile inputs and the current Viewer State snapshot identity;
- calibration reactions;
- Watchlist save and watched state;
- current-cycle movie IDs;
- active region and selected supported providers;
- TMDB movie identity, localized title and artwork;
- genres;
- release year;
- runtime;
- `voteAverage`;
- `voteCount`;
- movie-level provider availability and verification time.

Runtime is informational in M6 and does not affect default scoring. Availability
is an eligibility gate. The remaining scoring metadata is genres, release era,
rating and vote evidence.

Decision Engine v1 does not score using:

- TMDB popularity;
- cast or director;
- keywords, themes, tone or pacing;
- production companies, country or original language;
- runtime;
- passive impressions, detail opens or trailer plays;
- unsupported inferences such as “likes cerebral films” or “likes musicals.”

## Candidate generation

The pilot candidate source is TMDB Discover.

1. Request six pages for normal generation, yielding up to 120 recall
   candidates before exclusions.
2. Use the active Viewer Profile region and Spanish localization for display
   metadata.
3. Set `include_adult = false` and `include_video = false`.
4. Deduplicate by TMDB movie ID.
5. Popularity ordering may be used to obtain a practical recall pool, but
   popularity never contributes to P1 score, explanation or role assignment.
6. Enrich candidates with the metadata and movie-level availability evidence
   required by this ADR.
7. Under the proposed ADR-014 recovery policy, expand cumulatively to page 12
   and then page 20 only when the accepted normal pool cannot fill the set.

The six-page normal boundary and proposed twenty-page recovery boundary are
pilot search-policy parameters, not claims that titles outside either pool are
ineligible or unsuitable.

Discover provider filters may reduce network work, but they are never final
availability proof. A movie can enter the Decision Set only after movie-level
verification.

## Reaction semantics

P1 uses these accepted values:

| Reaction | Value | Taste effect | Watch effect |
|---|---:|---|---|
| `Love it` | `+1.00` | strong positive | watched |
| `Like it` | `+0.50` | positive | watched |
| `It was okay` | `0.00` | neutral | watched |
| `Didn't like it` | `-0.75` | negative | watched |
| `Haven't seen` | excluded | none | not watched |
| `Don't know it` | excluded | none | not watched |

One negative reaction must not create a permanent genre ban. Neutral reactions
may moderate sparse feature evidence through their observation count, but they
never create positive or negative affinity.

## Eligibility

Eligibility is evaluated independently from score and cannot be overridden by
quality, Watchlist intent, diversity or a product role.

Exclude a movie when any of the following is true:

- an informative calibration reaction proves it was watched;
- Watchlist marks it watched;
- another accepted viewing-history source marks it watched;
- its ID is in the current active set during a replacement request;
- movie-level availability is `ineligible`;
- movie-level availability is `unknown`.

A saved but unwatched Watchlist movie remains eligible. Saving expresses weak
current decision intent; it does not modify the stable Taste Profile.

Availability is `eligible` only when the movie-level response contains at least
one selected, allowlisted provider under the active region's `flatrate`
entries. Rent, buy and separately paid add-ons remain ineligible. Missing,
failed, invalid or unverifiable regional evidence is `unknown` and fails closed.

If only two candidates pass every gate and the credibility rule, return two. If
none pass, return an honest empty Decision Set. Never relax watched,
availability or credibility rules merely to reach three.

Recent shown suppression is evaluated separately from permanent eligibility.
ADR-014 permits an older shown title without explicit feedback to return only
after never-shown candidates and progressive recall cannot fill the set. It
never permits an active, watched, reacted, or `Not interested` title to return.

## P1 scoring model

All components are normalized to `[0, 1]`. The final score is a ranking index,
not a probability that the viewer will like the movie.

### Feature affinity

For every genre and release decade represented in watched calibration evidence:

```text
rawMean = sum(reactionValue) / observationCount

evidenceConfidence = observationCount / (observationCount + 2)

affinity = rawMean × evidenceConfidence
```

Signed affinity is normalized for scoring:

```text
normalizedAffinity = (affinity + 1) / 2
```

An unseen genre or decade is neutral rather than negative.

### P1 genre component

P1 rewards candidates supported by multiple positive genre signals while still
allowing unknown or negative genres to moderate the result.

```text
normalizedMeanAffinity = average(
    normalized affinity of every candidate genre
)

positiveGenreCoverage =
    candidate genres with signed affinity > 0.05
    / candidate genre count

genreComponent =
    normalizedMeanAffinity × 0.80
    + positiveGenreCoverage × 0.20
```

If a candidate has no genres, both values are neutralized as defined under
missing metadata; no genre match may be invented.

### Era component

```text
eraComponent = normalized affinity of candidate release decade
```

An unknown release year or unseen decade is neutral (`0.50`). Runtime does not
participate.

### Profile confidence and adaptive weights

Only directional reactions increase confidence that the engine understands
taste:

```text
directionalCount = Love it + Like it + Didn't like it reactions

profileConfidence = directionalCount / (directionalCount + 6)

qualityWeight = 0.35 - (0.20 × profileConfidence)

personalWeight = 1 - qualityWeight

genreWeight      = personalWeight × 0.65
eraWeight        = personalWeight × 0.10
similarityWeight = personalWeight × 0.25
```

Quality therefore carries more influence for a sparse profile and less as
directional evidence grows.

### Positive-movie similarity

Compare the candidate with every `Love it` and `Like it` calibration movie.

```text
genreOverlap = Jaccard(candidateGenres, anchorGenres)

eraSimilarity =
    1.0 when both movies share a decade
    0.5 when their decades are adjacent
    0.0 otherwise

metadataSimilarity =
    genreOverlap × 0.80
    + eraSimilarity × 0.20

anchorStrength =
    1.00 for Love it
    0.75 for Like it

similarityComponent = max(
    metadataSimilarity × anchorStrength
)
```

If there are no positive anchors, `similarityComponent = 0`.

Similarity is intentionally limited to accepted metadata. It must not imply
shared themes, creators, tone or narrative structure.

The maximum similarity calculation above remains unchanged. A positive anchor
may be named in a visible explanation only when all of these stricter evidence
conditions hold:

- the anchor has the Viewer's current `Love it` or `Like it` reaction;
- candidate and anchor share at least one genre;
- genre Jaccard similarity is at least `1/3`.

Release era may reinforce an already-qualified genre anchor but cannot qualify
one by itself. Failing these conditions removes anchor evidence from the
explanation selection; it does not remove the similarity contribution from P1
scoring.

### General quality confidence

```text
ratingComponent = clamp(
    (voteAverage - 5.0) / 3.5,
    0,
    1
)

voteEvidence = clamp(
    log(1 + voteCount) / log(1 + 20,000),
    0,
    1
)

qualityComponent =
    ratingComponent
    × (0.65 + 0.35 × voteEvidence)
```

The `0.65` floor allows a recent movie with little vote evidence to retain most
of its rating-based contribution. High vote evidence adds confidence; low vote
evidence never creates a penalty. Recent movies receive no separate bonus,
penalty or `New` treatment in M6.

### Base score and Watchlist intent

```text
baseScore = 100 × (
    genreComponent        × genreWeight
    + eraComponent        × eraWeight
    + similarityComponent × similarityWeight
    + qualityComponent    × qualityWeight
)

rankScore = min(
    100,
    baseScore + watchlistIntentBonus
)

watchlistIntentBonus =
    2.0 when saved and unwatched
    0.0 otherwise
```

The Watchlist bonus may break a close result but cannot rescue a substantially
weaker candidate. It does not feed back into feature affinity or profile
confidence.

### Credibility admission rule

A normally profiled candidate may enter role selection when:

```text
rankScore >= 50
```

A sparse profile may additionally admit a generally well-supported candidate:

```text
sparseProfile = profileConfidence < (1 / 3)

admitWhenSparse = sparseProfile && qualityComponent >= 0.60
```

Because the confidence formula reaches `1 / 3` at three directional reactions,
this exception applies only at zero, one or two directional reactions. It
prevents an under-informed profile from producing no useful options while
remaining bounded by explicit quality evidence.

The admission rule is applied before diversity. Diversity cannot make a
below-threshold candidate credible.

## Missing metadata

Missing data must have deterministic, conservative behavior:

- no candidate genres: `normalizedMeanAffinity = 0.50` and
  `positiveGenreCoverage = 0`;
- unknown release year: `eraComponent = 0.50` and no era-similarity credit;
- missing or invalid vote data: clamp the affected quality inputs to `0`;
- missing runtime: keep the candidate eligible and display runtime as unknown;
- missing identity required to open Movie Detail: exclude the malformed
  candidate;
- missing or unverified availability: classify as `unknown` and fail closed.

## Pipeline order

The logical pipeline is:

```text
Generate the normal six-page recall pool
↓
Deduplicate and enrich accepted metadata
↓
Exclude hard-ineligible, active, and recently suppressed movies
↓
Compute P1 score and Watchlist intent
↓
Apply credibility admission rule
↓
Verify movie-level availability
↓
Remove ineligible and unknown candidates
↓
Assign Safe, Stretch and Discovery with diversity
↓
Build evidence-backed explanations
↓
Persist the Decision Set and cycle state
```

An implementation may interleave enrichment and availability requests for
efficiency, but observable results must match this logical pipeline for the same
complete snapshot. ADR-014 repeats this pipeline over cumulative expanded pages
and progressively released recent suppression only when the prior stage cannot
fill the set.

## Diversity and product roles

Diversity modifies final composition, not raw P1 scores.

### Diversity selection score

After an item has been selected:

```text
selectionScore = rankScore
    - 10 × maximum genre Jaccard overlap
      with any already selected movie
```

The penalty is recomputed for each open slot. It allows a close, meaningfully
different candidate to replace a near duplicate without rescuing a dramatically
weaker one.

### Role assignment

1. **Safe Choice** — the qualifying eligible candidate with the highest
   `rankScore`.
2. **Stretch Choice** — the remaining qualifying candidate with the highest
   `selectionScore` relative to Safe.
3. **Discovery Choice** — the remaining qualifying candidate with the highest
   `selectionScore` relative to Safe and Stretch.

Roles describe set composition, not three independent scoring formulas.
Discovery is earned through a credible P1 score plus diversity; it is never a
random or below-threshold title.

If no candidate qualifies for an open role, omit that role and return the
smaller set.

### Tie-breaking

For exact ties, use this order:

1. higher `qualityComponent`;
2. lower numeric TMDB movie ID.

Popularity is not a tie-breaker. Compute and compare unrounded values; rounding
is presentation and diagnostics only.

## Explanations

Every recommendation carries structured `RecommendationEvidence` from the
calculation that selected it. Presentation localizes that evidence through a
small deterministic template set.

Allowed evidence:

- a qualified named `Love it` or `Like it` anchor and only the genres or era
  signals actually shared;
- candidate genres with positive learned affinity;
- a supported era affinity;
- verified general-quality evidence, especially for a sparse profile;
- saved-and-unwatched Watchlist intent;
- the deliberate diverse role, when a supported connection is also stated;
- the verified included provider shown separately as availability evidence.

Canonical semantic templates:

```text
Anchor:
Because you {loved|liked} {anchor}, and this shares {supported signals}.

Affinity:
Because {genres} are among your strongest positive signals.

Watchlist:
You saved this for later, and it also matches {supported signals}.

Sparse profile:
A well-supported option while PickOne is still learning your taste.

Diverse role:
A different direction that still connects through {supported signals}.
```

When more than one evidence type is available, choose the primary explanation
with this semantic precedence:

1. saved-and-unwatched Watchlist intent plus a genuine taste match;
2. a named positive `Love it` or `Like it` anchor;
3. learned positive genre affinities;
4. verified general-quality evidence for a sparse profile.

Safe, Stretch and Discovery remain separate role labels. Diversity explains
why a candidate occupies a different role only after a supported taste or
quality connection exists; it never becomes the sole fit reason.

Templates may be localized or tightened for UI space without adding semantic
claims. Do not display numeric scores or confidence percentages.

Genre identity and genre presentation are separate. Numeric TMDB genre IDs may
be used for equality, Jaccard, affinity, and persistence validation, but every
genre named in an explanation requires a trusted human-readable label. Anchor
shared-genre labels and positive-affinity labels resolve deterministically from
the complete hydrated Taste Profile for the matching genre ID. Presentation
must not fall back to `genre <id>` or any other internal identifier.

Persisted evidence that claims a genre signal without a renderable label cannot
be published as-is. It must be repaired or regenerated from trusted inputs
while preserving recommendation-cycle shown history. This is an evidence and
presentation correction only; it changes no score, threshold, credibility
rule, diversity penalty, role, or tie-break.

Persisted and restored anchor evidence is semantically valid only while the
named movie still has the captured current `Love it` or `Like it` reaction and
the stored candidate/anchor metadata still satisfies the genre threshold.
Invalid evidence cannot be rendered or silently downgraded into a generic
anchor claim; the set must be repaired or regenerated from trusted inputs.

Forbidden claims include unobserved preferences, themes, tone, pacing,
creators, “perfect for you,” or certainty that the viewer will enjoy a movie.
Provider copy must remain based on verified availability rather than the
recommendation reason.

## Persistence, refresh and invalidation

The current Decision Set persists across app launches. The pilot has no
automatic freshness expiration.

Persistence separates immutable cycle identity from mutable current
eligibility and display state.

The cycle identity signature contains:

- engine model version;
- the complete relevant profile and reaction snapshot;
- active region and sorted selected provider identifiers;
- explicit viewing context, using the versioned default context in M6.

It must use a stable canonical encoding and digest rather than Swift's
process-randomized `Hasher`. Watchlist save and watched state is deliberately
excluded from the signature.

The persisted conceptual snapshot contains enough information to reproduce and
explain the current product state:

- Decision Set identifier and generation time;
- engine model version (`P1`);
- cycle identity signature;
- active region and selected provider identifiers;
- assigned movie IDs and roles;
- display metadata required to render the retained set after relaunch;
- structured recommendation evidence;
- the reaction value and anchor identity required to validate named anchor
  evidence against the current trusted reaction snapshot;
- provider verification time and verified matching providers;
- recommendation-cycle identifier, complete shown history, bounded ordered
  recent suppression, suppression epoch, and typed exhaustion compatibility.

Persist product evidence and identifiers, not framework-specific repository or
TMDB response types.

Every successfully persisted set records its newly presented movie IDs in
complete diagnostic history and moves them to the newest end of bounded recent
suppression before Presentation publishes it. Replacing one movie after an
eligibility change follows the same rule. Explicit feedback remains a hard
exclusion after its ID ages out of recent suppression.

`Give me three more`:

1. regenerates under the same cycle identity and current mutable eligibility;
2. excludes the active set and full bounded recent window;
3. executes normal recall, progressive expansion, and rollover in one action;
4. preserves complete history and records newly selected IDs as recent;
5. persists the replacement set and updated history atomically;
6. publishes typed exhaustion rather than offering the same deterministic
   operation again when no replacement exists.

The cycle identity changes when the engine model version, active profile or
reactions, region, selected services, or explicit viewing context changes.
Complete diagnostic history survives. `Reset preferences` starts a new recent-
suppression epoch; an app relaunch alone does neither.

Watchlist changes never reset suppression. A newly watched movie invalidates
its current recommendation and triggers deterministic repair. Saved or unsaved
changes reevaluate the Watchlist bonus and explanation evidence and may repair
or replace the current set. In every case complete shown-ID history is
preserved.

### Accepted Milestone 7 input and cycle evolution

ADR-012 changes the owner and lifecycle of inputs without changing P1:

- current Movie reactions come from Viewer Movie State rather than the legacy
  Viewer Profile reaction map;
- watched and `Not interested` are title eligibility exclusions;
- `Not interested` never contributes affinity or similarity;
- Watchlist intent remains the accepted saved-unwatched `+2` bonus;
- a Movie-reaction change creates a new cycle identity, preserves complete
  history and recent suppression, and reevaluates unaffected visible cards;
- Watchlist, watched, and `Not interested` changes repair mutable eligibility
  under the current cycle without clearing complete or recent history;
- when one atomic action changes reaction plus watched or Watchlist, the reaction
  change has precedence and produces one successor cycle rather than an
  eligibility repair followed by regeneration;
- every Decision Set records its source Viewer State snapshot identity, and the
  coordinator rejects a result that is stale before publication.

This scoped evolution supersedes the M6 implication that every reaction-
signature change begins with empty shown history. ADR-014 further bounds which
part of that history suppresses selection. Formula, thresholds, credibility,
diversity, roles, and deterministic tie-breaking remain unchanged.

### Milestone 7 Decision Set envelope migration

Milestone 7 introduces `DecisionSetEnvelopeV2`. It retains all validated v1
fields and adds the opaque `sourceViewerStateSnapshotID` defined by ADR-012.
The source identity is compared for equality before persistence, restoration,
and publication; it is not part of the recommendation-cycle signature.

A `DecisionSetEnvelopeV1` from the final Milestone 6 build is a supported legacy
source, but it can never be published as current because it has no trustworthy
source Viewer State identity. Migration follows this order:

1. decode and semantically validate the complete v1 envelope through the
   existing untrusted-data boundary;
2. preserve its exact bytes as a read-only migration source until a replacement
   v2 envelope has persisted successfully;
3. carry its complete `shownMovieIDs` into reconciliation;
4. recompute the cycle signature from current trusted M7 inputs;
5. retain the v1 cycle identifier when the signature still matches; otherwise
   create a successor cycle while inheriting every v1 shown ID;
6. regenerate recommendations and persist a v2 envelope bearing the current
   Viewer State snapshot identity before Presentation may publish anything.

Migration never fabricates a source identity for the old recommendations and
never treats a valid v1 envelope as corrupt merely because it needs
regeneration. If regeneration or v2 persistence fails, Home shows Retry, the v1
bytes remain available, and no v1 recommendation is presented as current. If
the v1 bytes are corrupt or unsupported, preserve them in diagnostic quarantine
and do not partially extract shown history. Existing recommendation recovery may
then regenerate from trusted inputs, but it must not claim that unverifiable
history was preserved.

Recovery of an older Viewer State snapshot always publishes that state under a
fresh snapshot identity. Therefore every existing v2 Decision Set becomes stale
and must reconcile; an earlier numeric value can never make an old set appear
current.

### Milestone 7 Taste Profile hydration

Every current Movie reaction is part of the P1 input contract. Omitting a
reaction because its metadata request failed would silently change affinity,
profile confidence, score, and explanation under the same Viewer State
identity. Milestone 7 therefore requires complete reaction hydration before P1
may run.

Input assembly sorts reaction movie IDs ascending, schedules at most four
structured child operations through the existing `MovieRepository`, stores
results by their sorted index, and assembles evidence in that deterministic
order. Task completion order never affects engine input. Caller cancellation
propagates through the task group; no detached task or shared mutable result
owner is introduced. Non-cancellation failures are collected by index so the
lowest failed movie ID is the stable diagnostic outcome.

One failed reaction hydration prevents P1 invocation for that generation. The
coordinator retains only a prior persisted set independently proven safe under
the current state; without one it presents Retry. PickOne does not fabricate
empty evidence or produce an explicitly or implicitly degraded Taste Profile.
This all-or-nothing reaction rule is distinct from candidate-specific
enrichment, where one bad candidate may still be excluded when the remaining
complete input is sufficient.

Feedback replaces or invalidates recommendations deliberately according to its
semantics. `Not tonight` is temporary context, not stable dislike. `Already
watched` excludes the title. Passive UI behavior never changes the profile.

Availability is revalidated before provider handoff when the previous
verification is more than 24 hours old. If revalidation invalidates one movie,
replace that movie when a qualifying eligible replacement exists; do not
discard the remaining valid set.

## Failure behavior

Failure and honest emptiness are different product states.

- If candidate retrieval fails and a persisted set remains valid for display,
  preserve that set and report refresh failure without silently replacing it.
- If generation fails without a usable persisted set, surface a retryable
  recommendation-generation failure.
- Candidate-specific enrichment failure excludes only that candidate when the
  remaining snapshot is sufficient.
- Current-reaction metadata hydration is all-or-nothing. Any failed reaction
  prevents P1 from running with partial taste evidence; retain only a
  proven-safe persisted set or expose Retry.
- Availability retrieval failure produces `unknown` for that candidate and
  fails closed.
- Persistence failure must not present an unpersisted set as safely retained;
  preserve the previous persisted state and expose retry.
- If the recommendation envelope is corrupt or uses an unsupported schema,
  preserve its original bytes in diagnostic quarantine, then attempt to
  generate and persist a new set from current trusted inputs. Successful
  recovery replaces only the active recommendation envelope and retains the
  diagnostic bytes. Failed recovery presents Retry and never exposes a Reset
  recommendations action.
- Recommendation recovery must not mutate or delete Viewer Profile, Watchlist,
  or Search History state.
- Exhausting credible eligible candidates only after the accepted progressive
  search and rollover policy produces a successful typed smaller or empty
  outcome, not a transport or system error. It is persisted and actionable and
  cannot expose another known deterministic no-op refresh.

## Architecture boundaries

Decision Engine v1 follows the existing `Presentation → Domain ← Data`
dependency direction.

### Domain

Domain owns:

- immutable engine input and output contracts;
- reaction and evidence semantics;
- pure P1 affinity, score, admission, diversity and role logic;
- deterministic explanation evidence;
- use cases or orchestration protocols required by the feature.

The scoring core is synchronous, side-effect free and independent of SwiftUI,
TMDB DTOs, persistence frameworks and Foundation Models.

### Data

Data owns:

- TMDB Discover retrieval and paging;
- metadata enrichment and DTO mapping;
- movie-level availability verification;
- persisted Decision Set and recommendation-cycle storage;
- repository implementations and cache policy.

### Presentation

Presentation owns:

- generation, refresh and retry intent;
- loading, smaller-set, empty and error states;
- role and explanation rendering;
- deliberate feedback actions.

Milestone 6 exposes five main tabs in this order: Home, Search, Discover,
Watchlist and Settings. Home replaces the current first Discovery tab;
Discovery occupies the current Ask position. Existing Ask code remains in the
target but is not exposed in main navigation until its later milestone.

Async retrieval and persistence orchestration must have a single concurrency
owner and must not make the pure scoring core responsible for cancellation or
network state.

Milestone 6 should begin as an explicit internal boundary in the existing
application target. This ADR does not approve a new physical module or Swift
package. Module extraction remains an evidence-based follow-up if the stable
contract, focused tests or build/ownership needs justify it.

## Foundation Models boundary

Decision Engine v1 does not depend on Apple Foundation Models.

Candidate generation, eligibility, scoring, diversity, role assignment and
canonical explanations remain deterministic. Foundation Models must not rerank
or override P1.

A later milestone may evaluate an optional iOS 26+ adapter that converts Ask
text into a bounded `ViewingIntent` or `PreferenceDelta`. Any such output must
be validated by Domain, must use the same deterministic Decision Engine, and
must have a complete non-generative fallback. Foundation Models types must not
enter Domain.

## Testing and acceptance

Implementation is not complete until the following are automated or explicitly
verified:

### Pure domain tests

- every accepted synthetic fixture A–M;
- P1 reaction values and sparse-evidence shrinkage;
- adaptive weights summing to `1` within numerical tolerance;
- P1 positive genre coverage;
- positive-anchor similarity;
- visible-anchor qualification at genre Jaccard `1/3`, including the
  Deadpool–Parasite negative explanation fixture;
- quality-confidence floor for low vote counts;
- Watchlist `+2` bonus without Taste Profile mutation;
- score `>= 50` admission and sparse `qualityComponent >= 0.60` exception;
- diversity Fixture H result;
- Safe, Stretch and Discovery assignment;
- explanation semantic precedence and diversity never becoming the sole reason;
- deterministic tie-breaking;
- smaller and empty Decision Sets.

### Repository and orchestration tests

- exactly six Discover pages requested when normal generation fills the set;
- cumulative 6→12→20 recovery staging, deduplication, early empty-page stop,
  cancellation, and no unnecessary later-stage requests;
- deduplication by TMDB ID;
- popularity absent from scoring and explanation inputs;
- calibration and Watchlist watched exclusion;
- `unknown` and `ineligible` availability excluded;
- exact selected-provider `flatrate` verification;
- active-set and 30-ID recent suppression across refresh and app relaunch;
- complete shown history preservation with deterministic oldest-first rollover;
- input-change invalidation and cycle reset;
- Watchlist save/watched repair preserving cycle identity and both history
  representations;
- reaction reconciliation retaining every unaffected recommendation whose
  rebuilt evidence remains eligible, credible, and explainable;
- persisted smaller/zero exhaustion and invalidation after a relevant input,
  epoch, or search-policy change;
- Viewer State and Decision Set v2-to-v3 migration, including the sanitized
  blocked-installation fixture;
- valid v1-to-v2 migration preserves exact legacy bytes and every shown ID,
  never publishes a v1 recommendation as current, and persists the current
  Viewer State snapshot identity only after regeneration;
- matching and changed cycle-signature migration paths, failed regeneration,
  failed v2 persistence, and corrupt-v1 no-partial-history behavior;
- stale source snapshot identities before persistence, restoration, and
  publication;
- bounded four-wide reaction hydration, deterministic ascending-ID output under
  out-of-order completion, cancellation propagation, and no P1 invocation from
  partial evidence;
- deterministic lowest-ID diagnostics when multiple reaction hydrations fail;
- unnamed Discover genre IDs resolving to readable anchor and affinity evidence
  without numeric Presentation fallback;
- availability revalidation and single-title replacement;
- atomic persistence and failure preservation;
- corrupt and unsupported envelopes quarantined before regeneration, with
  retry on failed recovery and no mutation of other local stores.

### Product verification

- explanations use only structured supported evidence;
- persisted anchor evidence is checked against the current reaction before
  restoration or publication;
- runtime remains display-only;
- the frozen original and augmented real-profile snapshots reproduce the
  accepted P1 ordering behavior;
- household utility is reviewed after Milestone 6 before changing P1.

Fixture tests are the regression contract. The real-movie sanity check is a
product calibration aid and must not replace deterministic synthetic tests.

## Consequences

### Positive

- behavior is reproducible, inspectable and fixture-testable;
- availability and watched truth cannot be overruled by ranking;
- sparse profiles receive bounded quality support without becoming popularity
  lists;
- new movies are not punished merely for having fewer votes;
- the final set expresses deliberate roles and diversity;
- the engine remains useful on iOS 18 and without AI;
- later catalog reactions or Ask intent can feed the same contracts.

### Costs and limitations

- six Discover pages and movie-level availability verification create network
  and orchestration work;
- coarse TMDB metadata cannot recognize preferences such as “no musicals” or
  “mysteries with unexpected turns” reliably;
- incomplete watch history can produce honest but already-watched false
  positives until catalog-wide reactions exist;
- P1 cannot infer themes, tone, pacing or creator preference;
- deterministic templates are less expressive than generative prose;
- fixed constants require deliberate reevaluation rather than silent tuning.

These are accepted v1 limitations, not reasons to add title-specific exceptions
or unsupported metadata inference.

## Deferred decisions

- runtime as session context;
- a `New` or newly-available badge;
- shared household scoring;
- backend profile and Decision Set synchronization;
- optional Foundation Models intent extraction for Ask;
- physical module extraction;
- post-pilot P2 scoring changes.

## Supporting evidence

- [`PRODUCT.md`](../../PRODUCT.md)
- [`ENGINEERING.md`](../../ENGINEERING.md)
- [Product Language Glossary](../product/product-language-glossary.md)
- [Milestone 7 — Continuous Taste Learning](../milestones/milestone-7-continuous-taste-learning.md)
- [ADR-012 — Unified Local Viewer Movie State](adr-012-unified-local-viewer-movie-state.md)
- [Decision Engine v1 — Product Fixtures](../recommendation/decision-engine-v1-product-fixtures.md)
- [Decision Engine v1 — Real Movie Sanity Check](../recommendation/decision-engine-v1-real-movie-sanity-check.md)
- [Decision Engine v1 — Scoring Prototype](../recommendation/decision-engine-v1-scoring-prototype.md)
- [Apple Foundation Models — Decision Engine Feasibility Study](../research/apple-foundation-models-decision-engine-feasibility.md)

## Superseded material

This accepted ADR supersedes `PickOne/ADR-011-Deterministic-Decision-Engine-v1-draft.md`.
There must be one canonical ADR-011 at
`docs/decisions/adr-011-deterministic-decision-engine-v1.md`.

# PickOne Product Language Glossary

## Status

- Status: `Accepted`
- Product authority: [`PRODUCT.md`](../../PRODUCT.md)
- Initial scope: Milestones 4–7

This glossary defines the canonical product and engineering meaning of terms
that cross product specifications, Domain contracts, ADRs, persistence, and
Presentation. Documents may use shorter UI copy, but they must not silently
change these meanings.

## People and preference state

### Viewer

The person whose current state and preferences PickOne uses to make a decision.
The household pilot has one Viewer: the Product Owner. A Viewer is a product
concept and does not imply an account, login, remote identity, or household
profile.

### Viewer Profile

The persisted local configuration for the Viewer. It contains stable viewing
context such as region and selected streaming services, plus the reference to
the last completed calibration catalog. A separate draft in the same local
envelope owns resumable calibration progress.

The Viewer Profile is persisted. It is not itself the calculated model of the
Viewer's taste and must not grow into a container for every movie interaction.
After Milestone 7 migration it does not own Movie reactions; those live only in
Viewer Movie State.

### Taste Profile

A deterministic Domain interpretation derived from the Viewer's current Movie
reactions and the accepted Decision Engine rules. It contains the evidence and
affinities used for scoring; it is not independently authored by the Viewer.

The Taste Profile is derived, not persisted as a second source of truth. It may
be recalculated whenever its inputs or engine version change.

### Calibration response

One answer given for a movie presented during onboarding or recalibration:
`Love it`, `Like it`, `It was okay`, `Didn't like it`, `Haven't seen it`, or
`Don't know it`.

The first four are informative responses and become Movie reactions. `Haven't
seen it` and `Don't know it` are calibration progress and recognition evidence;
they do not remove later or historical Movie reactions.

### Movie reaction

The Viewer's current post-viewing evaluation of one movie: `Love it`, `Like
it`, `It was okay`, or `Didn't like it`.

A Movie reaction proves the movie is watched. Only one current Movie reaction
may exist per TMDB movie ID. Changing a reaction replaces the previous one;
removing it removes its Taste evidence but does not make the movie unwatched.

### Viewer Movie State

The single current Domain aggregate for the Viewer's explicit state about one
TMDB movie. It represents separately:

- Watch state;
- an optional Movie reaction or `Not interested` preference;
- an optional Watchlist intent;
- enough metadata to identify and present the movie without an immediate
  network request.

Its invariants prevent contradictory states. It is not part of the Viewer
Profile aggregate.

### Viewer State snapshot identity

An opaque, persisted and non-reusable identity for the complete current Viewer
Profile inputs and Viewer Movie State used by recommendations. It is an equality
token, not a user-visible version number or an ordering counter.

Recommendation work captures this identity and may persist or publish only
while it still matches the active snapshot. A state-changing commit, legacy
migration, or recovery publication receives a fresh identity; restoring an
older copy never makes its former identity active again.

### Watch state

The factual local state of whether the Viewer has watched a movie. It is
independent from Watchlist intent and can be changed from any Movie Detail.

A Movie reaction implies watched. Removing a Movie reaction does not remove the
watched fact. Marking a movie unwatched removes an existing Movie reaction.

### Watchlist intent

The Viewer's current intent to watch an unwatched movie in the future.
Watchlist is not viewing history and does not support explicit rewatch intent in
the first version.

Setting watched, a Movie reaction, or `Not interested` removes Watchlist
intent. Removing Watchlist intent never changes Watch state or Movie reaction.

### Not interested

A stable title-level rejection for a movie the Viewer has not watched. It
excludes that TMDB movie ID from recommendations but does not become `Didn't
like it` and does not penalize its genres or era.

`Not interested` and a Movie reaction are mutually exclusive. It is not offered
for a watched movie. Saving the movie to Watchlist clears `Not interested`.

### Taste evidence

Validated information the Decision Engine may use to derive a Taste Profile or
explain a recommendation. In P1 this comes from current Movie reactions and
accepted movie metadata. Passive impressions, detail opens, trailer plays, and
`Not interested` are not Taste evidence.

## Calibration

### Calibration Catalog

An ordered, versioned collection of recognizable movies used by onboarding and
recalibration. Each entry has a TMDB movie ID and sufficient fallback metadata.

A calibration flow freezes one exact catalog snapshot. A newer remote version
may be used only by a later flow. Cached and bundled catalogs are valid fallback
sources when the remote document cannot be used.

## Recommendation inputs and gates

### Candidate

A movie admitted to the bounded recommendation recall pool. Candidate status
does not mean the movie is watchable, credible, or selected.

### Eligibility

The complete set of non-negotiable gates a Candidate must pass before it may
continue toward a Decision Set. In the pilot this includes Watch state, `Not
interested`, Recommendation-cycle history, and verified selected-provider
availability.

Eligibility is separate from score. A high score cannot override a failed or
unknown eligibility gate. Credibility is a separate post-scoring admission
rule, not part of Eligibility.

### Availability evidence

The movie-level, region-specific provider response and verification time used
to determine whether a movie is included with at least one selected service.
Missing, invalid, failed, or unverifiable evidence remains `unknown`; it is not
silently converted to unavailable.

### Affinity

A signed, confidence-adjusted P1 value derived from Movie reactions for an
accepted feature such as genre or release decade. Affinity is a component of
the Taste Profile, not a direct user rating and not a permanent genre ban.

### Similarity

The continuous P1 movie-to-movie metadata signal used as one component of
scoring. It combines accepted genre overlap and broad release-era evidence and
may be non-zero even when the relationship is too weak to name to the Viewer.

Scoring similarity does not itself authorize a visible explanation. For
example, Deadpool may contribute `0.36` similarity to Parasite while remaining
below the positive-anchor explanation threshold.

### Positive anchor

A `Love it` or `Like it` movie that provides strong, explainable similarity to
a Candidate.

For the accepted P1 explanation policy, an anchor must share at least one genre
and have genre Jaccard similarity of at least `1/3`. Release era may reinforce
the explanation but can never qualify the anchor by itself. `It was okay` is
never a positive anchor. A positively rated movie can therefore contribute to
scoring similarity without qualifying as a Positive anchor that Presentation
may name.

### Quality confidence

The P1 component derived from TMDB vote average and vote evidence. It is a
bounded ranking signal, especially useful while Taste evidence is sparse. It is
not a claim that the Viewer will like the movie.

### Score

The deterministic P1 ranking index computed from accepted affinity,
similarity, quality, and Watchlist-intent inputs. It is not a probability,
rating, eligibility decision, or user-visible confidence percentage.

### Credibility

The post-scoring admission rule that decides whether an otherwise eligible
Candidate has enough accepted support to participate in role selection. It is
evaluated separately from Eligibility and after P1 scoring. Diversity cannot
make a below-threshold Candidate credible.

## Recommendation output and lifecycle

### Decision Set

The persisted ordered result of zero to three recommendations, with at most one
Safe, Stretch, and Discovery role. A smaller or empty honest set is valid when
the engine cannot support all three roles.

### Recommendation cycle

The sequence of Decision Sets produced under one deterministic cycle identity.
It records every movie already shown so refresh or repair cannot repeat it.

In Milestone 7, a Movie-reaction change creates a new identity because Taste
evidence changed, while inheriting all IDs already shown by the preceding cycle.
Watch state, Watchlist intent, and `Not interested` change mutable eligibility
and repair the current cycle without erasing its history.

### Safe, Stretch, and Discovery

The three product roles used to compose a deliberate Decision Set:

- **Safe**: the highest-confidence credible option;
- **Stretch**: a credible option that provides a meaningful alternative;
- **Discovery**: a less obvious but still credible and supported direction.

The role describes set composition. It never replaces the evidence-backed
reason that a recommendation fits.

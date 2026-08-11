# Decision Engine v1 — Product Fixtures

**Status:** Accepted supporting evidence — P1 selected by ADR-011
**Purpose:** Preserve the observable product constraints used to select the
canonical Milestone 6 model. ADR-011 owns the final P1 constants and rules.

---

# 1. Why fixtures come before weights

Decision Engine v1 must not choose scoring weights because they appear mathematically reasonable.

Weights are implementation parameters.

The product requirement is observable behaviour.

Fixtures therefore define:

- known viewer evidence;
- known candidate metadata;
- eligibility state;
- expected relative behaviour;
- unacceptable outcomes.

A scoring model is acceptable only when it satisfies the representative fixtures without introducing unreasonable behaviour elsewhere.

---

# 2. Fixture conventions

Synthetic fixtures use controlled metadata rather than live TMDB responses.

This makes tests:

- deterministic;
- reproducible;
- independent from catalogue changes;
- easier to reason about.

Real-movie sanity checks may be added separately to evaluate whether the resulting recommendations feel credible to humans.

They must not replace deterministic automated fixtures.

---

# 3. Current accepted Decision Engine behaviour

The following decisions are considered accepted inputs to these fixtures.

## Taste evidence

Primary signal:

- genre affinity.

Secondary signal:

- broad era affinity.

Supplementary signals:

- similarity to positively rated movies;
- general quality confidence.

## Reaction semantics

Relative meaning:

```text
Love it        → strong positive
Like it        → positive
It was okay    → neutral
Didn't like it → negative
Haven't seen   → no taste evidence
Don't know it  → no taste evidence
```

The fixtures originally treated numeric weights as experimental. ADR-011 now
accepts the P1 values; those canonical values govern implementation.

## Watch history

Exclude:

- movies seen through informative calibration reactions;
- Watchlist movies marked watched.

## Watchlist intent

A saved but unwatched Watchlist movie:

- remains eligible;
- receives a small positive decision-intent bonus;
- does not modify the stable Taste Profile.

## Runtime

Runtime is informational in M6.

It does not influence the default ranking.

## Recent movies

Recent movies receive no special ranking treatment in M6.

Low vote evidence:

- provides less general-quality confidence;
- never creates a negative score merely because the movie is new.

## Availability

Only verified `eligible` movies can enter the final Decision Set.

`unknown` fails closed.

## Diversity

The final set optimizes both relevance and diversity.

The three highest raw scores do not automatically become the final set.

## Refresh

`Give me three more` temporarily excludes movies already shown during the current recommendation cycle.

---

# 4. Fixture A — Strong genre preference

## Viewer evidence

Calibration:

| Movie | Genres | Era | Reaction |
|---|---|---|---|
| A1 | Science Fiction, Drama | 2010s | Love it |
| A2 | Science Fiction, Adventure | 2010s | Love it |
| A3 | Crime, Drama | 2000s | Like it |
| A4 | Comedy | 2010s | Didn't like it |
| A5 | Romance, Comedy | 2000s | Didn't like it |
| A6 | Action | 2020s | It was okay |
| A7 | Drama | 2020s | Like it |
| A8 | Horror | 2010s | Don't know it |

Expected Taste Profile:

```text
Science Fiction → strong positive
Drama           → positive
Adventure       → positive
Crime           → weak/moderate positive

Comedy          → repeated negative evidence
Romance         → weak negative evidence

2010s           → positive era evidence
2000s           → mixed/weak
2020s           → weak positive/neutral
```

## Candidates

| Candidate | Genres | Era | Quality | Availability |
|---|---|---|---|---|
| C1 | Science Fiction, Drama | 2010s | high | eligible |
| C2 | Science Fiction, Adventure | 2020s | high | eligible |
| C3 | Crime, Thriller, Drama | 2010s | high | eligible |
| C4 | Comedy, Romance | 2010s | very high | eligible |
| C5 | Science Fiction, Drama | 2010s | medium | eligible |

## Expected behaviour

C1 should rank very strongly.

C2 should rank strongly.

C3 should remain competitive because it matches positive Drama/Crime evidence.

C4 must not become a top recommendation merely because its general quality is extremely high.

C5 may rank below C1 because both fit taste similarly but C1 has stronger quality confidence.

## Invalid outcome

```text
C4
C1
C2
```

This would indicate that general quality is overpowering personalization.

---

# 5. Fixture B — Sparse profile

## Viewer evidence

Only two informative reactions:

| Movie | Genres | Reaction |
|---|---|---|
| B1 | Thriller, Drama | Love it |
| B2 | Comedy | Didn't like it |

Confidence:

```text
Low
```

## Candidates

| Candidate | Genres | Quality | Availability |
|---|---|---|---|
| C1 | Thriller, Drama | high | eligible |
| C2 | Adventure, Drama | very high | eligible |
| C3 | Science Fiction | very high | eligible |
| C4 | Comedy | high | eligible |
| C5 | Crime, Thriller | medium | eligible |

## Expected behaviour

C1 should benefit from the known positive evidence.

C2 and C3 remain credible because general-quality confidence carries greater influence under sparse evidence.

C4 should not be permanently rejected simply because one Comedy movie was disliked.

The engine must not behave as though it fully understands the viewer after two reactions.

## Invalid outcome

Only Thriller/Drama candidates are returned.

This would indicate overfitting.

---

# 6. Fixture C — Negative evidence must not overgeneralize

## Viewer evidence

| Movie | Genres | Reaction |
|---|---|---|
| N1 | Science Fiction, Horror | Didn't like it |
| N2 | Science Fiction, Drama | Love it |
| N3 | Science Fiction, Adventure | Love it |
| N4 | Drama | Like it |

## Expected Taste Profile

Science Fiction must remain positive overall.

The disliked movie may weaken Science Fiction confidence slightly.

It must not turn Science Fiction into a negative preference.

Horror may receive negative evidence because it has no balancing positive support.

## Candidates

| Candidate | Genres | Quality |
|---|---|---|
| C1 | Science Fiction, Drama | high |
| C2 | Science Fiction, Adventure | high |
| C3 | Horror | very high |
| C4 | Drama | high |

## Expected behaviour

C1 and C2 should remain strong candidates.

## Invalid outcome

Science Fiction candidates are suppressed because of N1.

---

# 7. Fixture D — Availability beats score

## Viewer evidence

Strong affinity for:

```text
Crime
Thriller
Drama
```

## Raw ranking before availability

```text
C1 → 94
C2 → 89
C3 → 84
C4 → 80
```

Availability:

```text
C1 → ineligible
C2 → unknown
C3 → eligible
C4 → eligible
```

## Expected final eligible ranking

```text
C3
C4
```

The product returns two recommendations.

## Invalid outcomes

Returning C1 because it has the best score.

Returning C2 because availability might eventually resolve.

Adding a weak unrelated C5 purely to reach three.

---

# 8. Fixture E — Watched exclusion

## Viewer evidence

C1 would otherwise be the strongest recommendation.

State:

```text
C1 → calibration reaction: Love it
C2 → Watchlist: watched
C3 → Watchlist: saved, not watched
```

## Expected behaviour

C1 is excluded.

C2 is excluded.

C3 remains eligible and receives the accepted small Watchlist-intent bonus.

## Invalid outcomes

Recommending C1 because the engine interprets `Love it` only as preference evidence.

Recommending C2 because Watchlist and calibration use separate storage.

---

# 9. Fixture F — Watchlist intent

Candidates before Watchlist intent:

```text
C1 → taste relevance 82
C2 → taste relevance 80
```

C2 is saved in Watchlist and unwatched.

## Expected behaviour

A small Watchlist bonus may allow C2 to overtake C1 when they are already close.

It must not allow a substantially worse candidate to dominate.

For example:

```text
C1 → relevance 90
C2 → relevance 55 + Watchlist
```

C1 must remain ahead.

## Product principle

Watchlist means:

> I have expressed interest in watching this.

It does not mean:

> This represents my stable taste.

---

# 10. Fixture G — New movie with little vote evidence

Candidates:

```text
C1
genre fit: excellent
era fit: excellent
vote average: high
vote count: low
recent release

C2
genre fit: good
era fit: good
vote average: high
vote count: very high
established release
```

## Expected behaviour

C1 must not receive a recency or low-vote penalty.

C2 may receive more general-quality confidence.

Either candidate may win depending on the remaining preference evidence.

## Invalid outcome

C1 becomes effectively impossible to recommend solely because it has few votes.

---

# 11. Fixture H — Diversity

Viewer strongly likes:

```text
Science Fiction
Drama
Adventure
```

Raw ranking:

```text
C1 — Science Fiction, Drama       93
C2 — Science Fiction, Drama       91
C3 — Science Fiction, Adventure   89
C4 — Crime, Drama                 86
C5 — Mystery, Drama               84
```

Naive top three:

```text
C1
C2
C3
```

## Expected behaviour

The diversification phase should consider replacing one of the highly overlapping candidates with C4 or C5.

A required P1 regression result:

```text
C1
C3
C4
```

The accepted P1 diversification algorithm produces this exact selection.

## Constraint

Diversity must not cause a major relevance collapse.

If the diverse alternative scores dramatically below the third candidate, the engine should preserve relevance.

The previously open diversity parameter is resolved by ADR-011's ten-point
maximum-overlap penalty.

---

# 12. Fixture I — Refresh history

Initial Decision Set:

```text
C1
C2
C3
```

User requests:

> Give me three more

Remaining high-ranking candidates:

```text
C4
C5
C6
C7
```

## Expected behaviour

The next set must not contain:

```text
C1
C2
C3
```

unless the current recommendation cycle has been intentionally reset.

Expected second set:

```text
C4
C5
C6
```

subject to eligibility and diversity.

---

# 13. Fixture J — Quality must not become popularity

Viewer profile strongly supports:

```text
Horror
Mystery
```

Candidates:

```text
C1
Horror, Mystery
good rating
moderate vote evidence

C2
Action, Adventure
excellent rating
massive vote evidence

C3
Horror
good rating
strong vote evidence
```

## Expected behaviour

C1 and C3 should usually outrank C2.

C2's broad popularity is not enough to compensate for poor personal relevance.

## Invalid outcome

The engine degenerates into a "popular movies" ranking.

---

# 14. Fixture K — Neutral reactions

Viewer rates:

```text
Movie A → It was okay
```

Movie A genres:

```text
Fantasy
Adventure
```

## Expected behaviour

The movie becomes known watched content.

Its genres receive neither positive nor negative preference evidence.

## Invalid outcome

`It was okay` creates weak positive affinity.

---

# 15. Fixture L — Honest empty result

All otherwise credible candidates are:

```text
ineligible
unknown
watched
```

## Expected behaviour

Decision Engine returns an empty Decision Set.

Presentation must later provide an honest product state.

## Invalid outcome

Eligibility or watch-history rules are relaxed silently to avoid an empty screen.

---

# 16. Historical boundary of the fixture phase

Before P1 was selected, these fixtures deliberately did not fix:

- reaction numeric weights;
- normalized genre formula;
- quality-confidence function;
- candidate score percentages;
- Watchlist bonus magnitude;
- diversity threshold;
- candidate-pool size beyond the accepted broad target;
- candidate-generation sorting/filter values;
- explanation templates;
- Decision Set roles;
- persistence/freshness policy.

Those values were subsequently selected by the scoring prototype and accepted
in ADR-011. This section records the validation sequence; it is not an open
implementation decision.

---

# 17. Completed validation sequence

The fixture pack was followed by the accepted **Real Movie Sanity Check v1**
and P1 scoring prototype.

Use a realistic calibration profile and a fixed set of real candidate movies.

For each candidate, inspect:

- genre;
- era;
- rating;
- vote evidence;
- watch state;
- availability fixture.

Then answer manually:

1. Which candidates should clearly rise?
2. Which should clearly fall?
3. Which three would constitute a credible Decision Set?
4. Where should diversity modify raw ranking?
5. Would the recommendation reasons feel honest?

That exercise is complete. ADR-011 is the canonical implementation contract.

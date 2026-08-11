# Decision Engine v1 — Scoring Prototype

**Status:** Accepted P1 for Milestone 6 — subject to the post-M6 household utility checkpoint
**Input authority:** Accepted *Decision Engine v1 — Product Fixtures* and *Real Movie Sanity Check v1*
**Purpose:** Define and evaluate the simplest deterministic scoring formula that satisfies the accepted observable behaviour.

---

# 1. Prototype principles

P0 is intentionally mechanical and explainable.

It uses only:

- genre affinity;
- broad era affinity;
- metadata similarity to positively rated movies;
- general quality confidence;
- the accepted small Watchlist intent bonus.

It does not use:

- runtime for ranking;
- cast, director, keywords, production company, country, or original language;
- mood, pacing, style, themes, or narrative interpretation;
- an LLM or embeddings;
- explicit hard-content exclusions that the current profile cannot represent.

Availability, watch history, and current-cycle history remain eligibility gates. They are applied outside the score.

---

# 2. Reaction values

P0 uses the following experimental values:

| Reaction | Value | Meaning |
|---|---:|---|
| Love it | `+1.00` | strong positive evidence |
| Like it | `+0.50` | positive evidence |
| It was okay | `0.00` | no directional evidence; watched |
| Didn't like it | `-0.75` | negative evidence |
| Haven't seen | excluded | no taste evidence; not watched |
| Don't know it | excluded | no taste evidence; not watched |

`Didn't like it` is stronger than `Like it` but weaker than `Love it`. This preserves the accepted asymmetry without allowing one negative reaction to create a permanent genre ban.

These began as prototype constants and are now the canonical P1 Milestone 6
inputs through ADR-011. They remain revisable only through an explicitly
reviewed later model version.

---

# 3. Feature affinity

For every genre and decade represented in watched calibration evidence:

```text
rawMean = sum(reactionValue) / observationCount

evidenceConfidence = observationCount / (observationCount + 2)

affinity = rawMean × evidenceConfidence
```

The result is bounded conceptually within:

```text
-1.0 → strong negative affinity
 0.0 → unknown, neutral, or balanced evidence
+1.0 → strong positive affinity
```

The `+2` prior shrinks sparse observations toward neutral.

Neutral reactions are included as observations with value `0`. They never create positive or negative affinity, but repeated neutral evidence can moderate an otherwise sparse conclusion.

For scoring, signed affinity is normalized to `[0, 1]`:

```text
normalizedAffinity = (affinity + 1) / 2
```

## Candidate genre component

```text
genreComponent = average(
    normalized affinity of every candidate genre
)
```

All candidate genres participate. A negative genre can moderate positive matches but never acts as an automatic exclusion.

## Candidate era component

```text
eraComponent = normalized affinity of candidate release decade
```

An unseen decade is neutral, not negative.

---

# 4. Profile confidence and adaptive weights

Profile confidence uses only directional reactions:

```text
directionalCount = Love it + Like it + Didn't like it reactions

profileConfidence = directionalCount / (directionalCount + 6)
```

Neutral reactions contribute watch history but do not make the engine believe it understands the viewer's taste better.

Quality receives more influence under sparse evidence:

```text
qualityWeight = 0.35 - (0.20 × profileConfidence)

personalWeight = 1 - qualityWeight
```

The personal weight is divided as follows:

```text
genreWeight     = personalWeight × 0.65
eraWeight       = personalWeight × 0.10
similarityWeight = personalWeight × 0.25
```

Observed P0 weights:

| Profile | Confidence | Genre | Era | Similarity | Quality |
|---|---:|---:|---:|---:|---:|
| Original onboarding | 0.571 | 49.68% | 7.64% | 19.11% | 23.57% |
| Augmented profile | 0.714 | 51.54% | 7.93% | 19.82% | 20.71% |

This preserves genre as the primary signal and reduces quality influence as profile confidence grows.

---

# 5. Positive-movie similarity

P0 compares a candidate with every `Love it` and `Like it` movie.

For each positive anchor:

```text
genreOverlap = Jaccard(candidateGenres, anchorGenres)

eraSimilarity =
    1.0 when both movies share a decade
    0.5 when their decades are adjacent
    0.0 otherwise

metadataSimilarity =
    genreOverlap × 0.80
    + eraSimilarity × 0.20
```

Anchor strength:

```text
Love it → 1.00
Like it → 0.75
```

Candidate similarity is the strongest supported positive-anchor match:

```text
similarityComponent = max(
    metadataSimilarity × anchorStrength
)
```

This is intentionally narrow. It cannot infer that two movies share a director, theme, tone, or narrative structure.

---

# 6. General quality confidence

P0 first normalizes TMDB rating:

```text
ratingComponent = clamp(
    (voteAverage - 5.0) / 3.5,
    0,
    1
)
```

Vote evidence uses a logarithmic curve capped at approximately 20,000 votes:

```text
voteEvidence = clamp(
    log(1 + voteCount) / log(1 + 20,000),
    0,
    1
)
```

Final quality confidence:

```text
qualityComponent =
    ratingComponent
    × (0.65 + 0.35 × voteEvidence)
```

The `0.65` floor is important. A recent movie with few votes can still receive most of its rating-based quality bonus. Greater vote evidence adds confidence; low evidence never creates a negative score.

---

# 7. Candidate score

```text
candidateScore = 100 × (
    genreComponent     × genreWeight
    + eraComponent     × eraWeight
    + similarityComponent × similarityWeight
    + qualityComponent × qualityWeight
)
```

The result is a ranking index, not a probability and not a prediction that the viewer will like the movie.

## Watchlist intent

A saved, unwatched candidate receives:

```text
+2.0 points
```

The bonus is applied after the base score and capped at `100`.

This allows Watchlist intent to break a close result without rescuing a substantially weaker candidate.

---

# 8. Eligibility order

P0 assumes this order:

```text
Generate candidates
↓
Exclude known watched movies
↓
Exclude current-cycle history
↓
Score candidates
↓
Verify availability
↓
Remove ineligible and unknown availability
↓
Diversify eligible ranking
↓
Return up to three
```

Scoring never overrides watch or availability exclusions.

---

# 9. Diversity P0

P0 applies a greedy diversity adjustment after raw ranking.

The highest raw score is selected first.

For every remaining slot:

```text
selectionScore = rawScore
    - 10 × maximum genre Jaccard overlap
      with any already selected movie
```

The candidate with the highest `selectionScore` is selected next. Raw scores remain unchanged and are retained for explanations and diagnostics.

Interpretation:

- an identical genre set may absorb a penalty of `10` points;
- a candidate five points lower can replace a near-duplicate;
- a candidate dramatically lower cannot be rescued by diversity alone.

Accepted Fixture H result:

```text
Raw:
C1 93 — Science Fiction, Drama
C2 91 — Science Fiction, Drama
C3 89 — Science Fiction, Adventure
C4 86 — Crime, Drama

Diversified:
C1
C3
C4
```

---

# 10. Synthetic fixture results

The P0 scoring checks pass the currently formula-relevant synthetic fixtures.

| Fixture | Observed result | Assessment |
|---|---|---|
| A — Strong genre preference | C1 `81.41`, C2 `76.67`, C5 `71.55`, C3 `63.61`, C4 `50.20` | personalization defeats very-high-quality Comedy/Romance; C3 remains above C4 |
| B — Sparse profile | C1 `76.80`, C2 `66.46`, C3 `58.00`, C5 `53.76`, C4 `47.56` | known fit wins while high-quality alternatives remain credible |
| C — Negative evidence | C1 `73.94`, C2 `73.44`, C4 `71.32`, C3 `50.27` | one disliked Science Fiction movie does not suppress the genre |
| G — Recent movie | established `75.76`, recent/low-vote `71.25` | low evidence gives less bonus but creates no effective exclusion |
| H — Diversity | C1, C3, C4 | accepted diversified result |
| J — Quality versus popularity | personalized C1/C3 outrank acclaimed unrelated C2 | quality does not become popularity |

The remaining synthetic behaviours are eligibility or state-transition rules rather than scoring-formula outcomes:

- availability fails closed;
- known watched movies are excluded;
- saved/unwatched Watchlist movies remain eligible;
- neutral reactions add no directional affinity;
- refresh history excludes already shown candidates;
- an honest empty set remains valid.

---

# 11. Original-profile result

This pass uses only the supplied onboarding calibration. It deliberately does not know the later catalog reactions.

## Raw top ten

| Rank | Candidate | Score | Later-known truth |
|---:|---|---:|---|
| 1 | The Martian | 66.89 | watched; Like it |
| 2 | The Grand Budapest Hotel | 65.58 | watched; Didn't like it |
| 3 | Whiplash | 65.24 | unseen |
| 4 | Gone Girl | 63.49 | watched; Like it |
| 5 | Hereditary | 62.29 | watched; Like it |
| 6 | Prisoners | 61.71 | unseen |
| 7 | The Handmaiden | 60.85 | unseen; Romance is undesirable |
| 8 | Blade Runner 2049 | 60.38 | unseen |
| 9 | Us | 59.97 | unseen; viewer would watch it |
| 10 | Arrival | 59.77 | uncertain memory; possible dislike |

## Diversified Decision Set

```text
The Martian
Whiplash
The Grand Budapest Hotel
```

## Interpretation

This pass produces two useful findings:

1. `The Martian` ranking first validates the strongest positive-fit prediction.
2. `The Grand Budapest Hotel` ranking highly demonstrates the unavoidable limitation of incomplete watch history and coarse metadata. Comedy, Drama, the 2010s, high quality, and metadata overlap with `Parasite` make it algorithmically plausible even though the viewer disliked it.

P0 cannot fix the second finding honestly without the later catalog reaction.

`Knives Out` ranks 15th at `57.29`. This does not violate eligibility, but it conflicts with the earlier working hypothesis that it should be a serious top-set candidate. Product validation must decide whether that hypothesis was too strong or whether P0 undervalues distributed genre evidence.

---

# 12. Augmented-profile result

This pass includes all newly confirmed catalog reactions and excludes every known watched candidate.

## Raw top ten without Watchlist intent

| Rank | Candidate | Score |
|---:|---|---:|
| 1 | Anatomy of a Fall | 64.98 |
| 2 | Whiplash | 64.85 |
| 3 | Us | 63.85 |
| 4 | Prisoners | 62.68 |
| 5 | Arrival | 61.95 |
| 6 | Blade Runner 2049 | 61.92 |
| 7 | Nope | 61.75 |
| 8 | The Prestige | 61.32 |
| 9 | The Handmaiden | 60.66 |
| 10 | Nightcrawler | 60.30 |

Additional boundary results:

```text
Knives Out   → rank 12, score 58.18
La La Land   → rank 13, score 58.03
Oppenheimer  → rank 15, score 53.44
The Godfather → rank 17, score 52.96
```

Diversified Decision Set:

```text
Anatomy of a Fall
Whiplash
Arrival
```

`Arrival` is algorithmically explainable but remains a known false-positive risk because the viewer's memory is uncertain.

## With `Us` represented as Watchlist intent

The accepted `+2` intent bonus changes the raw top three to:

```text
Us               65.85
Anatomy of a Fall 64.98
Whiplash          64.85
```

Diversified Decision Set:

```text
Us
Whiplash
Anatomy of a Fall
```

This demonstrates the intended bonus behaviour: `Us` was already close and moves to first. A weak candidate would not receive enough help to dominate.

---

# 13. What P0 gets right

- It passes the formula-relevant synthetic checks.
- Genre remains the primary signal.
- Quality matters more when evidence is sparse.
- Low vote evidence never creates a new-release penalty.
- Strong quality does not make `The Godfather` a top result.
- Known watched movies disappear correctly from the augmented pass.
- `It was okay` excludes `The Substance` without changing taste direction.
- The Watchlist bonus changes a close decision without overpowering relevance.
- Diversity replaces near-duplicates without rescuing dramatically weaker movies.

---

# 14. What P0 exposes

## Missing history cannot be solved by scoring

The original result contains movies later confirmed as watched. This is an evidence-ingestion problem, already assigned to a later milestone, not a reason to distort the formula.

## Coarse metadata creates legitimate false positives

`The Grand Budapest Hotel`, `Arrival`, and `La La Land` demonstrate different forms of missing evidence. P0 must not invent themes, musical classification, or remembered reactions.

## Strongest-anchor similarity may overfit one movie

P0 takes the maximum positive-anchor similarity. This helps `The Martian`, but may over-reward a single coarse match and under-reward candidates such as `Knives Out` that weakly match several positive anchors.

A later P1 experiment may compare:

```text
max positive-anchor similarity
versus
weighted average of the two strongest positive anchors
```

The alternative should be accepted only if it improves human behaviour without breaking the synthetic fixtures.

## A ranking score is not certainty

The numerical gap between many real candidates is small. P0 should not generate confident language such as “perfect for you.”

---

# 15. Product validation questions

1. Does `Us + Whiplash + Anatomy of a Fall` feel like a credible set when `Us` carries Watchlist intent?
2. Would `Whiplash` be an acceptable recommendation despite the viewer's rejection of musicals, given that it is a drama about music rather than a traditional musical?
3. Between `Anatomy of a Fall`, `Knives Out`, and `Oppenheimer`, which would the viewer most want PickOne to place highest?
4. Does `Knives Out` at rank 12 feel clearly too low, or was its earlier presence in the proposed set merely plausible rather than required?
5. Should `Arrival` remain eligible under uncertain memory, accepting the possible false positive, or should the product later support an explicit `Not sure / Hide this` decision state?

---

# 16. Acceptance rule

P0 may become the first accepted scoring model only if:

- the real Decision Set is judged credible;
- any requested adjustment can be expressed using observable v1 evidence;
- the adjustment does not repair a single movie by adding hidden exceptions;
- the synthetic fixtures continue to pass;
- the formula remains explainable enough to generate honest reasons.

If the real set is not credible, P1 should change one concept at a time and compare results against P0.

---

# 17. P0 product-review result

P0 is not accepted as the final scoring model.

The viewer reported:

```text
Whiplash          → would not watch it because the subject is music
Anatomy of a Fall → could not be evaluated without knowing its premise
Oppenheimer       → tentative preference among the proposed alternatives
Knives Out        → no ranking expectation without having seen it
Arrival           → keep eligible despite uncertain memory
```

## Key diagnosis

The `Whiplash` result is not merely a quality-weight problem.

TMDB classifies it as:

```text
Drama
Music
Thriller
```

The viewer's strongest learned genre is Thriller, but their intended meaning is closer to mysteries and thrillers with unexpected turns. TMDB's broad `Thriller` label does not encode that distinction.

P0 also allows one positive genre plus very strong general quality to compete with movies that match several positive genres simultaneously.

The viewer's preference for unexpected turns is not observable through the accepted v1 metadata. P1 must not claim to understand it or introduce a hidden `Whiplash` exception.

## Accepted Arrival behaviour

`Arrival` remains eligible. Uncertain memory creates neither watched state nor negative taste evidence.

## Oppenheimer boundary

The tentative preference for `Oppenheimer` is retained as a product observation, not a required rank. With accepted v1 metadata, its support is limited to:

- strong general quality confidence;
- positive 2020s evidence;
- highly mixed Drama affinity;
- no learned History affinity.

Forcing it upward would also strengthen other high-quality, weak-fit candidates. P1 must not add an unexplained title-specific bonus.

---

# 18. P1 — Positive genre coverage

P1 changes exactly one concept.

P0 genre component:

```text
genreComponent = normalized mean candidate-genre affinity
```

P1 genre component:

```text
positiveGenreCoverage =
    candidate genres with affinity > 0.05
    / candidate genre count

genreComponent =
    normalizedMeanAffinity × 0.80
    + positiveGenreCoverage × 0.20
```

All other reaction values, confidence functions, component weights, quality logic, Watchlist bonus, eligibility rules, and diversity logic remain unchanged.

## Product rationale

P1 rewards a candidate supported by several positive genre signals rather than allowing one broad match to carry the entire genre component.

It does not ban movies containing unknown or negative genres. Their average affinity still contributes 80% of the component.

The `0.05` threshold and `20%` coverage share are experimental constants. The coverage share was kept deliberately modest because larger values caused the original onboarding pass to underweight the very strong identity match between `The Martian` and `Interstellar`.

---

# 19. P1 verification

P1 continues to pass the formula-relevant synthetic fixtures:

| Fixture | P1 observed result | Assessment |
|---|---|---|
| A — Strong genre preference | C1 `84.09`, C2 `79.51`, C5 `74.24`, C3 `64.32`, C4 `46.84` | pass |
| B — Sparse profile | C1 `79.84`, C2 `65.70`, C3 `53.45`, C5 `53.00`, C4 `44.15` | pass |
| C — Negative evidence | C1 `77.20`, C2 `76.81`, C4 `74.28`, C3 `46.71` | pass |
| G — Recent movie | established `78.70`, recent/low-vote `74.19` | pass |
| H — Diversity | C1, C3, C4 | pass |
| J — Quality versus popularity | personalized C1/C3 outrank unrelated C2 | pass |

---

# 20. P1 real-profile results

## Original onboarding snapshot

Raw top five:

```text
1. The Martian               65.25
2. The Grand Budapest Hotel  65.23
3. Gone Girl                 64.55
4. Hereditary                63.27
5. Whiplash                  63.27
```

Diversified set:

```text
The Martian
Hereditary
The Grand Budapest Hotel
```

Later-known truth:

- `The Martian` and `Hereditary` were both liked;
- `The Grand Budapest Hotel` was disliked;
- all three were already watched but absent from onboarding history.

Compared with P0, the set moves from one validated taste match to two. The remaining false positive is still caused by missing evidence and coarse metadata.

## Augmented profile

Raw ranking:

| Rank | Candidate | Score |
|---:|---|---:|
| 1 | Us | 67.56 |
| 2 | Nope | 65.72 |
| 3 | Anatomy of a Fall | 65.61 |
| 4 | Arrival | 62.89 |
| 5 | Whiplash | 62.64 |
| 6 | The Prestige | 62.26 |
| 7 | Blade Runner 2049 | 61.62 |
| 8 | Mad Max: Fury Road | 60.78 |
| 9 | Prisoners | 60.56 |
| 10 | Knives Out | 59.20 |
| 16 | Oppenheimer | 48.45 |
| 17 | The Godfather | 48.10 |

Diversified set:

```text
Us
Blade Runner 2049
Nope
```

When `Us` is represented as saved Watchlist intent, its score rises from `67.56` to `69.56`. The final set does not change because it already ranked first.

## Behavioural change from P0

```text
Whiplash:   rank 2 → rank 5; removed from final set
Us:         rank 3 → rank 1
Knives Out: rank 12 → rank 10
```

P1 improves the known false-positive behaviour without adding a title exception or breaking the synthetic constraints.

---

# 21. Anatomy of a Fall context

`Anatomy of a Fall` is a courtroom mystery about a writer whose husband dies in ambiguous circumstances. Investigators cannot establish suicide or homicide; she becomes the accused, and the trial examines both the death and the couple's relationship.

Its observable metadata is:

```text
Thriller
Mystery
Crime
2023
```

That combination explains its high raw rank under the augmented profile. The engine still cannot claim that it contains the unexpected turns the viewer prefers.

---

# 22. P1 product-validation questions

1. Does `Us + Blade Runner 2049 + Nope` feel like a credible default Decision Set?
2. Does the premise of `Anatomy of a Fall` sound like something the viewer would want to watch?
3. Is it acceptable for `Oppenheimer` to remain low when the current profile contains no observable preference for History, or does that reveal a missing future signal rather than a scoring error?

P1 should be accepted or rejected from these behaviours, not from whether every individual movie happens to be liked.

---

# 23. P1 acceptance

The Product Owner accepted P1 after reviewing the revised real-profile behaviour.

Accepted findings:

```text
Us + Blade Runner 2049 + Nope → credible default Decision Set
Anatomy of a Fall             → premise is appealing; high raw rank is credible
Oppenheimer                   → low P1 rank is accepted under current evidence
Arrival                       → remains eligible despite uncertain memory
```

P1 is the first accepted deterministic scoring model for Milestone 6.

Its constants are implementation inputs, not permanent product promises. The required household utility checkpoint after Milestone 6 may produce a later, explicitly reviewed model revision.

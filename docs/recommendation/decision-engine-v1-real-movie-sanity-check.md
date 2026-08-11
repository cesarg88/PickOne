# Decision Engine v1 — Real Movie Sanity Check

**Status:** Accepted supporting evidence — P1 selected
**Metadata snapshot:** 2026-08-11
**Region:** Not applied in this scoring experiment
**Purpose:** Preserve the real-profile validation used to choose the P1 scoring
constants now accepted by ADR-011.

---

# 1. What this experiment decides

This sanity check asks whether the evidence currently available to Decision Engine v1 can produce a credible ranking for one real viewer.

It does not yet decide:

- reaction numeric weights;
- component percentages;
- the quality-confidence function;
- the Watchlist bonus;
- the exact diversity threshold;
- production candidate-generation parameters;
- provider-specific availability.

All candidates in this experiment are treated as `eligible`. Availability behaviour remains covered by the accepted synthetic fixtures and can be tested separately once the viewer's supported services are supplied.

---

# 2. Normalization rules

The supplied calibration values are normalized as follows:

```text
Love it / love it                 → Love it
like it                           → Like it
It was Ok / it was Ok / it was ok → It was okay
Not for me                        → Didn't like it
Haven't seen it / haven't seen it → Haven't seen
```

`Gladiator` is recorded as a 2000 release because TMDB movie `98` has release date `2000-05-04`.

No other supplied identity required correction.

---

# 3. Normalized calibration profile

| TMDB ID | Movie | Year | TMDB genres | Normalized reaction | Taste evidence | Watch state |
|---:|---|---:|---|---|---|---|
| 157336 | Interstellar | 2014 | Adventure, Drama, Science Fiction | Love it | strong positive | watched |
| 238 | The Godfather | 1972 | Drama, Crime | Haven't seen | none | not watched |
| 11036 | The Notebook | 2004 | Romance, Drama | Didn't like it | negative | watched |
| 155 | The Dark Knight | 2008 | Action, Crime, Thriller | It was okay | neutral | watched |
| 1417 | Pan's Labyrinth | 2006 | Fantasy, Drama, War | Didn't like it | negative | watched |
| 18785 | The Hangover | 2009 | Comedy | It was okay | neutral | watched |
| 419430 | Get Out | 2017 | Mystery, Thriller, Horror | Like it | positive | watched |
| 496243 | Parasite | 2019 | Comedy, Thriller, Drama | Love it | strong positive | watched |
| 354912 | Coco | 2017 | Family, Animation, Music, Adventure | It was okay | neutral | watched |
| 546554 | Knives Out | 2019 | Comedy, Crime, Mystery | Haven't seen | none | not watched |
| 76341 | Mad Max: Fury Road | 2015 | Action, Adventure, Science Fiction | Haven't seen | none | not watched |
| 120 | The Lord of the Rings: The Fellowship of the Ring | 2001 | Adventure, Fantasy, Action | Didn't like it | negative | watched |
| 278 | The Shawshank Redemption | 1994 | Drama, Crime | Didn't like it | negative | watched |
| 98 | Gladiator | 2000 | Action, Drama, Adventure | It was okay | neutral | watched |
| 447332 | A Quiet Place | 2018 | Horror, Drama, Science Fiction | Didn't like it | negative | watched |

Profile evidence summary:

```text
15 calibration movies
12 known watched movies
 3 positive reactions
 4 neutral reactions
 5 negative reactions
 3 unseen movies
```

---

# 4. Observed Taste Profile hypothesis

This is an interpretation to validate, not a final stored profile or a scoring formula.

## Positive identity anchors

```text
Interstellar → strong positive
Parasite     → strong positive
Get Out      → positive
```

These identities may contribute to candidate similarity using only accepted v1 metadata. No narrative similarity, director, cast, keyword, or embedding evidence may be claimed.

## Negative identity anchors

```text
The Notebook
Pan's Labyrinth
The Lord of the Rings: The Fellowship of the Ring
The Shawshank Redemption
A Quiet Place
```

They provide negative evidence but must not create permanent genre bans.

## Genre evidence

| Genre | Positive observations | Neutral observations | Negative observations | Product interpretation |
|---|---:|---:|---:|---|
| Thriller | 2 | 1 | 0 | strongest positive genre evidence |
| Mystery | 1 | 0 | 0 | positive but sparse |
| Science Fiction | 1 | 0 | 1 | mixed; Interstellar prevents negative overgeneralization |
| Comedy | 1 | 1 | 0 | positive but broad and low-confidence |
| Adventure | 1 | 2 | 1 | mixed; weak/moderate positive at most |
| Drama | 2 | 1 | 4 | highly mixed; must not be treated as a simple preference |
| Horror | 1 | 0 | 1 | mixed; no reliable direction by itself |
| Action | 0 | 2 | 1 | neutral to weak negative |
| Crime | 0 | 1 | 1 | mixed to weak negative |
| Fantasy | 0 | 0 | 2 | clearest repeated negative genre evidence |
| Romance | 0 | 0 | 1 | negative but sparse |
| War | 0 | 0 | 1 | negative but sparse |
| Family | 0 | 1 | 0 | no directional evidence |
| Animation | 0 | 1 | 0 | no directional evidence |
| Music | 0 | 1 | 0 | no directional evidence |

The central test is whether the engine can preserve contradictory evidence. A model that converts `Drama`, `Science Fiction`, or `Horror` into a simple yes/no preference would misrepresent this viewer.

## Era evidence

| Era | Evidence | Interpretation |
|---|---|---|
| 2010s | 2 strong positive, 1 positive, 1 neutral, 1 negative | strongest positive era evidence |
| 2000s | 3 neutral, 3 negative | negative era evidence, but secondary to genre fit |
| 1990s | 1 negative | negative but too sparse for a broad conclusion |
| 1970s | unseen only | no taste evidence |
| 2020s | no calibration evidence | unknown, not negative |

## Confidence

Proposed overall confidence:

```text
Medium
```

There is enough evidence to personalize, but only three positive anchors and several contradictory genre observations. The engine should not behave as though the viewer's taste is fully understood.

---

# 5. Controlled candidate pool

Ratings and vote counts are a TMDB snapshot, not permanent fixture values. Automated tests should freeze the selected values rather than query live TMDB.

All candidates below are `eligible` for this scoring experiment.

| TMDB ID | Candidate | Year | Genres | Rating | Votes | Runtime |
|---:|---|---:|---|---:|---:|---:|
| 238 | The Godfather | 1972 | Drama, Crime | 8.686 | 23,315 | 175 |
| 546554 | Knives Out | 2019 | Comedy, Crime, Mystery | 7.840 | 14,290 | 131 |
| 76341 | Mad Max: Fury Road | 2015 | Action, Adventure, Science Fiction | 7.636 | 24,380 | 121 |
| 329865 | Arrival | 2016 | Drama, Science Fiction, Mystery | 7.631 | 19,661 | 116 |
| 286217 | The Martian | 2015 | Science Fiction, Drama, Adventure | 7.706 | 21,603 | 141 |
| 335984 | Blade Runner 2049 | 2017 | Science Fiction, Drama | 7.601 | 15,446 | 164 |
| 210577 | Gone Girl | 2014 | Mystery, Thriller, Drama | 7.890 | 20,213 | 149 |
| 146233 | Prisoners | 2013 | Drama, Thriller, Crime | 8.106 | 13,319 | 153 |
| 593643 | The Menu | 2022 | Comedy, Horror | 7.179 | 6,463 | 107 |
| 458723 | Us | 2019 | Horror, Mystery, Thriller | 6.943 | 8,201 | 116 |
| 762504 | Nope | 2022 | Horror, Science Fiction, Thriller | 6.825 | 5,058 | 130 |
| 570670 | The Invisible Man | 2020 | Thriller, Science Fiction, Horror | 7.089 | 6,378 | 124 |
| 242582 | Nightcrawler | 2014 | Crime, Drama, Thriller | 7.708 | 11,901 | 118 |
| 290098 | The Handmaiden | 2016 | Thriller, Drama, Romance | 8.180 | 4,422 | 145 |
| 497828 | Triangle of Sadness | 2022 | Comedy, Drama | 7.011 | 2,944 | 147 |
| 933260 | The Substance | 2024 | Horror, Science Fiction, Thriller | 7.133 | 6,285 | 141 |
| 915935 | Anatomy of a Fall | 2023 | Thriller, Mystery, Crime | 7.514 | 3,397 | 151 |
| 414906 | The Batman | 2022 | Crime, Mystery, Thriller | 7.700 | 12,281 | 177 |
| 244786 | Whiplash | 2014 | Drama, Music, Thriller | 8.375 | 16,898 | 107 |
| 313369 | La La Land | 2016 | Comedy, Drama, Romance | 7.900 | 18,316 | 129 |
| 120467 | The Grand Budapest Hotel | 2014 | Comedy, Drama | 8.025 | 16,339 | 100 |
| 493922 | Hereditary | 2018 | Horror, Mystery, Thriller | 7.293 | 8,774 | 128 |
| 1124 | The Prestige | 2006 | Drama, Mystery, Science Fiction | 8.211 | 17,895 | 130 |
| 872585 | Oppenheimer | 2023 | Drama, History | 8.023 | 12,201 | 181 |
| 110415 | Snowpiercer | 2013 | Action, Science Fiction, Drama | 6.906 | 10,552 | 127 |

---

## Candidate watch-state audit

### Newly confirmed watched reactions

| Candidate | Normalized reaction | Consequence |
|---|---|---|
| The Martian | Like it | exclude; add positive evidence |
| Gone Girl | Like it | exclude; add positive evidence |
| The Menu | Like it | exclude; add positive evidence |
| The Invisible Man | Like it | exclude; add positive evidence |
| The Batman | Like it | exclude; add positive evidence |
| The Grand Budapest Hotel | Didn't like it | exclude; add negative evidence |
| The Substance | It was okay | exclude; add no directional taste evidence |
| Hereditary | Like it | exclude; add positive evidence |

### Confirmed unseen and eligible

```text
Knives Out
Mad Max: Fury Road
Blade Runner 2049
Prisoners
Us
Nope
Nightcrawler
The Handmaiden
Whiplash
The Prestige
Oppenheimer
Snowpiercer
Triangle of Sadness
Anatomy of a Fall
```

Additional intent evidence:

```text
Us → viewer would watch it
```

This is decision intent, not stable taste evidence. It may receive the accepted small Watchlist bonus only if that intent is represented by an actual saved Watchlist state.

### Confirmed unseen but explicitly rejected

```text
La La Land    → viewer does not watch musicals and will not watch it
The Godfather → viewer rejects it because it feels too old
```

Neither case is a watched negative reaction. They must not silently modify genre affinity as though the viewer had seen and disliked the movie.

`La La Land` exposes a hard v1 observability gap: the accepted TMDB metadata snapshot does not identify it as `Music`, so the engine cannot reliably enforce the viewer's no-musicals rule with the accepted six signals.

### Intentionally uncertain

```text
Arrival → may have been watched and disliked; memory uncertain
```

Uncertain memory must not become stable positive or negative taste evidence.

---

## Augmented Taste Profile hypothesis

The newly confirmed reactions materially strengthen the profile:

| Signal | Augmented interpretation |
|---|---|
| Thriller | very strong positive evidence |
| Mystery | strong positive evidence |
| Science Fiction | positive evidence with one important negative counterexample |
| Horror | strong positive evidence; `A Quiet Place` must not overgeneralize |
| Comedy | positive but mixed evidence |
| Crime | positive/mixed evidence |
| Adventure | positive/mixed evidence |
| Drama | remains highly mixed despite additional positive anchors |
| 2010s | very strong positive era evidence |
| 2020s | strong positive era evidence from three liked movies; one neutral watched movie adds no direction |
| 2000s | remains negative/mixed |

The augmented profile is substantially more confident than the onboarding-only profile. Its exact confidence label remains dependent on the future confidence function.

---

# 6. Product-reviewed human expectations

These expectations are deliberately relative. They constrain the future scoring model without pretending that an exact ranking has already been accepted.

## A. Confirmed taste matches that expose incomplete watch history

### The Martian

The viewer has seen it and assigned the canonical reaction `Like it`. Its predicted strong affinity validates the use of metadata similarity to `Interstellar`.

It must be excluded once the newly supplied watch state is persisted. If the engine only has the original calibration snapshot, recommending it is an understandable data-completeness failure rather than a scoring failure.

### Gone Girl

The viewer has seen it and liked it. Its predicted strong affinity validates the positive Thriller, Mystery, and 2010s evidence.

Like `The Martian`, it must be excluded when the complete watch history is available while remaining useful as a positive taste anchor.

## B. Plausible unseen top-set candidate

### Knives Out

The viewer explicitly confirmed it as unseen. Comedy and Mystery carry positive evidence, Crime is mixed, and its era is strongly supported. It remains a credible top-set hypothesis, but the viewer has not yet validated whether they would actually like it.

## C. Algorithmically plausible false-positive risk

### Arrival

Its accepted metadata strongly overlaps with `Interstellar`, so a v1 engine can reasonably rank it highly. The viewer believes they may have seen it and may not have liked it, but is not certain.

`Arrival must clearly rise` is therefore removed as a hard product constraint. The uncertain memory must not be converted into stable negative evidence. This candidate is retained as a useful test of the limits of metadata similarity.

## D. Candidates that should remain strongly competitive

```text
Prisoners
Us
Nightcrawler
Blade Runner 2049
Whiplash
```

Each combines at least one meaningful positive signal with either mixed genres or lower-confidence evidence. The exact internal order may vary.

## E. Recent candidates and newly validated positive anchors

```text
Nope
Anatomy of a Fall
```

These candidates may receive less quality-confidence bonus than older candidates with more vote evidence, but no penalty for being recent.

The viewer's positive reactions to `The Menu`, `The Invisible Man`, and `The Batman` now provide strong positive 2020s evidence. Those three movies must be excluded as watched while contributing to the augmented profile.

`The Substance` must also be excluded as watched. Its `It was okay` reaction contributes no directional taste evidence. `Hereditary` must be excluded while adding positive Horror, Mystery, Thriller, and 2010s evidence.

## F. Boundary candidates

### The Prestige

Its 2000s era evidence is negative, but its Mystery and Science Fiction overlap is credible and its general-quality confidence is high. Because era is secondary, it should not collapse to the bottom automatically.

### The Handmaiden

Thriller and the 2010s support it; Romance provides negative evidence. It tests whether one negative genre can moderate a candidate without becoming an exclusion rule.

### Mad Max: Fury Road

It is unseen and therefore eligible. Science Fiction and the 2010s help, while Action and Adventure are mixed. It should remain plausible without being assumed to be a top match.

### Snowpiercer

The era is favorable, but its genre combination is mixed and its quality confidence is lower than several alternatives. It should be plausible but not automatically strong.

### The Grand Budapest Hotel

The viewer has seen it and did not like it. Once persisted, it becomes negative evidence and must be excluded as watched.

Without that new reaction, its Comedy, Drama, and 2010s metadata makes it a plausible false positive. The original calibration evidence does not contain enough information to infer this dislike.

## G. Confirmed or likely bad recommendations

### The Godfather

The viewer has not seen it and would not choose it because it feels too old. Its very high rating and vote evidence must not make it a top recommendation by themselves.

This cannot safely become a negative movie reaction because the film was not watched. It exposes a distinction between stable taste evidence and current decision intent. The original evidence only weakly supports an age preference, so the engine must not claim that it knows the user rejects old films.

### Oppenheimer

The viewer identified it as a movie that might deserve to rise despite limited genre support. Its general quality is strong, but Drama is highly mixed and History has no evidence. The augmented profile now provides positive 2020s era evidence.

It becomes an important boundary case: quality confidence must be strong enough to keep it competitive under a medium-confidence profile, but not so strong that the engine degenerates into a ranking of acclaimed movies.

### La La Land

The viewer identified it as a clearly bad recommendation because they do not watch musicals. It is confirmed unseen and must not be persisted as a watched negative reaction.

The v1 metadata snapshot exposes Comedy, Drama, and Romance but does not identify it as a musical. Therefore the engine cannot infer the correct rejection reason from the accepted six signals. Romance evidence may lower it coincidentally, but that must not be presented as understanding the user's dislike of musicals.

### Triangle of Sadness

A human may perceive thematic similarity to `Parasite`, but Decision Engine v1 cannot observe themes, social satire, director, or keywords. If it does not rank highly from Comedy, Drama, era, and quality alone, that is an accepted v1 limitation rather than necessarily a scoring failure.

---

# 7. Product-reviewed constraints for the first scoring model

The first formula should satisfy at least the following:

1. With the original incomplete history, `The Martian` and `Gone Girl` should receive strong raw relevance scores.
2. With the newly supplied history persisted, `The Martian` and `Gone Girl` must be excluded while contributing positive taste evidence.
3. `Knives Out` should remain a serious top-set candidate despite carrying no direct taste reaction of its own.
4. `Arrival` may score strongly from observable evidence, but its rise is no longer an accepted human-correctness constraint.
5. `The Godfather` must not become a top-three recommendation through quality confidence alone.
6. `Oppenheimer` should remain competitive under a medium-confidence profile without quality overpowering personalization.
7. `The Prestige` must not be suppressed solely because it belongs to the 2000s.
8. `Nope` and `Anatomy of a Fall` must not receive recency penalties.
9. `Us` must remain credible despite the negative reaction to `A Quiet Place`.
10. `The Menu`, `The Invisible Man`, `The Batman`, and `Hereditary` must be excluded while strengthening the augmented profile.
11. `The Substance` must be excluded while adding no directional taste evidence.
12. `The Grand Budapest Hotel` must be excluded and contribute negative evidence.
13. `La La Land` must not be represented as watched or disliked; its explicit no-musicals rejection is not observable under the accepted v1 signals.
14. `Us` may receive a small intent bonus only if represented as saved and unwatched in Watchlist.
15. A candidate with strong quality but weak personalized fit must not displace several candidates with clearly stronger taste evidence.

---

# 8. Decision Set validation result

A taste-plausible diversified result from the original incomplete engine input would contain:

```text
one of: Arrival / The Martian
plus:   Gone Girl
plus:   Knives Out or Us
```

One plausible set is:

```text
The Martian
Gone Girl
Knives Out
```

Why this set is useful as a hypothesis:

- `The Martian` represents strong positive identity similarity;
- `Gone Girl` represents the strongest genre-and-era combination;
- `Knives Out` represents an unseen candidate with positive Mystery/Comedy evidence;
- the three offer meaningfully different experiences without a major relevance collapse.

The viewer confirmed that this appears to be a good and sufficiently diverse set. However, it is not an operationally valid set under complete knowledge because `The Martian` and `Gone Girl` have already been watched.

This produces two separate conclusions:

```text
Scoring direction  → validated for The Martian and Gone Girl
Final eligibility  → invalid until their watch states are persisted
```

The initial replacement hypothesis was held until the remaining candidate pool received a watch-state audit. That audit is now complete except for the intentionally uncertain memory of `Arrival`.

Based on the augmented profile and currently confirmed unseen movies, a new working hypothesis is:

```text
Us
Knives Out
Blade Runner 2049 or Oppenheimer
```

This set is deliberately provisional:

- `Us` has strong taste fit and explicit current viewing intent;
- `Knives Out` remains a strong unseen Mystery/Comedy candidate;
- `Blade Runner 2049` represents personalized Science Fiction fit;
- `Oppenheimer` represents the viewer's proposed quality-led boundary case;
- the third position is useful for calibrating the tradeoff between personalization and quality confidence.

---

# 9. Diversity expectations

If the raw ranking begins with:

```text
Arrival
The Martian
Blade Runner 2049
Gone Girl
Knives Out
```

the final set should normally not preserve the first three unchanged. They substantially overlap on Science Fiction, Drama, and era.

A diversification phase should retain the strongest representative of that cluster and consider `Gone Girl`, `Knives Out`, or another close candidate.

Diversity must not rescue a weakly personalized candidate such as `The Godfather` merely because it is different.

---

# 10. Explanation honesty checks

Acceptable explanation evidence:

```text
Arrival
Because you loved Interstellar and have responded positively to mysteries from the 2010s.

Gone Girl
Because thrillers and mysteries are among your strongest positive signals.

Knives Out
Because it combines mystery and comedy, two genres supported by movies you enjoyed.
```

Unacceptable explanation claims:

```text
You enjoy cerebral movies.
You like social satire.
You are a fan of Christopher Nolan.
You prefer slow-burn stories.
You enjoy dark movies.
```

The current evidence and accepted metadata do not justify those statements.

---

# 11. CEO validation results

## Question 1 — Expected risers

`The Martian` and `Gone Girl` were both watched and liked; `The Martian` was considered very good. `Knives Out` is unseen. `Arrival` may have been watched and may have been disliked, but the viewer is uncertain.

Product consequence:

- the predicted affinity for `The Martian` and `Gone Girl` is validated;
- both reveal missing watch-history evidence and must be excluded once updated;
- `Arrival` becomes an uncertainty/false-positive test rather than a required high rank;
- `Knives Out` remains the strongest validated unseen hypothesis among the original four.

## Question 2 — Preferred first candidate

The viewer selected `The Martian` from the pool, while also confirming it has already been watched.

Product consequence:

The scoring intuition is credible, but candidate eligibility is only as complete as the available watch history.

## Question 3 — Proposed final set

`The Martian + Gone Girl + Knives Out` was judged a good final set in terms of relevance and diversity.

Product consequence:

The composition is validated as a taste hypothesis, not as a deliverable recommendation set, because two items are watched.

## Question 4 — Clearly bad recommendations

The viewer identified:

```text
La La Land                 → dislikes musicals
The Grand Budapest Hotel   → watched and disliked
The Godfather              → unseen, but rejected because it feels too old
```

Product consequence:

- `La La Land` exposes that the accepted metadata does not identify its musical nature;
- `The Grand Budapest Hotel` exposes coarse-genre false positives and the importance of catalog rating updates;
- `The Godfather` exposes a current-intent/age preference not safely representable as a watched negative reaction.

## Question 5 — Candidate that might deserve to rise beyond current evidence

The viewer identified `Oppenheimer`, with uncertainty.

Product consequence:

`Oppenheimer` remains a boundary case for the balance between medium profile confidence and general quality confidence. It is not yet a hard top-set requirement.

## Watch-state follow-up

The viewer confirmed positive reactions to `The Martian`, `Gone Girl`, `The Menu`, `The Invisible Man`, `The Batman`, and `Hereditary`, and a negative reaction to `The Grand Budapest Hotel`. `The Substance` was confirmed watched with the neutral reaction `It was okay`.

The viewer confirmed `Us` as unseen but desirable to watch. This validates the distinction between stable taste and current decision intent.

The viewer also stated a categorical refusal to watch musicals. `La La Land` is unseen and must not be represented as a disliked watched movie. The current v1 metadata cannot reliably apply the broader no-musicals exclusion.

Product consequence:

- preserve reaction truth and watch-state truth separately;
- update the Taste Profile in real time when a catalog reaction is captured;
- use Watchlist state for weak decision intent only;
- record the no-musicals requirement as an explicit known v1 limitation rather than inventing unsupported evidence;
- do not expand the accepted metadata scope solely to repair this single fixture before evaluating the initial deterministic engine.

## Accepted follow-on product capability

The validation exposed the inevitable gap created by onboarding sampling: a viewer may already have seen many catalog movies that were never shown during calibration.

The accepted follow-on capability is:

> The viewer can rate any movie in the catalog. The reaction updates watch history and the stable Taste Profile in real time.

This capability belongs to a later milestone. It is not required to implement the first Decision Engine scoring prototype, but the engine contracts must allow the resulting evidence to be consumed without redesign.

---

# 12. Completed follow-on

The product review and watch-state audit are complete. `Arrival` remains intentionally uncertain and supplies no stable taste evidence.

The following sequence was completed to produce the accepted P1 model:

1. preserve the original calibration snapshot as the engine-input fixture;
2. create an augmented-profile fixture containing the newly disclosed reactions;
3. freeze candidate metadata for deterministic testing;
4. implement the simplest normalized scoring prototype;
5. test several small sets of reaction and component weights;
6. reject any formula that violates the product-reviewed constraints;
7. select an initial diversity rule;
8. run the synthetic fixtures and both real-profile passes together;
9. consolidate ADR-011 and translate it into Milestone 6 tasks;
10. place catalog-wide rating and real-time Taste Profile updates into the accepted later milestone backlog.

ADR-011 now owns the production contract. The original and augmented snapshots
remain frozen regression evidence for Milestone 6.

The two-profile approach is intentional:

```text
Original snapshot  → tests what the engine can infer from onboarding alone
Augmented profile  → tests real-time learning and complete watch exclusion
```

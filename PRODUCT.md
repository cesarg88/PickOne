# PickOne Product Definition

## Document Status

- Status: `Canonical`
- Last product review: `2026-09-01`
- Product name: `PickOne` is a codename until the decision experience is
  validated.

This is the single source of truth for what PickOne is, whom it serves, the
problem it solves, and the behavior the product is intended to provide.

If another document conflicts with this one about product intent or user
behavior, this document wins. Milestones define bounded delivery, ADRs define
technical decisions, and the backlog tracks work; none of them independently
redefine the product.

Cross-cutting product terms have one canonical meaning in the
[Product Language Glossary](docs/product/product-language-glossary.md). In
particular, the Viewer Profile is persisted configuration and workflow state;
the Taste Profile is a derived interpretation of current Movie reactions.

## Current Product Development Mode

PickOne is being developed first for the Product Owner's household, with the
Product Owner as the primary viewer and decision-maker represented by the first
local profile. The immediate goal is not broad adoption; it is to make the
decision experience genuinely useful during real movie nights on the Product
Owner's iPhone.

A partner may participate in the decision, but the first version does not model
separate partner preferences or attempt to combine household profiles. External
user validation, monetization, and public distribution are intentionally
postponed until the household pilot demonstrates utility. They are deferred,
not rejected as future product directions.

## One-Sentence Definition

PickOne is an iOS decision assistant that gives people a few personalized movie
recommendations they can actually watch, so they can stop browsing and start
watching.

## The Problem

People who want to watch a movie often open several streaming applications,
browse large catalogs, compare titles, and still fail to choose anything. The
result is wasted time, decision fatigue, frustration, and sometimes abandoning
the viewing session entirely.

Existing streaming products are designed primarily to expose and retain users
inside catalogs. Search is useful when someone already knows a title. Neither
experience reliably answers:

> What should I watch now, from the services I already pay for?

PickOne exists to answer that question quickly and credibly.

## Mission

Reduce the effort and uncertainty between wanting to watch a movie and starting
one.

## Product Promise

> Open PickOne, receive a few strong movie choices for tonight, understand why they
> fit, and know where each one is included with your subscriptions.

The ideal outcome is not a longer PickOne session. It is a confident viewing
decision followed by leaving PickOne to watch the movie.

## Primary Audience

The initial audience is adults who:

- subscribe to one or more streaming services
- regularly browse without reaching a decision
- are open to recommendations beyond a single catalog
- value a small, useful answer over an exhaustive list
- may choose alone or together with a partner

The first pilot context is the Product Owner's household in Spain, using one
individual profile for the Product Owner. Household movie nights and partner
participation remain useful real-world context, but the first recommendation
model represents only the Product Owner's preferences. This does not limit the
long-term product to one viewer, household, or country.

## Primary Job to Be Done

When I want to watch a movie but do not know which one, help me choose something
that fits my taste and current situation and is included on a service I can use,
so I can start watching without wasting time browsing.

## Product Thesis

PickOne becomes useful by combining three kinds of context:

1. **Stable preference context** — what the viewer tends to enjoy or avoid.
2. **Viewing context** — what feels right tonight, including mood, available
   time, company, and desired intensity.
3. **Availability context** — the viewer's active country and subscribed
   streaming services.

These contexts are combined to reduce decision fatigue, not to maximize
catalogue exploration.

A title is not a valid primary recommendation merely because it matches a
genre. It must be a plausible fit for the viewer and the moment, and it must be
watchable under the active availability constraints.

## Product Principles

### Decisions over discovery

Streaming has an abundance problem. People rarely fail because no movie exists;
they fail because comparing too many plausible options becomes exhausting.
PickOne therefore optimizes for a confident choice, not catalog exploration,
content impressions, or time spent in the app.

PickOne does not exist to make browsing more efficient. It exists to do the
difficult filtering before presenting an answer. A feature that makes browsing
easier while making the final decision harder does not support the core product.

### Few strong, purposeful options

Default to three recommendations. More options should be requested explicitly,
not exposed through an infinite feed. One option provides no meaningful
alternative; larger sets recreate the comparison burden PickOne is intended to
remove.

The three recommendations form a balanced decision set rather than three
interchangeable ranking results:

1. **Safe Choice** — the highest-confidence option and the one most likely to
   minimize regret.
2. **Stretch Choice** — still compatible with the viewer, but meaningfully
   different in mood, style, genre, or another useful dimension.
3. **Discovery Choice** — less obvious than the other two, while retaining a
   credible and explainable connection to the available evidence.

Discovery must feel earned rather than random. When PickOne cannot produce
three eligible choices at the required quality, an honest smaller set is better
than filling a role with a weak recommendation.

### Watchability is eligibility

For the primary experience, a movie unavailable in the active region and
subscriptions is not a useful recommendation. Availability is evaluated before
a movie enters the final decision set; it is not decorative metadata added
after ranking.

### Honesty and explainability over false precision

Every recommendation must state briefly why it fits. Explanations should build
confidence rather than expose technical scoring or generic marketing copy. They
must be supported by evidence PickOne actually possesses and must never imply
knowledge, certainty, personalization, or availability that has not been
established.

When preference evidence or candidate quality is limited, the experience must
represent that uncertainty honestly. A plausible, understandable recommendation
is more trustworthy than unsupported claims of algorithmic intelligence.

### Learn without interrogating

Collect enough information to make a credible first recommendation, then learn
from lightweight real behavior. Do not turn onboarding or normal use into a
questionnaire.

### Context is not permanent taste

“Not tonight” must not be interpreted as “I dislike this.” Product actions must
distinguish temporary intent, stable dislike, prior viewing, and future
interest.

### Preserve user trust

Do not silently replace a useful recommendation set, claim unsupported
personalization, hide availability uncertainty, or imply that rent/buy offers
are included subscriptions.

### Reduce unnecessary decisions

Ask viewers only for choices that are meaningful to them. Persistence,
orchestration, and other implementation details should remain invisible unless
an error requires the viewer to act.

### Decisions over engagement

PickOne optimizes for decision confidence, not clicks, screen views, or session
length. The ideal session is short: the viewer opens PickOne, finds a movie,
starts watching, and leaves the application. Success means helping the viewer
leave with a decision.

### Build confidence before sophistication

The first recommendation experience must demonstrate that PickOne understands
enough about the viewer to be useful without overstating what it knows.
Onboarding, the viewer profile, availability, the Decision Engine, and concise
explanations all exist to establish that confidence.

### AI is optional and the promise is durable

The product is a decision assistant, not a chatbot. The Decision Engine must
produce meaningful recommendation sets from deterministic product rules. AI may
later improve explanations, ranking, personalization, or reasoning, but the
core experience must remain useful when no AI service is available.

Algorithms, scoring models, providers, and implementation technologies may
change. The promise to provide a small, deliberate, watchable, and explainable
decision set should remain stable.

## Target First Product Version

The first product version validates a recommendation-first experience for
individual viewing. It consists of onboarding, a persistent home selection,
movie detail, availability, trailers when available, and explicit feedback.
The first complete recommendation experience is the initial confidence test:
technical sophistication has no value unless the resulting choices make sense
to the viewer.

### 1. Onboarding

Onboarding should take approximately two minutes and collect only information
needed to improve the first recommendation set.

#### Region

- use Spain (`ES`) as the only supported pilot region
- display Spain to the user without exposing a country selector during the
  pilot
- persist the region explicitly so later product versions can support region
  selection without redefining availability

The region represents where the user intends to watch, not nationality or
language. Region editing is deferred until PickOne supports another market.

#### Streaming subscriptions

- ask which supported services the user currently has
- allow multiple selections
- require at least one selected service
- do not preselect a service
- make the list editable after onboarding
- distinguish access included without an additional transaction from rental,
  purchase, and separately paid add-on channels
- do not ask the pilot user to select plan variants; map the Product Owner's
  confirmed entitlements internally

The default first-version promise is content the user can play through the
selected plan without an additional payment. Advertising does not make an
already-paid plan ineligible by itself. Rent, buy, and unselected add-on
channels must not be mixed into that promise. A future plan selector should be
introduced only when a variant materially changes availability and PickOne can
represent that distinction reliably.

#### Taste calibration

Use a versioned catalog of recognizable movie examples with fast responses:

- `Love it`
- `Like it`
- `It was okay`
- `Didn't like it`
- `Haven't seen it`
- `Don't know it`

The first four responses are informative taste signals and mean the viewer has
seen the movie. `It was okay` is neutral and must not be interpreted as a
positive or negative signal. `Haven't seen it` means the viewer recognizes the
movie but has not watched it. `Don't know it` means the viewer does not identify
the movie. Neither of the latter responses is a positive or negative taste
signal.

The normal flow starts from 12 titles, may use reserve titles up to 15 total
responses, and finishes early after eight informative signals. Reaching eight
signals is a target, not a completion requirement. After 15 responses, a
profile with three to seven signals is accepted with conservative future
personalization. With zero to two signals, the viewer may rate an additional
optional block or continue with broad, availability-filtered future
recommendations without a strong-personalization claim.

Onboarding completion is automatic. PickOne already knows when calibration has
finished because eight informative signals have been reached, the normal flow
has ended with three to seven signals, the viewer has explicitly chosen
`Continue` from the low-signal decision, or the optional extension has reached
eight signals or exhausted its six titles. These conditions trigger completed-
profile persistence immediately; they do not lead to a separate confirmation
screen or require a `Save preferences` action.

The only explicit completion-related choice is the meaningful low-signal
decision between `Rate more movies` and `Continue`. After the last valid action,
successful persistence enters the application automatically. A detectable
persistence failure keeps the completed draft and current onboarding state,
shows retry UI, and never enters the application.

Concrete title reactions are more informative than genre selection alone. The
catalog should be optimized for recognition in the household pilot while
remaining deliberately diverse in genre, tone, pace, era, popularity, and
language without claiming scientific precision.

PickOne may update the catalog remotely without an application release. Before
calibration it prefetches a complete validated catalog, waits visibly for no
more than two seconds, and then resolves the flow from remote, last valid
cached, or bundled content in that order. Once a flow starts, its exact catalog
snapshot is frozen through completion and relaunch; a late or newer catalog can
affect only a later onboarding or recalibration flow.

Calibration cards use the title known in Spain as the primary title and an
original or English title with the release year as secondary recognition
context. The bundled catalog preserves both title forms and year as fallback
metadata when localized TMDB hydration is unavailable.

When both title forms are equivalent after ignoring case and trivial whitespace
differences, the card shows the title only once with the year. Distinct title
forms remain on two lines. This comparison does not perform linguistic,
punctuation, or diacritic normalization.

Milestone 5 initially preserved calibration reactions separately from
Watchlist watched state. Milestone 7 supersedes that temporary boundary with a
single Viewer Movie State: informative calibration responses become current
Movie reactions and watched facts, while Watchlist remains future intent for
an unwatched movie.

Progress visualization, animations, transitions, and completion feedback are
deferred to a dedicated onboarding UX-polish milestone. This completion-flow
decision does not introduce a progress indicator.

#### Deferred preference controls

Names, avatars, manual genre choices, language preferences, family or maturity
constraints, accounts, and household profiles are outside Onboarding v1. They
may be introduced later only when observed product needs justify the added
questions.

### 2. Home — “Three for Tonight”

Home is the primary product surface. It opens with three recommendations, not a
generic catalog and not an empty text composer. It should feel as if PickOne has
already done the difficult filtering rather than asking the viewer to search a
database.

The set should contain:

1. **Safe Choice** — the highest-confidence option based on the available
   evidence
2. **Stretch Choice** — a compatible option with a meaningful difference in
   tone, style, genre, or tradeoff
3. **Discovery Choice** — a less obvious option with a credible connection to
   the viewer's preferences or current context

The labels presented to users may evolve, but the set should feel deliberate
rather than like three interchangeable results.

Each recommendation communicates at a glance:

- title and artwork
- a short reason it fits
- streaming service where it is included
- runtime
- release year and useful genre or tone context
- whether it has already been saved or watched

The short reason uses the strongest supported semantic evidence in this order:

1. saved Watchlist intent combined with a real taste match;
2. a positive `Love it` or `Like it` movie anchor;
3. learned positive genre affinities;
4. general quality evidence while the profile is sparse.

The Safe, Stretch, or Discovery role communicates how the set was composed.
Diversity alone never replaces the reason that the movie fits.

A visible positive-anchor explanation is stricter than the underlying P1
similarity score. Its anchor must have the Viewer's current `Love it` or `Like
it` reaction, share at least one genre with the candidate, and reach genre
Jaccard similarity of at least `1/3`. Release era may reinforce that real genre
connection but cannot justify an anchor by itself. Direct and Watchlist-wrapped
copy names only the shared genres and supported era evidence carried by the
structured anchor. Persisted anchor evidence must still match the current
reaction and metadata threshold when the set is restored or published.

Every genre named to the Viewer must use a human-readable label. TMDB genre IDs
may support internal identity, comparison, and scoring, but they must never
appear in recommendation copy. If a supported genre signal has no readable
label, PickOne must resolve it from trusted hydrated metadata or treat that
signal as unrenderable; it must not fall back to copy such as `genre 28`.

### 3. Recommendation-set persistence and refresh

The current set persists when the app is closed and reopened. A user must not
lose an interesting suggestion merely because they switched apps or wanted to
discuss it with a partner.

The set changes when:

- the user explicitly requests another three
- feedback makes a replacement appropriate
- the active profile, region, services, or viewing context changes
- an accepted freshness policy expires the set

Provide a visible action such as `Give me three more`. Pull to refresh may exist
as a secondary shortcut, but it must not be the only way to request a new set.

The active set cannot repeat as the result of a replacement request. Watched,
Movie reactions, and `Not interested` are permanent title exclusions unless the
Viewer explicitly edits that state. Exact availability and credibility remain
non-negotiable.

The recommendation cycle is identified by the engine version, current Movie
reactions, region, selected services, and explicit viewing context. A Movie-
reaction change creates a new cycle identity because it changes the derived
Taste Profile. Complete shown history is retained for diagnosis, but previously
shown without feedback is not a permanent exclusion. Only a bounded recent
window suppresses otherwise valid titles; older titles outside that window may
return after never-shown candidates and progressive recall are exhausted.

Watchlist, watched, and `Not interested` changes update mutable eligibility and
repair the set without deleting complete history. Watched, reactions, and `Not
interested` never become rollover candidates. `Give me three more` must execute
one real progressive recovery strategy rather than repeat an unchanged
deterministic empty operation.

A reaction recalculates Taste Profile and rebuilds evidence, but it should
retain other visible titles that remain eligible, credible, and explainable.
Watched and `Not interested` normally replace only the affected title. A
smaller or zero set is honest only after the complete accepted strategy; an
exhausted state is explained and offers actions that can change the underlying
inputs instead of another known no-op refresh. Exhaustion suppresses that same
deterministic operation for 24 hours, then restores `Give me three more` so a
later TMDB catalog or availability change can be discovered. It never becomes
a permanent lock.

If the stored recommendation envelope is corrupt or incompatible, PickOne
preserves the unread bytes for diagnosis and attempts to generate and persist a
replacement set from current trusted inputs. If recovery cannot complete, Home
shows a retryable failure. Recommendation recovery never resets or modifies the
Viewer Profile, Watchlist, or Search History.

PickOne derives one complete Taste Profile from every current Movie reaction.
It does not silently omit reactions whose movie metadata cannot be hydrated and
does not describe such a partial interpretation as personalized. When complete
Taste Profile hydration fails, Home retains only a previously persisted set
that remains provably safe under the current state; otherwise it shows Retry.
Candidate-specific enrichment failure remains separate and may exclude only
the affected candidate when the remaining complete input is sufficient.

### 4. Lightweight viewing context

The default home experience should work without another form. When the default
set does not fit the moment, offer quick contextual choices such as:

- something light
- make me laugh
- something intense
- under 100 minutes
- a safe choice
- surprise me

These choices refine the current session. They do not permanently redefine the
user's taste.

### 5. Movie state and feedback

Watch state, Watchlist intent, and preference are distinct meanings:

- Watchlist means an unwatched movie saved for the future;
- watched is an independent fact that may be assigned from any Movie Detail;
- a Movie reaction implies watched and replaces any earlier reaction;
- removing a reaction preserves watched;
- `Not interested` means an unwatched title is excluded stably, but it is not a
  genre or era dislike and contributes no P1 affinity;
- explicit rewatch intent is not supported in this version.

Rating, watched, `Not interested`, and Watchlist actions apply the transition
rules accepted in Milestone 7. Conflicting prior intent is removed rather than
silently restored later. PickOne must not interpret a detail open, trailer
play, or passive impression as watched or as feedback.

Changing a Movie reaction recalculates the Taste Profile and regenerates Home
from the latest state snapshot identity while preserving complete diagnostic
history. Other visible recommendations remain when their evidence can be
rebuilt as eligible, credible, and explainable under the new snapshot. Home
communicates a successful update discreetly. A stale generation can never
replace a result built from newer Viewer Movie State.

Every Home recommendation exposes lightweight explicit feedback without
requiring navigation to Movie Detail: the four Movie reactions, `Already
watched` without a reaction, and `Not interested`. Movie Detail and `My movies`
remain the full editing surfaces. Passive card impressions and navigation never
become feedback.

Explicit decision-outcome actions such as `Watch this`, `Not tonight`, and a
later viewing confirmation remain future work. They are not prerequisites for
learning from deliberate ratings, watched facts, Watchlist intent, or `Not
interested`.

### 6. Movie detail

Detail exists to build enough confidence to make the decision. It should
prioritize:

- synopsis
- the PickOne recommendation reason
- runtime, year, genres, and key credits
- where it is included in the active region
- trailer when an appropriate official video is available
- Watchlist and watched state
- rating and `Not interested` feedback
- the optional provider handoff action

A trailer is supporting evidence, not an autoplay surface. If no suitable
trailer exists, omit the section gracefully.

Availability is presented directly in Detail rather than hidden behind a
handoff action. Detail content and availability may load in parallel;
availability has its own loading and failure state and must not block otherwise
usable movie information.

### 7. Availability

Availability is a recommendation eligibility rule for the first product
version, not decorative metadata added after ranking.

The product must evaluate:

- active viewing country
- selected providers
- selected plan or entitlement where the source distinguishes it
- monetization type
- known freshness and coverage limitations

Primary recommendations should be included with at least one selected
plan in the active region without additional transactional payment. Rent, buy,
and separately paid add-on channels are ineligible unless a future product
decision explicitly enables them. Ad-supported access is eligible only when it
belongs to the plan the user selected.

TMDB Discover may generate candidates, but it is not final availability proof.
Before a movie becomes eligible, its movie-level provider response must contain
an allowlisted selected provider under the active region's `flatrate` entries.

Availability data must carry required TMDB and JustWatch attribution. When a
direct provider deep link is unavailable, the product must not manufacture or
imply one.

Availability checks distinguish three outcomes:

- `eligible` — valid current evidence contains at least one selected,
  allowlisted provider under the active region's `flatrate` entries
- `ineligible` — valid regional evidence exists, but it does not satisfy the
  selected-provider eligibility rule
- `unknown` — regional evidence could not be obtained or verified

Missing evidence, an absent active-region entry, source failure, and invalid
data are `unknown`, not proof that a movie is unavailable. Unknown titles fail
closed for primary recommendation eligibility while remaining distinct from
ineligible titles.

Detail shows every selected provider for which eligibility is verified. The
provider logos communicate availability and are not interactive when PickOne
cannot open the corresponding service directly. A separate secondary handoff
may open only the country-specific watch URL returned by TMDB and must clearly
identify TMDB as its destination.

### 8. Supporting surfaces

The first-version main tabs are, in order: `Home`, `Search`, `Discover`,
`Watchlist`, and `Settings`. Home replaces the current first Discovery surface,
and Discovery takes the tab position currently occupied by Ask. The existing
Ask code is retained as a later-milestone asset but is not exposed as a main
tab in Milestone 6.

Search, discovery, watchlist, and movie detail remain useful, but support the
decision product:

- **Search** helps when the user already knows a title.
- **Discovery** allows deliberate catalog exploration without becoming Home.
- **Watchlist** preserves future intent and informs recommendations.
- **My movies** is the accepted Settings history for ratings, watched movies
  without a rating, and `Not interested`; it excludes Watchlist-only titles.
- **Detail** supplies evidence for a decision.
- **Ask** later supports precise requests that quick context cannot express.

## Ask and Natural Language

Free-text `Ask` remains part of the product vision but is not the primary
first-version entry experience.

It is a later enhancement for specific intent such as:

- “A romantic movie with emotional weight, but not too sad.”
- “Something about samurai released in the last five years.”
- “A smart science-fiction movie like Arrival, under two hours.”

Ask should use the same profile, region, subscription, watch-history, and
availability rules as Home. It must not become a separate recommendation system
or a general-purpose chat experience.

The existing stubbed Ask flow is a technical and UX learning asset, not the
current definition of the product.

## Shared Viewing and Household Direction

Choosing with a partner is a core long-term use case. The intended product
direction includes:

- distinct taste profiles
- shared household subscriptions
- selection of who is watching
- recommendations that seek a credible intersection of preferences

Full household and account infrastructure is not required for the first
individual recommendation version. The pilot persists one local profile for the
Product Owner. Joint movie nights may inform qualitative feedback, but partner
preferences are not a recommendation input in this version.

Future household work should be justified by observed decision problems rather
than added only to preserve hypothetical flexibility.

## Success Definition

The primary outcome is a viewing decision, not engagement with PickOne.

### North-star candidate

Percentage of recommendation sessions in which the user chooses a movie to
watch within five minutes.

### Supporting signals

- time from opening Home to `Watch this`
- percentage of sessions ending in `Watch this`
- confirmation that the chosen movie was actually watched
- number of new sets requested before a decision
- `Not tonight`, `Not interested`, and watched-state rates
- detail and trailer opens that lead to a decision
- recommendation eligibility loss caused by availability constraints
- repeated or already-watched recommendation rate
- qualitative confidence and frustration reported in the pilot

Time spent, number of screens viewed, and catalog impressions are not success
metrics by themselves.

### Initial product hypothesis

For viewers who currently browse multiple streaming catalogs without deciding,
three personalized and watchable recommendations will reduce time-to-decision
and increase the probability of starting a movie.

The hypothesis is not validated merely because the app builds, produces
recommendations, or passes a device smoke test.

## Privacy and Trust Boundaries

- collect only preference and product-behavior data needed for accepted
  recommendation and measurement purposes
- do not collect raw natural-language requests by default for analytics
- explain any future account, sync, or remote-profile behavior before enabling
  it
- allow users to edit subscriptions, region, preferences, watched state, and
  feedback
- do not claim that a recommendation is personalized until meaningful signals
  are actually used
- communicate availability as current best-known information, not a guarantee

## Current Baseline vs Target

The current application already provides:

- discovery
- search and search history
- movie detail, similar movies, and credits
- one recoverable Unified Viewer Movie State for current reactions, watched
  facts, `Not interested`, and future Watchlist intent
- a stubbed free-text Ask experience
- regional subscription-availability evidence in Movie Detail
- resumable onboarding and recalibration with streaming-service selection and
  an exact frozen catalog snapshot resolved from validated remote, last-valid
  cached, or bundled content
- a persistent editable local viewer profile and Settings surface
- continuous reaction editing from Movie Detail, complete Taste Profile
  recalculation, and Home reconciliation that preserves shown history while
  rejecting obsolete work
- the `My movies` Settings history for ratings, watched-only movies, and `Not
  interested`, separate from future Watchlist intent
- the deterministic Decision Engine and persistent “Three for Tonight” Home
  implementation from PR #31, including structured explanations, refresh,
  repair, Movie Detail routing, and the accepted positive-anchor boundary,
  extended in Milestone 7 to regenerate or repair from the latest Viewer Movie
  State

Milestone 6 is complete. The Milestone 7 implementation baseline now includes
Unified Viewer Movie State, continuous reactions and Taste Profile updates,
Home reconciliation, `My movies`, and remote/cached/bundled frozen calibration
catalog resolution. Final physical validation found a P0 exhaustion defect, so
Milestone 7 is reopened and Milestone 8 remains blocked. The accepted product
correction preserves explicit feedback and complete shown history while making
recent repeat suppression bounded, recoverable, and directly operable from
Home. Its exact D0 policy is proposed in
[Milestone 7 P0 — Home Exhaustion Recovery](docs/milestones/milestone-7-p0-home-exhaustion-recovery.md).

Explicit decision outcomes such as `Watch this` and `Not tonight`, later
viewing confirmation, and trailer presentation remain future product work.

Technical migration or architecture work may continue without changing current
behavior, but new product implementation must be specified against this target.

## Explicit Non-Goals for the First Product Version

- infinite personalized feed
- maximizing session duration
- general-purpose AI conversation
- social feed, public profiles, user reviews, or follower relationships
- collaborative filtering at scale
- cross-device accounts and sync
- push notifications
- support for TV series
- direct playback hosting
- a guarantee that third-party availability data is always complete
- replacing streaming-service applications after the user decides

## Accepted Product Decisions

As of the last review:

- PickOne is developed first for the Product Owner's household and must prove
  useful there before external validation, monetization, or public distribution.
- The pilot uses one editable local profile representing the Product Owner.
- Home, not Ask or generic discovery, is the primary product surface.
- The default recommendation set contains three movies.
- The default set is deliberately composed as Safe Choice, Stretch Choice, and
  Discovery Choice; these are product roles rather than three interchangeable
  ranking positions.
- Onboarding captures region, subscriptions, and title-based taste signals.
- Subscription and regional availability are primary eligibility constraints.
- Included subscription access is distinct from rent or buy availability.
- Recommendation sets persist across app launches until deliberately refreshed
  or invalidated.
- A visible new-set action is required; pull to refresh is optional support.
- Every recommendation explains why it fits and where it is included.
- Feedback distinguishes stable preference from temporary mood.
- Trailers belong in Detail when suitable video metadata exists.
- Natural-language Ask is a later enhancement using the same decision rules.
- Shared viewing is an important future direction, but separate or combined
  household profiles are outside the first individual version.
- The first pilot market is Spain (`ES`).
- The pilot stores `ES` explicitly but does not expose a country selector.
- The pilot provider allowlist is Netflix `8`, Amazon Prime Video `119`,
  Disney Plus `337`, and Max `1899`, presented to the user as Max.
- The pilot entitlement maps Netflix's highest plan to provider `8` and
  ad-free Prime Video to provider `119`.
- Onboarding asks for supported services, not plan variants. The known pilot
  entitlements are mapped internally; plan selection remains deferred until it
  materially and reliably changes availability.
- Onboarding shows Spain inside service selection rather than as a separate
  non-interactive screen, requires at least one service, and preselects none.
- Onboarding progress is resumable. Successful completion atomically commits
  profile lifecycle and informative Movie reactions while preserving Search
  History and every unrelated Watchlist intent. When completion upserts a
  reaction for a movie currently saved, that same atomic transition removes
  only that movie's conflicting Watchlist intent as required by ADR-012.
- Onboarding completes automatically after the last valid action. There is no
  intermediate `Ready to save your preferences?` state, completion confirmation
  screen, or `Save preferences` button.
- The viewer's only explicit completion-related choice is `Rate more movies`
  or `Continue` when normal calibration ends with zero to two informative
  signals.
- A detectable final-persistence failure retains the completed draft and
  current onboarding state, exposes retry, and never routes into the
  application.
- Informative-signal count is calculated in Domain from the four informative
  reactions and is not persisted independently.
- Calibration uses Spain-localized titles with bundled localized, original or
  English, and year fallbacks to reduce false `Don't know it` responses.
- Equivalent localized and original or English titles are shown once with the
  year; distinct title forms remain visible together.
- The exact Milestone 5 calibration catalog and order are accepted for the
  household pilot.
- Preferences can edit services, restart full calibration, or reset the profile
  with confirmation. Milestone 7 adds individual reaction editing through Movie
  Detail while `My movies` remains a read projection that routes there.
- Preferences and About use `Settings` as the accepted fifth main tab.
- Recalibration owns only calibration progress. Completing it preserves the
  region and current service selection from the active profile, including
  service edits made while recalibration is in progress.
- Eligibility means included in the selected plan without an additional
  transaction. Advertising alone is not a universal exclusion.
- Amazon Video stores, rent, buy, unselected Amazon Channels, and other
  separately paid add-ons are excluded.
- TMDB Discover is candidate generation only. Final eligibility requires the
  exact allowlisted provider in the movie-level `ES.flatrate` response.
- Availability is verified when a recommendation set is generated and
  revalidated before handoff when the previous verification is more than
  24 hours old.
- “Three for Tonight” does not expire automatically during the pilot. If
  revalidation invalidates one title, replace that title rather than discarding
  the complete set.
- If fewer than three eligible high-confidence movies exist, show the smaller
  honest set instead of violating availability or quality constraints.
- The pilot may use TMDB's country-specific watch page as an honest fallback
  handoff. It must not be presented as a direct provider link.
- Availability copy must identify JustWatch as the source, state that
  availability may change, and preserve required TMDB attribution.
- Movie Detail presents availability immediately in an independent
  `Available on` section rather than requiring a handoff action to discover it.
- Detail shows all selected providers verified under `ES.flatrate`; provider
  logos are informational and non-interactive.
- Availability loading and failure never block otherwise usable Detail content.
- Valid regional evidence produces either `eligible` or `ineligible`; missing,
  invalid, or unobtainable regional evidence produces `unknown`.
- The pilot uses the exact English copy and behavior bounded by Milestone 4,
  including brief JustWatch attribution beside availability and full TMDB and
  JustWatch attribution in About.
- The TMDB regional watch page is exposed only as a secondary
  `View playback options on TMDB` action, never as a provider deep link.
- Decision Engine v1 uses the accepted deterministic P1 formula, eligibility,
  diversity, role, tie-breaking, and evidence rules in ADR-011.
- Main navigation for Milestone 6 is `Home`, `Search`, `Discover`, `Watchlist`,
  and `Settings`; Ask remains implemented but hidden until its later milestone.
- Recommendation-cycle identity includes engine version, current Movie
  reactions, region, selected services, and viewing context. Watchlist changes
  repair or invalidate current eligibility without clearing already-shown
  cycle history.
- Recommendation-envelope corruption or incompatibility preserves the unread
  bytes, attempts regeneration, and exposes Retry if recovery fails without
  modifying profile, Watchlist, or Search History.
- Recommendation explanations prefer Watchlist intent plus a real taste match,
  then a positive movie anchor, then positive genre affinity, then quality for
  sparse profiles. Product roles communicate composition; diversity is not a
  substitute for fit evidence.
- Recommendation copy never exposes numeric genre IDs. A genre may be named
  only from trusted human-readable metadata; unlabelled genre evidence must be
  resolved, omitted, or cause explanation repair rather than produce an
  internal fallback such as `genre 28`.
- A visible positive anchor is limited to the current `Love it` or `Like it`
  reaction, at least one shared genre, and genre Jaccard similarity of at least
  `1/3`. Era may strengthen but never establish the anchor, and direct or
  Watchlist-wrapped copy enumerates only the shared genre and supported era
  signals. This explanation rule does not change P1 scoring.
- Viewer Profile is persisted viewing configuration and calibration lifecycle;
  Taste Profile is derived from current Movie reactions and the Decision Engine
  version rather than persisted as another source of truth.
- Taste Profile generation is all-or-nothing across current Movie reactions.
  PickOne never generates or publishes a recommendation set from a silently
  incomplete Taste Profile; failure retains only independently proven-safe
  content and otherwise exposes Retry.
- After Milestone 7 migration, Viewer Profile no longer persists a reaction
  map; Viewer Movie State is the single persisted owner of current reactions.
- Watchlist means future intent for an unwatched movie. Watched is an
  independent fact available from any Movie Detail; a reaction implies watched,
  and explicit rewatch intent remains unsupported.
- Watchlist's final Milestone 7 surface contains future intent only; its former
  watched section moves to the accepted `My movies` history.
- `My movies` is the final Settings label for current ratings, watched-only
  movies, and `Not interested`; Watchlist-only titles do not appear there.
- `Not interested` is a stable unwatched title exclusion. It does not become a
  negative genre or era affinity and is not available for a watched movie.
- Viewer Movie State transitions clear conflicting intent according to
  Milestone 7 without restoring it later: rating or watched removes Watchlist,
  unwatching removes a rating, and saving to Watchlist clears `Not interested`.
- A reaction change recalculates Taste Profile under a new non-reusable state-
  snapshot identity, preserves complete diagnostic history and bounded recent
  suppression, and keeps other visible titles only when their rebuilt evidence
  remains eligible, credible, and explainable.
  Watchlist, watched, and `Not interested` changes normally repair only the
  affected title without clearing complete or recent history; obsolete work
  cannot publish.
- Normal preference reset removes reactions and `Not interested` while
  preserving watched, Watchlist, Search History, and complete shown history. It
  starts a fresh recent-suppression epoch so Home can generate again.
  Recalibration upserts only informative reactions; `Haven't seen it`, `Don't
  know it`, and omitted movies never erase existing movie feedback.
- Calibration catalog resolution prefers a validated remote snapshot, then a
  last valid cache, then bundled content after at most two visible seconds. A
  flow freezes its exact snapshot through completion and relaunch.
- The initial remote catalog mirrors the accepted bundled household catalog.
  Later content or order changes still require Product Owner approval even
  though publication does not require an app release.
- Local viewer-state recovery tries the active envelope, a previous valid copy,
  and legacy migration while preserving unread bytes. Only total recovery
  failure may offer an explicit destructive reset; no failure fabricates empty
  viewer state.
- Recovery that must roll back to an earlier saved snapshot says so and asks the
  Viewer to review Settings; a normal first migration does not show a false
  warning.

## Open Product Questions

These require explicit product decisions before their related implementation:

1. What confirmation language best distinguishes a future `Watch this` intent
   from verified viewing?

Open questions are not permission for implementation agents to invent behavior.
They must be resolved in product steering or explicitly bounded by a milestone.

## Related Documents

- [`docs/product/product-language-glossary.md`](docs/product/product-language-glossary.md)
  defines canonical cross-cutting product and engineering language.
- [`docs/milestones/milestone-7-continuous-taste-learning.md`](docs/milestones/milestone-7-continuous-taste-learning.md)
  is the accepted executable specification for continuous taste learning,
  unified movie state, and the remote calibration catalog.
- [`docs/decisions/adr-012-unified-local-viewer-movie-state.md`](docs/decisions/adr-012-unified-local-viewer-movie-state.md)
  defines the unified local state, persistence, migration, and recovery model.
- [`docs/decisions/adr-013-remote-calibration-catalog.md`](docs/decisions/adr-013-remote-calibration-catalog.md)
  defines remote catalog resolution with exact-flow snapshot freezing.
- [`docs/milestones/milestone-6-three-for-tonight.md`](docs/milestones/milestone-6-three-for-tonight.md)
  is the completed implementation specification for the deterministic Decision
  Engine and persistent Home set.
- [`docs/decisions/adr-011-deterministic-decision-engine-v1.md`](docs/decisions/adr-011-deterministic-decision-engine-v1.md)
  defines the accepted P1 model, eligibility, composition, explanation, and
  persistence architecture.
- [`docs/milestones/milestone-5-viewer-profile-onboarding.md`](docs/milestones/milestone-5-viewer-profile-onboarding.md)
  is the completed specification and implementation record for viewer-profile
  onboarding.
- [`docs/decisions/adr-010-local-viewer-profile-and-dynamic-context.md`](docs/decisions/adr-010-local-viewer-profile-and-dynamic-context.md)
  defines its accepted persistence and dynamic availability-context
  architecture.
- [`docs/milestones/milestone-4-availability-foundation.md`](docs/milestones/milestone-4-availability-foundation.md)
  is the completed specification and record for availability behavior.
- [`docs/decisions/adr-009-availability-boundary-verification.md`](docs/decisions/adr-009-availability-boundary-verification.md)
  defines the availability architecture boundary and verification policy.
- [`docs/product/product-roadmap.md`](docs/product/product-roadmap.md) tracks
  delivery sequence.
- [`docs/product/improvement-backlog.md`](docs/product/improvement-backlog.md)
  tracks accepted and proposed work.
- [`docs/process/agent-delivery-model.md`](docs/process/agent-delivery-model.md)
  defines how product decisions become implementation specifications.
- [`docs/recommendation/recommendation-strategy-v1.md`](docs/recommendation/recommendation-strategy-v1.md)
  preserves the earlier Ask-first reasoning work and remains useful where it
  does not conflict with this definition.
- [`docs/product/conversational-recommendation-mvp.md`](docs/product/conversational-recommendation-mvp.md)
  records the existing stubbed Ask milestone rather than the target product.

# PickOne Product Definition

## Document Status

- Status: `Canonical`
- Last product review: `2026-07-30`
- Product name: `PickOne` is a codename until the decision experience is
  validated.

This is the single source of truth for what PickOne is, whom it serves, the
problem it solves, and the behavior the product is intended to provide.

If another document conflicts with this one about product intent or user
behavior, this document wins. Milestones define bounded delivery, ADRs define
technical decisions, and the backlog tracks work; none of them independently
redefine the product.

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

> Open PickOne, receive three strong choices for tonight, understand why they
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

A title is not a valid primary recommendation merely because it matches a
genre. It must be a plausible fit for the viewer and the moment, and it must be
watchable under the active availability constraints.

## Product Principles

### Decisions over discovery

Optimize for a confident choice, not catalog exploration, content impressions,
or time spent in the app.

### Few strong options

Default to three recommendations. More options should be requested explicitly,
not exposed through an infinite feed.

### Watchability is part of relevance

For the primary experience, a movie unavailable in the active region and
subscriptions is not a useful recommendation.

### Explain the recommendation

Every recommendation must state briefly why it fits. Explanations should build
confidence rather than expose technical scoring or generic marketing copy.

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

### AI is an implementation option

The product is a decision assistant, not a chatbot. AI may improve reasoning,
but the experience and success criteria must not depend on AI novelty.

## Target First Product Version

The first product version validates a recommendation-first experience for
individual viewing. It consists of onboarding, a persistent home selection,
movie detail, availability, trailers when available, and explicit feedback.

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

Use approximately 10–15 recognizable movie examples with fast responses:

- `Love it`
- `Like it`
- `Not for me`
- `Already watched`
- `Do not know it`

Concrete title reactions are more informative than genre selection alone.
Examples should be diverse enough to reveal genre, tone, pace, era, popularity,
and language preferences without claiming scientific precision.

#### Optional preference controls

The user may additionally select:

- genres they usually enjoy
- genres or content they want to avoid
- openness to subtitles or original-language films
- family or maturity constraints where relevant

Optional controls must not make onboarding feel mandatory or exhaustive.

### 2. Home — “Three for Tonight”

Home is the primary product surface. It opens with three recommendations, not a
generic catalog and not an empty text composer.

The set should contain:

1. a high-confidence or safest choice
2. a complementary choice with a different tone or tradeoff
3. a discovery choice that remains credible but is less obvious

The labels presented to users may evolve, but the set should feel deliberate
rather than like three interchangeable results.

Each recommendation communicates at a glance:

- title and artwork
- a short reason it fits
- streaming service where it is included
- runtime
- release year and useful genre or tone context
- whether it has already been saved or watched

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

Avoid immediate repeats from the active set, dismissed movies, and already
watched movies unless the user explicitly asks for them.

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

### 5. Decision and feedback actions

Recommendations need explicit outcome actions:

- `Watch this` — the user intends to watch the movie now
- `Save for later` — relevant, but not the current decision
- `Not tonight` — temporary mismatch; do not learn a stable dislike
- `Not interested` — negative preference signal
- `Already watched` — exclude by default and improve future context

Actions should update the set deliberately. PickOne must not interpret a detail
open, trailer play, or passive impression as a completed decision.

After a `Watch this` decision, a later lightweight check may ask whether the
user actually watched it. This closes the gap between intent and outcome without
requiring ratings or reviews.

### 6. Movie detail

Detail exists to build enough confidence to make the decision. It should
prioritize:

- synopsis
- the PickOne recommendation reason
- runtime, year, genres, and key credits
- where it is included in the active region
- trailer when an appropriate official video is available
- save and watched state
- the explicit `Watch this` or provider handoff action

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

Search, discovery, watchlist, and movie detail remain useful, but support the
decision product:

- **Search** helps when the user already knows a title.
- **Discovery** allows deliberate catalog exploration without becoming Home.
- **Watchlist** preserves future intent and informs recommendations.
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
- `Not tonight`, `Not interested`, and `Already watched` rates
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
- local watchlist and watched state
- a stubbed free-text Ask experience

It does not yet deliver the target first product version described here.
Specifically, onboarding, taste calibration, subscription-aware regional
eligibility, persistent “Three for Tonight,” explicit decision feedback, and
trailer presentation remain product work.

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
  Disney Plus `337`, and HBO Max `1899`, presented to the user as HBO Max.
- The pilot entitlement maps Netflix's highest plan to provider `8` and
  ad-free Prime Video to provider `119`.
- Onboarding asks for supported services, not plan variants. The known pilot
  entitlements are mapped internally; plan selection remains deferred until it
  materially and reliably changes availability.
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

## Open Product Questions

These require explicit product decisions before their related implementation:

1. What exact title set and selection logic should calibrate initial taste?
2. What confirmation language best distinguishes intent to watch from verified
   viewing?
3. Which deterministic scoring and diversity rules produce the first
   personalized recommendation set?

Open questions are not permission for implementation agents to invent behavior.
They must be resolved in product steering or explicitly bounded by a milestone.

## Related Documents

- [`docs/milestones/milestone-4-availability-foundation.md`](docs/milestones/milestone-4-availability-foundation.md)
  is the active specification for availability behavior.
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

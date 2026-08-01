# Milestone 4 — Availability Foundation

## Status

Accepted — Ready for implementation

## Identifiers

- Backlog: `IMP-009`
- Architecture: [ADR-009](../decisions/adr-009-availability-boundary-verification.md)
- Research:
  [SPIKE-001 findings](../research/tmdb-es-streaming-availability-findings.md)
- Product authority: [`PRODUCT.md`](../../PRODUCT.md)

## Goal

Make Spain-specific subscription availability a trustworthy, observable
product capability before Onboarding and Three for Tonight.

At the end of this milestone, Movie Detail independently shows every selected
pilot service on which TMDB currently reports the movie under `ES.flatrate`,
distinguishes confirmed ineligibility from unknown evidence, attributes
JustWatch, and offers a clearly secondary TMDB regional watch-page handoff.

## User Outcome

The Product Owner can open an existing Movie Detail on the pilot iPhone and see
where the movie is reported as included without tapping to discover that
information or waiting for availability before the rest of Detail becomes
usable.

## Current Baseline

- Movie Detail loads movie metadata, similar movies, credits, and local
  watchlist state.
- The detail view uses a single screen-level loading/error state.
- TMDB access, image loading, actor-isolated memory caching, strict Swift 6
  concurrency, and app composition already exist.
- Detail does not request, model, cache, or display watch-provider evidence.
- About contains the required TMDB notice but no JustWatch attribution.
- No viewer profile or service-selection persistence exists yet.

## Accepted Product Decisions

### Pilot context

Milestone 4 uses one immutable context injected by `AppContainer`:

| Service | TMDB provider ID | Product order |
| --- | ---: | ---: |
| Netflix | `8` | 1 |
| Amazon Prime Video | `119` | 2 |
| Disney Plus | `337` | 3 |
| HBO Max | `1899` | 4 |

The active region is Spain (`ES`). All four services are selected for the
Product Owner's current pilot context. This is not persisted and is not exposed
as onboarding or settings UI. Milestone 5 later supplies the same context from
the local profile.

### Domain outcomes

Every completed availability check returns one of three semantically distinct
outcomes:

#### `eligible`

Current valid `ES` evidence contains one or more selected and allowlisted
provider IDs exactly under `flatrate`.

The result includes every matching provider, deduplicated by ID and sorted in
the product order above.

#### `ineligible`

A valid, decoded `ES` evidence block exists, but no selected and allowlisted
provider occurs under `flatrate`.

This includes a selected provider appearing only under `rent`, `buy`, `ads`, or
`free`, and an `ES` response containing only unselected, non-allowlisted, store,
or add-on providers.

#### `unknown`

PickOne cannot obtain or verify valid evidence for Spain. This includes:

- no `ES` entry
- transport, timeout, or server failure
- invalid or undecodable response
- structurally invalid `ES` evidence

Unknown is not ineligible. It fails closed for future recommendation eligibility
but must be presented as an inability to verify.

Task cancellation propagates and publishes no new availability outcome.

### Exact eligibility rule

```text
eligible(movie, context)
    only if verifiedEvidence.results.ES exists
    and at least one context.selectedProviderID
        occurs exactly in verifiedEvidence.results.ES.flatrate
    and that provider ID is in the pilot allowlist
```

Discover responses, provider names, `display_priority`, logo paths, and entries
under other monetization arrays are never final proof.

A selected provider found under both `flatrate` and another monetization array
is eligible because the exact `flatrate` requirement is satisfied.

## User Experience

### Independent loading

Movie Detail and movie availability start loading concurrently.

The existing Detail state continues to own the screen-level movie content.
Availability uses a separate presentation state:

- `loading`
- `eligible(providers)`
- `ineligible`
- `unknown`

Availability must not be added to a coordinated snapshot or task group that
forces Detail to wait for it.

Behavior:

- Detail may render while only the availability section remains loading.
- A Detail error retains the existing screen-level behavior.
- An availability error does not replace loaded Detail content with an error.
- Reloading Detail starts a new availability attempt.
- Leaving Detail cancels outstanding work.
- A late result for another movie or superseded load is ignored.

### Section placement and copy

Place the availability section in the primary Detail content before supporting
content such as similar movies.

All new user-facing copy remains in English to match the current application.

#### Loading

- Title: `Available on`
- Body: a compact placeholder or progress indicator contained only inside the
  section
- Do not show an unavailable or unknown message before the check completes.

#### Eligible

- Title: `Available on`
- Body: logos for every verified selected provider
- Secondary text:
  `Availability data from JustWatch · may change`

Provider logos:

- are deduplicated and shown in the fixed product order
- are not buttons or links
- have the service name as their accessibility label
- use the existing image pipeline and TMDB image base
- fall back to the product-facing service name when the logo path is missing,
  invalid, or fails to load

Logo failure never changes an eligible result.

#### Ineligible

- Title: `Available on`
- Body: `Not shown as included with your services.`
- Secondary text:
  `Availability data from JustWatch · may change`

#### Unknown

- Title: `Available on`
- Body: `We couldn't verify availability.`
- Do not imply that the movie is unavailable.

### Attribution

The brief JustWatch attribution appears with every eligible or ineligible
availability result. Unknown has no verified source data and therefore does not
need the brief source line.

About retains the approved TMDB logo and notice and adds this visible text:

> Streaming availability data is provided by JustWatch.

No new analytics, tracking, or direct JustWatch API integration is authorized.

## Secondary TMDB Handoff

Availability is visible without interaction. Handoff is a separate, secondary
capability.

When valid eligible evidence contains a valid regional TMDB watch URL, show a
discrete text action below the availability information:

> View playback options on TMDB

Rules:

- provider logos remain non-interactive
- use the exact URL returned in the movie-level `ES` response
- never build, infer, normalize into, or claim a Netflix, Prime Video, Disney+,
  or HBO Max URL
- accept only an HTTPS URL whose host is `www.themoviedb.org` or
  `themoviedb.org`
- do not alter its path or query
- hide the action when the URL is absent or invalid; availability may remain
  eligible
- the label must identify TMDB so the action cannot be mistaken for direct
  playback

### Freshness before handoff

- Evidence is current through 24 hours from `verifiedAt`.
- If its age is no more than 24 hours, open its exact TMDB URL.
- If its age is greater than 24 hours, synchronously reverify before opening.
- When revalidation remains eligible, open only the new returned TMDB URL.
- When the provider disappears, publish `ineligible` and do not open a URL.
- When revalidation becomes unknown, publish `unknown` and do not open a URL.
- Revalidation cancellation opens nothing and publishes no replacement state.

The URL opener is injected or otherwise testable. Automated tests must not open
Safari or perform a real external navigation.

## Architecture

The implementation follows
[ADR-009](../decisions/adr-009-availability-boundary-verification.md) and
preserves `Presentation → Domain ← Data`.

### Domain

Add small `Sendable` value types for:

- viewing region
- selected pilot provider/service
- provider offer evidence
- verified availability evidence with `verifiedAt`
- availability outcome and unknown reason
- explicit availability fetch policy

Add a dedicated `AvailabilityRepository` protocol. Do not add availability
methods to `MovieRepository`.

Provide use-case boundaries equivalent to:

- get/check movie availability for a movie and viewing context
- prepare the secondary playback-options handoff, including required
  revalidation

Exact type names may follow repository conventions, but the distinct behaviors
must not be collapsed into Presentation or Data.

Domain owns:

- allowlist and selected-provider comparison
- exact `flatrate` eligibility
- tri-state outcome
- product ordering and deduplication
- freshness decision
- revalidation-before-handoff orchestration

### Data

Add a focused TMDB availability client and DTOs for:

```text
GET /3/movie/{movie_id}/watch/providers
```

Use the existing authenticated `HTTPClient`; add no dependency.

The DTO layer must decode:

- country-keyed results
- regional `link`
- `flatrate`, `rent`, `buy`, `ads`, and `free`
- provider ID, name, and optional logo path

Data maps valid `ES` evidence into Domain values and owns the actor-isolated
memory cache.

Rules:

- a missing optional monetization array inside an otherwise valid `ES` block is
  treated as empty
- malformed types or structurally invalid evidence produce an error that Domain
  maps to unknown
- a missing `ES` entry produces no verified evidence and maps to unknown
- no DTO enters Domain or Presentation
- no unknown result is cached
- no `verifiedAt` is stored separately from evidence

### Cache

- memory only
- actor-isolated and compiler-checked under Swift 6
- key: movie ID plus region
- value: complete verified regional evidence
- TTL: 24 hours
- clock: injected for deterministic tests
- fresh evidence may be reused without a request
- stale evidence requires a synchronous source verification before it can be
  treated as current
- app relaunch creates an empty cache and therefore a new request on first need

Do not change the stale-while-refresh behavior of existing movie caches.

### Presentation

`MovieDetailViewModel` receives availability use cases through explicit
injection and exposes an availability-section state independent from
`MovieDetailViewState`.

The implementation must:

- start Detail and availability work concurrently
- preserve the current Detail success and failure behavior
- guard against stale responses and cancellation
- map Domain provider values to presentation models and logo URLs
- keep SwiftUI independent of repositories, DTOs, and TMDB response details
- use the existing `ImagePipeline`

Do not introduce a service locator or allow the view to call a repository.

## In Scope

- dedicated availability Domain models, repository contract, and use cases
- TMDB movie watch-provider client, DTOs, mapping, repository, and memory cache
- immutable pilot availability context injected at composition
- exact `ES.flatrate` eligibility and tri-state result
- independent Movie Detail loading and presentation
- multiple-provider logos, fallback names, copy, and accessibility
- brief JustWatch attribution and full About attribution
- secondary TMDB regional handoff with freshness-aware revalidation
- unit, presentation, repository, client/DTO, cache, and relevant UI tests
- physical-device validation instructions and PR evidence

## Explicit Non-Goals

- onboarding, settings, or editable provider selection
- persistence of profile, availability evidence, or `verifiedAt`
- TMDB Discover candidate generation
- Decision Engine, Three for Tonight, or recommendation-card changes
- changes to Ask, Search, Discovery, Watchlist, credits, or similar-movie
  behavior except dependency wiring required to open Detail
- backend, AI, authentication, account, or sync work
- direct JustWatch API integration or partnership
- direct provider deep links or provider-logo interaction
- TV availability
- plan-variant UI
- localization of the current application
- analytics or operational event tracking
- generalized multi-source availability abstraction
- new third-party dependencies
- broad architecture, navigation, or cache refactors

## Error, Empty, and Cancellation Behavior

| Condition | Domain outcome | Detail presentation |
| --- | --- | --- |
| Selected allowlisted provider in `ES.flatrate` | Eligible | All matching logos |
| Valid `ES` evidence without a matching provider | Ineligible | Ineligible copy |
| Selected provider only in `rent`, `buy`, `ads`, or `free` | Ineligible | Ineligible copy |
| Only add-on, store, non-allowlisted, or unselected providers | Ineligible | Ineligible copy |
| `ES` key absent | Unknown | Unknown copy |
| Network, timeout, server, or decoding failure | Unknown | Unknown copy |
| Availability task cancelled | No completed outcome | No stale state update |
| Logo missing or image load fails | Outcome unchanged | Product name fallback |
| Eligible evidence lacks a valid TMDB URL | Eligible | Logos, no handoff |

No provider match is not an empty UI state; it is an explicit ineligible state
when valid regional evidence exists.

## Acceptance Criteria

### Domain and eligibility

- an exact selected provider under `ES.flatrate` produces eligible
- every exact selected provider under `ES.flatrate` is returned
- duplicate provider entries are collapsed by ID
- multiple matches use the fixed product order
- a provider under `flatrate` and another category remains eligible
- a selected provider found only under `rent`, `buy`, `ads`, or `free` produces
  ineligible
- an add-on or provider outside the allowlist cannot produce eligible
- a valid `ES` response without a selected provider produces ineligible
- an absent `ES` response produces unknown
- transport, server, and invalid-response failures produce unknown
- cancellation is propagated and does not become unknown or ineligible
- unknown fails closed when evaluated for future recommendation eligibility

### Cache and freshness

- valid eligible and ineligible evidence can be reused while no more than
  24 hours old
- evidence older than 24 hours is synchronously reverified before use where
  current proof is required
- unknown outcomes are not cached
- `verifiedAt` is stored only with its evidence
- the cache key separates movie and region but not provider selection
- changing selected services reevaluates the same fresh evidence
- a new repository after application relaunch has no evidence and performs a
  new request
- the 24-hour boundary is tested with an injected clock

### Movie Detail

- Movie Detail and availability begin concurrently
- Detail can render while availability remains loading
- availability failure leaves usable Detail content loaded
- the availability section shows its own loading state
- eligible shows every verified selected service
- ineligible and unknown show their distinct accepted copy
- provider logos are non-interactive and accessible by service name
- missing, invalid, or failed logo loading falls back to provider name
- late or cancelled work cannot update the wrong Detail
- About includes both the existing TMDB attribution and the accepted JustWatch
  attribution

### Handoff

- availability is visible without using the handoff
- only the exact valid regional TMDB URL returned by the API can be opened
- no provider URL is constructed or inferred
- the action is labelled `View playback options on TMDB`
- missing or invalid URL hides the action without changing eligibility
- fresh evidence opens without an unnecessary revalidation
- evidence older than 24 hours is revalidated before opening
- provider disappearance during revalidation prevents opening and publishes
  ineligible
- source failure during revalidation prevents opening and publishes unknown
- a successful revalidation opens only the newly returned URL

## Required Automated Tests

At minimum, add deterministic tests for:

1. DTO decoding for complete, missing-array, missing-`ES`, and invalid fixtures.
2. Data mapping of every monetization array and regional URL.
3. Repository fresh-cache hit, stale-cache reload, unknown non-caching, cache
   key isolation, and in-flight request behavior.
4. Domain eligibility, multiple providers, ordering, deduplication, non-allowed
   providers, category controls, missing region, and error mapping.
5. Freshness at below, equal to, and above 24 hours using an injected clock.
6. Handoff preparation for fresh, stale-still-eligible, stale-ineligible,
   stale-unknown, invalid URL, and cancellation.
7. Movie Detail ViewModel parallel loading, independent failure, retry,
   cancellation, and stale-response protection.
8. Presentation mapping for logos, fallback names, exact copy, and
   accessibility labels.
9. About attribution.

Use protocol-backed test doubles and URL loading interception. Tests must not
depend on the live TMDB catalog, real network, wall-clock waiting, or Safari.

## Required Validation

The implementation PR must pass:

```text
xcodebuild test \
  -project PickOne.xcodeproj \
  -scheme PickOne \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=latest' \
  -parallel-testing-enabled NO \
  -derivedDataPath /tmp/PickOne-M4-Tests \
  CODE_SIGNING_ALLOWED=NO

xcodebuild analyze \
  -project PickOne.xcodeproj \
  -scheme PickOne \
  -destination 'generic/platform=iOS Simulator' \
  -derivedDataPath /tmp/PickOne-M4-Analyze \
  CODE_SIGNING_ALLOWED=NO

xcodebuild build \
  -project PickOne.xcodeproj \
  -scheme PickOne \
  -configuration Release \
  -destination 'generic/platform=iOS' \
  -derivedDataPath /tmp/PickOne-M4-Release \
  CODE_SIGNING_ALLOWED=NO

Scripts/check-secrets.sh

Scripts/inspect-app-bundle.sh \
  /tmp/PickOne-M4-Release/Build/Products/Release-iphoneos/PickOne.app

git diff --check
```

CI must pass on the final PR. No live TMDB credential may appear in tests,
fixtures, logs, source, tracked configuration, or PR text.

## Physical-Device Validation

After automated validation passes, the Product Owner validates on the pilot
iPhone:

1. Open several Movie Details and confirm the screen remains usable while the
   availability section loads.
2. Confirm eligible movies show the correct service logos and JustWatch caveat.
3. Confirm a movie reported on more than one selected service shows every
   matching logo.
4. Confirm provider names remain understandable if a logo cannot load.
5. Confirm an unavailable or unverifiable result uses the correct distinct
   copy.
6. Confirm provider logos do nothing when tapped.
7. Confirm `View playback options on TMDB` opens a TMDB Spain watch page rather
   than implying or opening a provider deep link.
8. Relaunch the app and confirm availability is fetched and displayed normally
   with an initially empty memory cache.
9. Smoke-test Discovery, Search, Detail navigation, Watchlist, and Ask for
   regressions.

Catalog availability can change, so the PR must record the titles and observed
providers used during device validation rather than encode them as permanent
expectations.

## Rollout and Compatibility

- no runtime feature flag is required for the household pilot
- no persistent format or migration is introduced
- failure degrades only the availability section to unknown
- existing features remain usable when the availability endpoint fails
- removal can be limited to the new section and availability composition
  without modifying existing stored user data

## Privacy and Security

- use only the existing injected TMDB credential path
- never commit, log, or display the credential
- do not add analytics or send viewer state to a new party
- transmit only the movie ID required by the existing TMDB endpoint
- open only validated HTTPS TMDB URLs returned by the API
- do not scrape JustWatch or use unofficial endpoints
- preserve TMDB and JustWatch attribution

## Implementation Order

1. Add Domain values, outcome, repository contract, context, clock boundary, and
   eligibility tests.
2. Add TMDB client/DTO decoding and evidence mapping tests.
3. Implement the actor-isolated availability repository and freshness tests.
4. Implement availability and handoff use cases.
5. Wire the immutable pilot context in `AppContainer`.
6. Add independent Movie Detail state, mapping, UI, accessibility, and
   attribution.
7. Complete cancellation, stale-response, handoff, and regression tests.
8. Run every required local gate and record results in the PR.

## Agent Constraints

The implementation agent must:

- treat this specification, ADR-009, `PRODUCT.md`, and `AGENTS.md` as
  authoritative
- keep all work on `feature/milestone-4-availability-foundation`
- use only `Cesar-IA-Agent` for commits, push, and the final PR
- preserve strict Swift 6 concurrency without unchecked sendability
- make no product-copy, state, freshness, provider, or handoff decision beyond
  this specification
- avoid unrelated cleanup, including the known Movie Detail domain
  reconstruction backlog item
- add no dependency, backend, persistence, onboarding, recommendation engine,
  or provider abstraction
- stop and request steering if TMDB response behavior makes an accepted state
  impossible or ambiguous

## Pull Request Handoff

The final implementation PR must include:

- summary of the complete vertical slice
- link to this milestone, ADR-009, IMP-009, and SPIKE-001
- architecture and concurrency notes
- exact automated commands and results
- CI status
- known limitations
- titles/providers proposed for physical-device validation
- confirmation that no real credential or direct provider URL was introduced
- explicit list of deferred Onboarding, Decision Engine, backend, AI, and
  persistence work

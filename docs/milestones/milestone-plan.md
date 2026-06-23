# PickOne Milestone Plan

## Milestone 0

Status: completed

Included:

- project setup
- networking foundation
- DTOs
- repository infrastructure
- image pipeline
- initial tests

## Milestone 1

Status: completed

Included:

- top rated discovery feed
- movie detail
- similar movies
- credits
- in-memory cache
- partial failure degradation
- tests

Policies locked in this phase:

- detail failure shows an error
- similar failure hides similar content but keeps detail
- credits failure hides credits but keeps detail

## Milestone 2

Status: completed

Included:

- watchlist
- watched state
- search
- search history
- main tab navigation

Policies locked in this phase:

- watchlist ordering is most recent first
- no drag and drop reordering
- persist minimum `MovieSummary` data locally
- search history stays separate from watchlist persistence

## Milestone 3

Status: completed

Objective:

Introduce conversational recommendations on top of the existing layered architecture.

Entry criteria:

- project docs exist and are current
- root `.cursor` structure exists
- AI scope is defined narrowly
- backend or proxy boundary is agreed before real provider integration

Suggested delivery order:

- define recommendation MVP contract
- add domain repository protocol and use case
- add fake or stub implementation for iteration
- add data integration
- add presentation flow and tests

Suggested PR sequence:

- PR 1: product and backend contract docs
- PR 2: domain models, repository protocol, and use case
- PR 3: fake repository plus view model and screen state
- PR 4: backend client, repository implementation, and integration
- PR 5: polish, tests, and failure handling

Delivered:

- recommendation MVP contract and architecture notes
- `RecommendationRepository` domain boundary and `GetChatRecommendations` use case
- `StubRecommendationRepository` as the active iteration source
- Ask tab recommendation flow and navigation to movie detail
- add-to-watchlist support from recommendations
- enrichment of recommendation candidates through `MovieRepository`
- protection against out-of-order recommendation responses in the view model
- targeted unit coverage for domain, data, and presentation layers

Notes:

- Milestone 3 shipped with a local stub/mock source only
- no backend, authentication, or deployment infrastructure was introduced
- recommendation candidates are treated as source data and resolved through the movie domain layer before display

## Milestone 3.2

Status: planned

Objective:

Polish the recommendation experience and close the remaining UX gaps before introducing any real backend integration.

Scope:

- improve Ask screen onboarding and empty-state guidance
- add suggested starter prompts for faster first use
- tighten recommendation-specific copy for loading, empty, and failure states
- review recommendation card polish without changing the current architecture
- keep the stub/mock recommendation source as the active implementation

Out of scope:

- real backend or proxy integration
- authentication
- streaming responses
- multi-turn chat memory
- recommendation history
- provider-specific controls

Success criteria:

- a first-time user understands what to ask without guessing
- empty and error states feel intentional and actionable
- the recommendation flow remains fast and deterministic with the local stub
- no architecture boundary regressions are introduced while polishing UX

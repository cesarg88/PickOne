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

Status: planned

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

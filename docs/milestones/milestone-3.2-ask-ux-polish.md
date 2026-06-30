# Milestone 3.2 — Ask UX Polish

## Status
Complete / Merged

## Goal
Polish the Ask recommendation experience so the stubbed flow is clearer and more usable before the project moves into Intelligence work.

## Delivered Scope

- clearer onboarding copy in the Ask composer
- suggested prompts for idle, loading, empty, and error states
- improved loading, empty, and error messaging
- lightweight loaded-state summary treatment
- light recommendation card polish
- view model helpers for prompt submission and loading state
- protection against cleared state being overwritten by stale in-flight requests
- targeted `RecommendationViewModel` test updates

## Important Decisions

- keep the existing stub/mock recommendation source
- improve usability without introducing infrastructure
- maintain the current architecture and recommendation enrichment rules

## Out of Scope

- real backend or proxy integration
- authentication
- streaming responses
- multi-turn memory
- recommendation history
- provider-specific controls

## Notes / Follow-ups

Recommendation Strategy v1 has been accepted.
The next phase of the project moves into Intelligence, beginning with Decision Engine v1.

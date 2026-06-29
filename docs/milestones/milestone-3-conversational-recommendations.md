# Milestone 3 — Conversational Recommendations

## Status
Complete

## Goal
Introduce a first usable recommendation flow that helps users decide what to watch from natural-language prompts.

## Delivered Scope

- recommendation MVP contract docs
- recommendation repository boundary in Domain
- `GetChatRecommendations` use case
- stub recommendation repository for iteration
- Ask tab screen and state model
- recommendation cards with reasons
- navigation from recommendation to detail
- add-to-watchlist from recommendations
- targeted tests

## Important Decisions

- keep recommendation scope narrow and UX-first
- use a local stub/mock source rather than real backend integration
- keep app architecture decoupled from provider-specific assumptions

## Out of Scope

- real backend or proxy implementation
- authentication
- streaming responses
- multi-turn memory
- recommendation history

## Notes / Follow-ups

- Milestone 3 established the recommendation feature as a real product surface without committing to infrastructure yet

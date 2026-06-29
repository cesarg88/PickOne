# PickOne MVP Scope

## Goal

Ship a realistic first version of PickOne with clear movie discovery, list management, search, and a narrow AI recommendation flow.

## In Scope

- discovery feed based on TMDB top rated content
- movie detail with similar movies and credits
- watchlist with watched and to-watch sections
- local persistence for watchlist and search history
- search with pagination and history
- conversational recommendation MVP

## AI Recommendation MVP

- user provides a natural language prompt
- system returns a short set of movie recommendations
- each recommendation includes a reason
- recommendations resolve to TMDB-backed movie summaries where possible
- the current MVP uses a local stub/mock recommendation source
- a backend/proxy may be introduced later after Recommendation Strategy v1
- failures degrade clearly without breaking the rest of the app

## Out of Scope

- accounts and sync
- custom rankings and collaborative filtering
- manual watchlist reordering
- push notifications
- social sharing
- advanced analytics infrastructure
- disk cache for general app content

## Quality Bar

- layered architecture remains intact
- changes come through small PRs
- business logic is unit tested
- presentation state is explicit
- secrets stay out of tracked files

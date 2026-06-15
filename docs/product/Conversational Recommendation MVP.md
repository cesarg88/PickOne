# Conversational Recommendation MVP

## Goal

Help the user go from "I do not know what to watch" to a short, actionable set of movie options with minimal effort.

## User Problem

Search works when the user already knows what they want.

The conversational flow exists for the opposite case:

- the user has a mood, not a title
- the user wants a small curated answer, not a large result list
- the user benefits from short reasoning behind each suggestion

## Primary User Story

As a user, I can describe what I feel like watching in natural language and receive a short list of movie recommendations with simple reasons, so I can decide faster.

## MVP Input

One free-text prompt, such as:

- "I want a smart sci-fi movie like Arrival"
- "Something funny but not dumb"
- "A thriller from the 90s"

## MVP Output

The system returns:

- 3 to 5 recommendations
- one short explanation for the overall set
- one short reason per movie
- enough TMDB-linked movie data to open detail or save to watchlist

## UX Constraints

- keep the result set small
- prefer confidence and clarity over quantity
- show recommendations as a list of concrete movie cards
- allow the user to open detail directly from a recommendation
- allow the user to add a recommendation to the watchlist

## Failure Behavior

### Request Failure

- show a clear error state
- preserve the user's prompt for retry

### Partial Resolution Failure

If the backend returns recommendation text but cannot resolve some movies to TMDB IDs:

- show only the successfully resolved recommendations
- if none resolve, show an error instead of text-only results

## Out of Scope

- follow-up chat threads
- multi-turn memory
- streaming responses
- recommendation history
- personalization based on user profile
- provider-specific tuning controls in the UI

## Acceptance Criteria

- the user can submit a natural-language prompt
- the app returns 3 to 5 TMDB-backed recommendations when successful
- each result includes a reason
- the user can navigate to detail from a recommendation
- the user can add a recommendation to the watchlist
- failures are explicit and do not affect the rest of the app

## Suggested First Screen State Model

- idle
- loading
- loaded
- empty
- error

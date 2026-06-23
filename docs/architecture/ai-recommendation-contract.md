# AI Recommendation Contract

## Decision

PickOne will not call an AI provider directly from the iOS app.

The app will call a backend or proxy owned by PickOne. That backend is responsible for:

- holding provider credentials
- prompt orchestration
- recommendation generation
- resolving or validating TMDB movie identities

## Why

- app-bundled secrets are not acceptable
- provider logic will change more often than app release cycles
- we need a stable contract between app and recommendation engine
- backend ownership keeps provider choice flexible

## App Boundary

The iOS app should see one recommendation endpoint and one response model.

The app should not know:

- which LLM provider is used
- prompt templates
- provider-specific token settings
- raw provider responses

## Proposed Endpoint

`POST /recommendations`

## Request

```json
{
  "query": "A tense sci-fi movie with emotional depth",
  "maxResults": 5
}
```

## Response

```json
{
  "recommendations": [
    {
      "id": 157336,
      "title": "Interstellar",
      "year": 2014,
      "reason": "Epic science fiction with strong emotional stakes."
    }
  ],
  "explanation": "These picks focus on ambitious science fiction with emotional weight."
}
```

## Contract Rules

- `maxResults` must be clamped server-side to the product range
- response should contain 3 to 5 items when successful
- each item should include a TMDB movie id when possible
- the app should treat missing or invalid IDs as unusable recommendations
- recommendation reasons should be short, displayable copy

## Domain Mapping

The backend response maps into:

- `ChatRecommendationSnapshot`
- `[Recommendation]`
- `MovieSummary` for each resolved movie

## Resolution Responsibility

Preferred approach:

- the backend returns TMDB IDs for final recommendations

This keeps identity resolution out of Presentation and avoids additional app-side search ambiguity.

## Error Model

At minimum, the app should handle:

- network failure
- timeout
- invalid response
- no resolvable recommendations

The recommendation flow should fail independently from discovery, detail, watchlist, and search.

## Caching

For MVP:

- no persistence required
- optional in-memory caching is acceptable only if it stays local to the recommendation flow

## Implementation Notes for the App

- keep the AI client behind a repository boundary
- do not expose DTOs outside Data
- return domain snapshots from use cases
- map snapshot to presentation state in the view model

## Current Milestone 3 Execution Mode

Until the recommendation UX is validated and the AI strategy is defined:

- use a local stub or mock as the recommendation source
- keep the existing contract unchanged
- do not add server infrastructure assumptions to the app
- do not add deployment, authentication, or provider dependencies yet

## Known Codebase Adjustment

The current `AIRecommendationClient` skeleton accepts an `apiKey`.

That is no longer the target architecture for production use. The client can remain as a generic backend client, but app-managed provider credentials should not be part of the final Milestone 3 implementation.

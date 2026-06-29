# PickOne Policies

## Development Policy

- Keep PRs small, reviewable, and milestone-scoped.
- Reuse existing patterns before introducing new structure.
- Prefer simple, teachable implementations over speculative abstractions.
- Respect the current documented product scope.

## Layering Policy

- Presentation uses use cases only.
- Domain owns orchestration and business rules.
- Data owns DTOs, persistence, clients, and repository implementations.
- DTOs never enter Domain.
- UI never talks directly to repositories.

## Cache Policy

- The current MVP cache is memory-only.
- General disk cache is out of scope until explicitly prioritized.
- Cache behavior should remain local to the relevant repository layer.

## Error and Degradation Policy

- Recommendation failures must not affect discovery, detail, watchlist, or search.
- Partial failures should degrade gracefully where product policy already allows it.
- If recommendation candidates cannot be resolved into usable movies, unresolved candidates are dropped.
- If no recommendation candidates can be resolved, the flow must show an empty/failure outcome rather than text-only recommendations.

## Recommendation Policy

- Recommendation outputs are candidates, not final display models.
- Candidates must be enriched through `MovieRepository` before becoming final recommendations.
- The active recommendation source remains a local stub/mock.
- Do not introduce backend, authentication, deployment, or provider integration without explicit approval.

## Secrets Policy

- Never commit real secrets.
- TMDB credentials must be injected through ignored xcconfig files or CI secrets.
- Secrets must not appear in source files, tracked configs, or shared schemes.
- Security-sensitive changes should be checked before commit.

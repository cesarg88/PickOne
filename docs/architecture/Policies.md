# PickOne Policies

## Development Policy

- keep PRs small and reviewable
- prefer simple implementations over speculative abstractions
- explain tradeoffs, especially when introducing new structure
- optimize for both product progress and learning value

## Testing Policy

- add or update tests when changing business logic
- favor unit tests for use cases, repositories, and view models
- broaden coverage when a change touches shared behavior
- do not add infrastructure-heavy tests without a clear need

## Dependency Policy

- default to Apple frameworks and standard library
- add external dependencies only with explicit justification
- avoid framework-driven architecture changes

## Secrets Policy

- never commit real secrets to tracked files
- inject TMDB credentials through ignored xcconfig files or CI
- never store secrets in shared Xcode schemes
- validate security-sensitive changes before commit

## Caching Policy

- current MVP cache is memory-only
- disk cache is out of scope until explicitly prioritized

## AI Policy

- AI features must be introduced behind clear architectural boundaries
- app code must not embed production AI provider secrets
- recommendation flows should degrade cleanly on partial failure
- prefer a backend or proxy boundary for AI provider access

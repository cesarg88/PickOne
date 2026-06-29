# Example Feature Plan

## Goal
Add a small user-facing feature without breaking existing architecture boundaries.

## Impacted Layers / Files

- Presentation: view, view model, presentation model
- Domain: use case and repository protocol if needed
- Data: repository implementation or mapper if needed
- Tests: view model and use case coverage

## Steps

1. Read the relevant docs and confirm scope.
2. Identify which layers need changes.
3. Implement the smallest viable change in dependency order.
4. Add or update tests for success and failure paths.
5. Summarize tradeoffs and out-of-scope items.

## Tests

- unit tests for new behavior
- async or cancellation tests where relevant

## Out of Scope

- unrelated refactors
- backend/provider decisions
- product scope expansion without approval

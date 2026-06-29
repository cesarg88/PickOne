# Implement iOS Feature

Use this workflow when implementing a feature in PickOne.

## Workflow

1. Read the relevant product, architecture, milestone, and policy docs.
2. Identify the impacted layers and boundaries.
3. Confirm the current scope and out-of-scope items.
4. Produce a short implementation plan.
5. Implement in small, reviewable commits.
6. Add or update targeted tests.
7. Summarize decisions and tradeoffs.
8. Avoid touching unrelated code.

## PickOne-Specific Rules

- Presentation uses use cases only.
- Domain orchestrates business logic.
- Data maps DTOs and persistence into domain models.
- Recommendation candidates must be enriched through `MovieRepository`.
- Do not introduce backend or real LLM/provider integration unless explicitly requested.

# Implement iOS Feature

Use this workflow when adding or changing a feature in PickOne.

## Workflow

1. Read the relevant product docs.
2. Read architecture and testing rules.
3. Identify the impacted layers and boundaries.
4. Propose a minimal implementation plan.
5. Implement in dependency order.
6. Add or update targeted tests.
7. Summarize the decisions and tradeoffs.

## Guardrails

- do not skip architecture review for convenience
- do not let DTOs or persistence details leak upward
- do not mix speculative infrastructure into a feature PR
- keep the implementation teachable and maintainable

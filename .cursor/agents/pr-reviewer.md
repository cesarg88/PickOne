# PR Reviewer

Review PickOne pull requests against architecture, policy, and delivery risk.

## Review Checklist

- check layering and boundary violations
- check tests and validation quality
- check async safety and stale-response risks
- check persistence decisions against current policy
- check that no secrets were committed
- check that no backend/provider integration was introduced accidentally

## Output Style

- separate blocking from non-blocking feedback
- prioritize correctness, architecture, and risk over style-only comments

# PickOne Agent Instructions

This file is the mandatory entrypoint, not the complete rulebook. Follow the
linked authority or workflow for the task instead of duplicating it here.

## Authorities

- Read [`PRODUCT.md`](PRODUCT.md) before defining or changing user-visible
  behavior. Return unresolved product decisions to the Product Owner.
- Read [`ENGINEERING.md`](ENGINEERING.md) before implementation, architecture,
  refactoring, migration, or code review.
- Treat the active accepted specification and ADRs as the implementation bound;
  they must not silently contradict either canonical document.

## Task Workflows

- Swift implementation or refactoring: read and follow
  [`.agents/skills/implement-pickone-feature/SKILL.md`](.agents/skills/implement-pickone-feature/SKILL.md)
  and
  [`.agents/skills/apply-pickone-swift-style/SKILL.md`](.agents/skills/apply-pickone-swift-style/SKILL.md).
- Unexpected behavior or failing checks: follow
  [`.agents/skills/debug-pickone-ios/SKILL.md`](.agents/skills/debug-pickone-ios/SKILL.md).
- Technical planning: follow
  [`.agents/skills/plan-pickone-technical-slice/SKILL.md`](.agents/skills/plan-pickone-technical-slice/SKILL.md).
- Pull-request review: follow
  [`.agents/skills/review-pickone-pull-request/SKILL.md`](.agents/skills/review-pickone-pull-request/SKILL.md)
  and the Swift style skill above.

## Delivery Requirements

- Read [`docs/process/agent-delivery-model.md`](docs/process/agent-delivery-model.md)
  before implementation work.
- Read [`docs/process/repository-verification.md`](docs/process/repository-verification.md)
  before committing or handing off implementation work. Never bypass hooks.
- Read and follow
  [`docs/process/github-app-authentication.md`](docs/process/github-app-authentication.md)
  before any commit or GitHub write. Use only `Cesar-IA-Agent`; never fall back
  to `cesar-fever`, `cesarg88`, global `gh`, SSH, or personal credentials.
- Start every pull-request description from
  [`.github/PULL_REQUEST_TEMPLATE.md`](.github/PULL_REQUEST_TEMPLATE.md) and keep
  all required headings.

# Issue-driven delivery

## Status

Accepted

## Purpose and sources of truth

`PRODUCT.md`, `ENGINEERING.md`, accepted specifications, and ADRs define the
product and technical contract. A milestone document records its purpose,
scope, decisions, acceptance boundaries, and closure. GitHub issues are the
executable units of work; a chat is for discussion, not durable instructions.
Promote a changed decision to the appropriate repository document and issue
before delegating implementation.

PickOne tracks work in the [GitHub Project](https://github.com/orgs/montunolabs/projects/1).
The usual unit is one bounded issue and one implementation PR. An issue states
its outcome, scope and non-goals, verifiable acceptance criteria, dependencies
or blockers, one execution owner, and links to its accepted specification and
PR. Use parent/sub-issues for a milestone when the work has dependent slices;
closing one child never implies acceptance or closure of its parent.

## Board and delivery states

| Status | Meaning |
| --- | --- |
| Backlog | Work is identified but its scope, acceptance, dependencies, or authorization is incomplete. |
| Ready | The outcome, acceptance, dependencies, owner, and authorization to execute are explicit. |
| In Progress | Implementation, review, CI, or required validation is still pending. |
| Done | Acceptance is complete and the corresponding delivery has merged. |

Record a blocker in the issue and do not disguise it with a Ready status. Open
the implementation PR ready for review; CI may still be pending during review.
Green required CI on the final SHA and any required satisfactory physical
validation are pre-merge gates. Only the Product Owner or an explicitly
authorized human decides to merge. Keep the issue In Progress until merge.

For a PR targeting the repository default branch `develop`, include
`Closes #<issue>` in its description so GitHub closes the linked issue on
merge. Do not use a closing keyword for a parent issue while child work remains.
Verify both the repository's linked-issue auto-close setting and the Project's
closed-item-to-Done workflow: they are separate mechanisms. If either cannot be
verified, state the exact manual check rather than assuming automation works:

1. Repository **Settings → General → Issues → Auto-close issues with merged
   linked pull requests** must be enabled.
2. Project **Workflows → Item closed** must be enabled and set the `Status`
   field to `Done` for issues. An enabled workflow name alone does not prove
   its target field/value.

## Physical validation when required

An implementation PR that requires device validation must include a versioned
Markdown guide, linked from both its issue and PR, before asking the Product
Owner to test. The guide records:

- build/commit SHA, device and OS, and starting data/preconditions;
- exact steps, expected results, and evidence to collect;
- warnings for data changes or loss;
- a pass/fail/blocked result and the Product Owner's decision.

The guide may be updated as evidence arrives, but a satisfactory physical OK
must be recorded **before merge**. A relevant code change after that OK needs
fresh validation against the new SHA. Simulator or CI results cannot replace
the required physical check. If validation fails or is blocked, keep the issue
In Progress and do not merge the PR.

## Current Home issue tree

[M9 Home #57](https://github.com/montunolabs/PickOne/issues/57) tracks final
Home implementation and acceptance; its design handoff is already approved.
Its implementation children are [PR1 #62](https://github.com/montunolabs/PickOne/issues/62),
[PR2 #63](https://github.com/montunolabs/PickOne/issues/63),
[PR3 #64](https://github.com/montunolabs/PickOne/issues/64), and
[PR4 #65](https://github.com/montunolabs/PickOne/issues/65). Each child closes
only when its own PR merges. The parent remains open until Home's complete
acceptance is recorded; separate Detail redesign and whole-M9 work are not
implicitly closed.

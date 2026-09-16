# Confirmation and provenance verification

## Scope and delivery state

Milestone 8 PR2 is authorized by the Product Owner on `2026-09-15` and starts
from latest `develop`, #51 (`d2a9197`). Read the
[PR1 validation record](pick-and-session.md),
[accepted milestone](../../milestones/milestone-8-pilot-measurement.md), and
[ADR-015](../../decisions/adr-015-local-decision-measurement-and-provenance.md).

PR2 implements only confirmation, optional satisfaction, durable provenance,
migration, pending access, and reconciliation. M8, ADR-015 implementation,
IMP-005, IMP-023, and the roadmap remain open. PR3 insights, aggregates,
Home/search evidence, export, pruning/deletion and PR4 final household pilot
closure are excluded, as are remote analytics and recommendation changes.

## Implementation boundaries

- Domain: confirmation scheduling and semantic commands extend Viewing Decision;
  `ConfirmViewingDecision` coordinates persisted stages across the two actors.
- Viewer Movie State: the existing reducer atomically adds watched/provenance;
  confirmation reaction uses the same reaction transition semantics. Provenance
  alone has no taste/eligibility impact. Mark unwatched removes it, and ordinary
  mark watched/rating never recreates it.
- Data: Viewer Movie State v4 preserves v3 snapshot ID, suppression epoch,
  profile/draft, all movie fields and migration record, assigning no provenance.
  Exact v3 bytes become the previous copy before replacement. v2 and original
  legacy upgrade paths remain supported. Recovery uses the existing exact-byte
  quarantine policy and never treats invalid bytes as an empty install.
- Viewing Decision v2 adds typed journals and confirmation outcomes, reading
  PR1 v1 records with absent confirmation data. Metadata remains outside this
  envelope and is joined through existing movie/state repositories.
- Applied-operation receipts are committed atomically in Viewer Movie State v4.
  They survive reaction edits, mark unwatched, and Reset preferences. Replaying
  an incomplete journal cannot restore a removed badge or overwrite a later
  reaction. Already-applied operations finish without metadata/network access.
- Presentation: a shared MainActor model presents inline Home confirmation,
  optional reactions, and manual access after three postponements in My movies.
  Loading or failure of measurement never replaces the core screen. Native
  buttons, scrollable compact content, and String Catalog English/Spanish copy
  preserve usable navigation at large text sizes.
- Composition owns concrete repositories. Confirmation metadata uses the
  existing cache policy and never starts a recommendation, candidate, provider,
  or analytics request. Watched/reaction commits invoke the existing Home
  reconciliation path; postponement and not-watched do not regenerate Home.

## Requirement traceability

| Accepted clause | Responsible boundary | Automated evidence |
|---|---|---|
| Exact 12-hour threshold; 24-hour postponement; third answer becomes manual | Viewing Decision reducer/projections | `ViewingConfirmationTests.eligibilityAndThreePostponements` |
| Not watched closes without changing movie state; duplicate postponement is idempotent | Semantic answer and repository separation | `ViewingConfirmationIntegrityTests.notWatchedAndPostponementNeverWriteViewerState` |
| Watched/provenance before optional reaction; no reaction inferred | Reducer and coordinator | `PickOneProvenanceTests`; `ViewingConfirmationPresentationTests.watchedOffersOptionalReactionAndNotNowPreservesProvenance` |
| Immutable historical reaction, independent from current reaction | Satisfaction journal and v4 receipts | `reactionSnapshotSurvivesLaterEditsAndUnwatchedNeverReplays` |
| Relaunch at every mutating journal boundary, including satisfaction | Previous/active failure injection; recreate both repositories and coordinator | `everyJournalWriteResumesAfterRecreation` |
| Viewer state write failure claims neither watched nor provenance | Atomic state reducer/store | `viewerWriteFailureNeverClaimsProvenance` |
| Later measurement failure never rolls back watched/provenance | Durable receipt and resumable journal | `replayAfterWatchedCommitDoesNotUndoUnwatched`; journal write matrix |
| v3 migration preserves existing fields and never infers provenance | Versioned coder/mapper and migration | `ViewingProvenanceMigrationTests.v3PreservesEveryFieldWithoutInferringProvenance` |
| Failed migration preserves exact active bytes and permits recreation/retry | Migration previous/active writes | `failedMigrationKeepsExactV3Bytes` |
| Provenance survives Reset preferences | Profile reducer and retained receipts | `resetPreferencesPreservesBadgeAndReceipts` |
| Direct rating/Already watched has no badge; unwatched hides badge | Existing reducer and My movies mapper | `directWatchedAndReactionHaveNoBadge`; `PickOneProvenanceTests` |
| Retry preserves operation identity and no false satisfaction success | MainActor model and persisted receipt | `failedAnswerIsRetryableAndNeverClaimsSuccess` |
| English/Spanish confirmation, optional step, badge, relaunch, large text | String Catalog and native SwiftUI views | `ViewingConfirmationInteractionTests` |
| Concurrent retries, cancellation before preparation, corrupt measurement, offline replay, PR1 v1 upgrade | Actor coordinator, receipt lookup, versioned envelope | `ViewingConfirmationIntegrityTests` |
| Closing either confirmation outcome immediately refreshes Home's Pick cache; old cancel/retry cannot target the closed decision; relaunch remains correct | Read-only refresh serialized with Pick actions; confirmation composition callback | `ConfirmationPickCacheTests` |
| Journal stages and immutable outcomes agree in both directions; contradictory active bytes are quarantined exactly and valid previous restored | Semantic envelope validation and existing recovery | `ConfirmationSemanticRecoveryTests`, including no-previous failure and valid superseded pending journals |
| Existing profile, Watchlist, Search History, recommendations and recovery | Unchanged authority boundaries plus current-schema fixtures | Full `make verify` regression suite, including existing M7 upgrade/recovery and PR1 suites |

## Validation

Focused command:

```sh
xcodebuild test -project PickOne.xcodeproj -scheme PickOne \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -parallel-testing-enabled NO -derivedDataPath .derivedData/Tests \
  -only-testing:PickOneTests/ViewingConfirmationTests \
  -only-testing:PickOneTests/PickOneProvenanceTests \
  -only-testing:PickOneTests/ViewingConfirmationRecoveryTests \
  -only-testing:PickOneTests/ViewingConfirmationIntegrityTests \
  -only-testing:PickOneTests/ViewingProvenanceMigrationTests \
  -only-testing:PickOneTests/ViewingConfirmationPresentationTests \
  -only-testing:PickOneTests/ConfirmationPickCacheTests \
  -only-testing:PickOneTests/ConfirmationSemanticRecoveryTests \
  -only-testing:PickOneUITests/ViewingConfirmationInteractionTests
```

The provenance test was added first and failed because the provenance value
and reducer transition did not exist. The initial separate-worktree build also
identified missing ignored local xcconfig files; those were copied from the
existing configured checkout without committing credentials.

The first full run exposed a Detail lifetime regression: rating a movie updated
Home and recreated the open Detail model, leaving its screen loading. Home now
owns that destination model for the navigation lifetime. The unchanged
`PickOneSmokeTests.testMilestone7EndToEndFlow` failed before the fix and passed
after it (focused run on `2026-09-15`).

PR review regressions were reproduced before the fixes: both not-watched and
watched left the cached active Pick intact, and the old card attempted stale
cancellation. Contradictory confirmation envelopes also bypassed quarantine.
The semantic cache refresh now reads the shared repository in the Pick action
queue without recording lifecycle/observation events. It clears stale failed
cancellation retries and runs after confirmation/recovery. Bidirectional journal
validation rejects impossible cancelled/not-watched pending operations and
completed satisfaction without its matching immutable reaction. Pending
operations for superseded Picks remain valid because the state machine can
produce them. Recovery tests cover exact quarantine bytes, previous-copy restore,
no-previous failure and repository recreation.

Final automated validation on `2026-09-16`:

- Full test suite: 605 unit tests in 114 suites and 8 UI tests passed on
  iPhone 17 Pro simulator, including existing PR1/M7 regression journeys.
- English and Spanish confirmation journeys verify the optional reaction/skip,
  separate badge, Accessibility XXXL layout, and persistence after relaunch.
- `make verify` passed: formatting, lint, repository checks, secret checks,
  full tests, Xcode static analysis, unsigned Release build and app-bundle
  inspection.

The required delivery gate is `make verify`. CI status is recorded with the
PR handoff; CI must be green on the final SHA before merge. Simulator checks
do not substitute for physical validation.

## Physical-device instructions for the Product Owner

Install over retained final-M7/PR1 data without deleting the app or its storage.
Record device, iOS version, app SHA, language, text size, date/time and outcome.

1. Before upgrading, record existing services/profile, rated and watched movies,
   Watchlist, Search History, and visible Home set. After upgrade/relaunch,
   confirm they survive and previously watched/rated movies have no new badge.
2. Pick a Home movie. Confirm it remains unwatched and its recommendation stays.
   Leave and relaunch before 12 hours: no prompt. Return to Home after 12 hours:
   see title and all three answers while normal navigation remains usable.
3. Choose Not yet. Return before and after 24 hours. Repeat three times; verify
   Home stops automatic prompting and My movies offers the pending choice.
   Resolve it there. Replaced/cancelled Picks must not prompt.
4. For another Pick choose I didn't watch it after all. Before navigating,
   verify the Home card immediately stops showing Picked and offers a new Pick
   instead of cancellation. Relaunch and verify no
   watched state, reaction, or PickOne badge was created by that answer.
5. Confirm watched and verify the old Pick action is cleared immediately.
   Choose Not now. Verify watched plus PickOne badge in
   My movies, with no reaction inferred; relaunch and check the same state.
6. Confirm another viewing and supply each optional reaction across separate
   journeys. Verify current reaction and badge are separate. Edit/remove the
   reaction afterward: retain the badge. Mark unwatched: hide it. Mark watched
   again directly: do not restore it.
7. Reset preferences on a disposable validation copy or only when intentionally
   ready to recalibrate: watched/provenance survive while reactions reset.
8. Repeat affected surfaces in English and Spanish, VoiceOver and the largest
   Dynamic Type size. Verify movie title context, answer discoverability,
   scroll reachability, optional-step skip, badge label and retry controls.
9. Interrupt/relaunch during confirmation and optional reaction saves. Verify
   eventual agreement and no duplicates. Deterministic automated failure
   injection supplies exact write-boundary coverage; manual timing cannot prove
   every interruption boundary.

Record actual results before merge. Do not claim physical validation from the
simulator. Report/export/delete and the final prolonged upgrade/pilot closure
belong to PR3/PR4 and are not instructions to add those behaviors in PR2.

# Pilot insights verification

## Scope and delivery state

The Product Owner authorized Milestone 8 PR3 on `2026-09-22`. This branch starts
from latest `develop`, PR2 #52 (`81fa448`). Authorities are the accepted
[Milestone 8](../../milestones/milestone-8-pilot-measurement.md),
[ADR-015](../../decisions/adr-015-local-decision-measurement-and-provenance.md),
and [PR2 validation record](confirmation-and-provenance.md).

This delivers only PR3: semantic Home/search evidence, derived pilot summary,
Settings presentation, local JSON export, retention and measurement-only deletion.
PR4 prolonged final-M7 upgrade/integration validation and milestone closure
were not authorized within PR3. PR4 is now separately authorized; its current
status is in [pilot-integration.md](pilot-integration.md). The PR3 runtime validation reported by the Product Owner
and the manual-check procedure are recorded below.
At the PR3 handoff M8 remained open. Final Product Owner acceptance was recorded
on `2026-10-03` in [PR4 integration](pilot-integration.md).

The [current coverage boundary](#current-coverage-boundary-2026-09-29) assigns
native Files save/cancel to physical checks and preserves app-owned automated
coverage. Earlier native Files UI results below are historical, not current tests.

## Implementation and metric definitions

- Domain derives the summary from retained records; no second summary store is
  introduced. Session Pick rate uses sessions with any Pick / all sessions.
  Confirmation rate uses confirmed watched / all Picks, including historical
  cancelled and superseded choices; the UI explicitly labels its denominator.
  Session-level confirmed counts are shown separately. Missing reactions remain
  unknown, and timing averages expose their sample counts and exclude unavailable
  values. First and final timing use the session's recorded first Pick and final
  decision identity; orphan recovered Picks never invent timing.
- Distinct movie IDs are unioned per observed session. Successful Home quick
  `Already watched` saves record a deduplicated session/movie pair. Direct rating,
  failed saves and other surfaces do not contribute. Attribution is captured in
  the existing observation queue before feedback, without delaying movie-state
  persistence; a later completion cannot move the action into a newer session. After inactivity,
  the still-visible Home is observed before attribution. Related Detail observes
  only its own movie, so a new session there does not invent sibling impressions.
- The existing coordinator diagnostics feed a typed local adapter. It records
  duration, highest expansion stage and semantic terminal outcome, adds no
  candidate/provider requests, and cannot change the recommendation result.
  Cancelled coordinator work emits no terminal diagnostic. Search evidence is
  bounded to the latest 1,000 retained records; the screen discloses this limit.
- Viewing Decision schema v3 adds only allowlisted semantic fields. Known v1/v2
  envelopes remain readable; sessions without prior observation evidence keep
  an unavailable denominator instead of receiving fabricated movie IDs or zero
  rates. Existing exact-byte quarantine and previous-copy recovery remain active.
- Schema v3 requires the `observedMovieIDs` key in each session. A migrated
  v1/v2 session is re-encoded with explicit JSON null, preserving unavailable
  evidence. Omitted v3 keys and wrong types quarantine the exact source bytes;
  recovery uses a valid previous copy or reports unavailable.
- Operation receipts carry their accepted wall timestamp. Timed retention drops
  unattributed receipts at 180 days, inclusive. Legacy unattributed receipts with
  neither a timestamp nor attribution are kept while any sessions, decisions or
  confirmation journals remain; only an empty retained history permits removal.
  Their missing attribution cannot prove that retained work no longer needs them. Receipts linked to retained sessions, decisions or
  search evidence keep their idempotency protection. Receipt-only pruning is
  persisted and sanitizes the previous envelope, including when triggered by an
  ordinary mutation. Export applies the same projection without writes.
- Retention and deletion run under the repository actor. Completed history is
  eligible at 180 days, inclusive. For a session with a later resolved outcome,
  completion is the later of session end and its decisions' last outcome change;
  a months-old pending Pick can still confirm and capture its optional reaction.
  Open sessions, active/postponed Picks and incomplete journals retain their
  complete dependent session/decision chain. Deletion starts a new envelope
  generation and uses a stable operation identity for retries.
- A complete candidate is validated before replacement. Lifecycle operations
  write the retained candidate to the previous copy before replacing active;
  failed replacement leaves the complete prior active source, and successful
  deletion/pruning cannot resurrect removed history through previous-copy recovery.
- Export builds a read-only JSON snapshot containing the retained allowlisted
  records and derived summary. Native file export is user-initiated; no server,
  analytics SDK, raw Search/Ask text, movie metadata or provider payload is added.
  The report distinguishes loading, empty, unavailable and action failure/retry.
- Composition supplies the shared actor. No measurement lifecycle API receives a
  reference to Viewer Movie State, Profile, Watchlist, Search History or Decision
  Sets. Durable provenance and current movie meaning remain under PR2's authority.

## Requirement traceability

| Accepted requirement | Boundary | Automated evidence |
|---|---|---|
| Exact funnel, optional satisfaction, unavailable first/final timing | Derived Domain summary | `PilotMeasurementTests.funnelTimingAndSatisfactionRemainDistinct` |
| Per-session distinct movie denominator and numerator | Session observation and semantic successful action | `observationsAndSuccessfulFeedbackAreDeduplicated` |
| Home success only, failure/retry, no rating attribution | Quick feedback callback | `HomeQuickFeedbackViewModelTests.onlySuccessfulAlreadyWatchedContributesEvidence` |
| Immediate/delayed feedback, inactivity and Detail-only observation | Existing observation queue and visible surface | `HomePickViewModelTests.immediateFeedbackWaitsForObservationAndKeepsOriginalSession`, `feedbackAfterInactivityObservesTheStillVisibleHome`, `relatedDetailRemainsVisibleThroughBackgroundAndOldSetBoundary` |
| Bounded search stage/outcome/time without activity side effects | Typed evidence reducer | `semanticSearchIsBoundedAndDoesNotChangeSessionTime`, `boundedSearchEvictsItsIdempotencyReceiptTogether` |
| Measurement adds no requests and failure cannot block recommendations | Existing coordinator diagnostic sink | `PilotSearchIntegrationTests` |
| Exact 180-day boundary, no recovery resurrection | Actor and active/previous persistence | `exactRetentionBoundaryAndRecoveryDoNotResurrectHistory` |
| Delete write failures, recreation, stable retry and new generation | Validated actor transaction | `failedDeletionPreservesCompleteStateAndRetryIsIdempotent` |
| Pending/manual/incomplete operations survive lifecycle; provenance survives deletion | Recreated repositories and confirmation coordinator | `deletionAndRetentionPreservePendingAndIncompleteConfirmationThenProvenance` |
| Old pending session can confirm and retain optional satisfaction | Terminal retention time | `PilotMeasurementLifecycleTests.oldPendingSessionCanStillCompleteAndCaptureOptionalSatisfaction` |
| Serialized and old-generation deletion retries | Actor isolation and durable deletion receipts | `concurrentDeletionRetriesLeaveOneValidGeneration`, `anOlderDeletionRetryCannotDeleteNewHistory` |
| Export is read-only with allowlisted records and exact summary | Data export projection | `exportIsReadOnlyAndContainsAllowlistedRecordsAndDerivedSummary` |
| Known-schema migration never invents earlier Home evidence | v3 mapper | `oldSchemaKeepsObservationRateUnavailable` |
| Missing v3 observation key differs from explicit migrated null | Presence-aware session DTO | `PilotMeasurementRecoveryTests.legacyObservationMigratesToExplicitNullAndSurvivesRelaunch`, `malformedObservationQuarantinesExactBytes` |
| Unattributed receipt retention, receipt-only persistence, export and recovery | Receipt timestamp and actor pruning | `receiptOnlyRetentionPersistsAndCannotRecoverExpiredReceipts`, `terminalReceiptExpiresAtBoundaryAcrossRelaunch` |
| Pruning write failures and retained-work protection | Previous/active transaction | `failedReceiptOnlyPruningPreservesActiveAndRetriesAfterRelaunch`, `retentionKeepsReceiptsForOpenWorkAndRetainedSearches` |
| Corrupt report/export/delete remains unavailable; never empty success | Existing recovery boundary | `corruptReportAndExportAreUnavailableWithoutOverwritingBytes`, `missingCurrentSchemaEvidenceIsNotInventedAsEmpty` |
| Unavailable/empty/retry/export cleanup/delete failure presentation | MainActor model | `PilotInsightsPresentationTests` |
| English/Spanish, deletion/relaunch, large text reachability and export-control accessibility | String Catalog and Settings screen | `PilotInsightsInteractionTests` (three independent tests; no Files navigation) |
| Native Files save, replacement and cancellation | Physical device/system picker | Explicit manual checks below; Product Owner runtime result recorded separately from automation |
| Existing movie/profile/Watchlist/Search History/Decision Set behavior | Separate authorities | Full `make verify` regression suite; exact Viewer State bytes checked across measurement deletion |

## Validation

The first focused test failed before implementation because the semantic action
and derived summary were absent. The later lifecycle test reproduced loss of an
old pending decision immediately after confirmation, and the immediate-feedback
test reproduced missed attribution before the first observation completed. Both
regressions were fixed at their responsible boundaries. Detail-only observation
and feedback at the inactivity boundary were also reproduced and corrected.
Current-schema missing evidence is quarantined rather than defaulted to zero.

The first full gate exposed older test assumptions: queued-Pick tests combined
1970 fixtures with the real clock, so their completed historical decision now
expired. They now inject the fixture clock while preserving all race assertions.
The Pick-only privacy test now rejects exact watched/current watch-state fields
while allowing the accepted `alreadyWatchedMovieIDs` semantic evidence.

Final delivery gate on `2026-09-22`: `make verify` passed (exit 0) using
Xcode 26.6 (17F113), iOS 26.5 Simulator, iPhone 17 Pro:

- SwiftFormat, strict SwiftLint, repository pre-commit checks and secret scan passed.
- 627 unit tests in 120 suites and all 10 UI tests passed.
- Static analysis, unsigned Release build and app-bundle inspection passed.
- Test result: `Test-PickOne-2026.09.22_20-54-45-+0200.xcresult`.

The final focused UI check also passed both journeys before the full gate:

```sh
xcodebuild test -project PickOne.xcodeproj -scheme PickOne \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -parallel-testing-enabled NO -derivedDataPath .derivedData/Tests \
  -only-testing:PickOneUITests/PilotInsightsInteractionTests
make verify
```

The native Files journey saves the exported document and handles replacement
when a previous test export exists; it does not depend on an optional filename
field. Both languages passed within the complete suite. Exported JSON was also
parsed to check its schema, timestamp, records and summary. English and Spanish
screenshots were inspected for wrapping and reachable controls at large text.
Physical-device results have not been claimed from simulator evidence.

## PR review follow-up

Both persistence review findings were reproduced with failing regression tests:
missing current-schema keys were accepted, migrated unknown evidence was omitted
on encoding, and unattributed receipts survived retention/export/recovery. The new
recovery suite covers v1/v2 migration, malformed current bytes with and without a
valid previous copy, the exact cutoff, receipt-only pruning from summary and
mutation, write failures, relaunch, read-only export and retained-work protection.

The reported Spanish Accessibility XXXL failure did not reproduce in the first
local run with an added hittability assertion. That run's screenshot showed both
actions at the end of the long report, dependent on List scroll position after
Files dismissal. A stronger no-swipe action-reachability test failed on that
layout. Export and Delete now sit in a persistent footer within the safe area, with multiline
Dynamic Type labels and the existing deletion confirmation. The List and footer occupy separate layout regions; metric scrolling is
scoped to the List so gestures cannot hit the controls. Both action-search swipe
loops are removed. The test asserts Delete is hittable before tapping and retains
a screenshot after Files export. CI uses Xcode 26.4.1; local evidence uses 26.6,
so this does not claim an exact reproduction of the hosted-runner failure.

Final follow-up validation on `2026-09-23`, Xcode 26.6 (17F113), iOS 26.5
Simulator, iPhone 17 Pro:

```sh
xcodebuild test -project PickOne.xcodeproj -scheme PickOne \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -parallel-testing-enabled NO -derivedDataPath .derivedData/Tests \
  -only-testing:PickOneTests/PilotMeasurementRecoveryTests \
  -only-testing:PickOneTests/PilotMeasurementPersistenceTests \
  -only-testing:PickOneTests/PilotMeasurementLifecycleTests \
  -only-testing:PickOneUITests/PilotInsightsInteractionTests
make verify
```

- Focused run: 17 unit tests in 3 persistence suites and both UI journeys passed.
  Result: `Test-PickOne-2026.09.23_01-35-05-+0200.xcresult`.
- Complete gate: 633 unit tests in 121 suites and all 10 UI tests passed;
  formatting, strict lint, secret scan, static analysis, unsigned Release build
  and bundle inspection passed (exit 0).
  Result: `Test-PickOne-2026.09.23_01-37-08-+0200.xcresult`.
- English and Spanish post-export screenshots were visually inspected. Both
  complete action labels fit, with report and footer in separate layout regions.
- GitHub CI and physical-device validation remain pending at handoff.

## Hosted CI export synchronization fix

The CI run [35798986224](https://github.com/cesarg88/PickOne/actions/runs/35798986224)
on `1483163` passed all unit tests but failed the Spanish XXXL UI assertion after
export. Its accessibility snapshot proves the Delete button was within the
screen at `y=635.7`, while `Browse View (Picker)` remained above it. Files had
replaced Save with an `En curso` activity indicator after confirming replacement.
The test incorrectly equated disappearance of Save with dismissal of the picker.
This evidence supersedes the earlier unconfirmed explanation based only on local
scroll screenshots; the fixed footer was present and correctly laid out in CI.

The test now checks that the underlying Delete action is not hittable while Files
is open, waits for the actual picker to disappear, then waits for Delete to become
hittable before retaining the screenshot and tapping. Both waits are bounded by
10 seconds and observe UI state; there is no sleep, swipe-count increase, skipped
assertion, or production behavior change.

Validation on `2026-09-23`, Xcode 26.6 (17F113), iOS 26.5, iPhone 17 Pro:

```sh
xcodebuild test -project PickOne.xcodeproj -scheme PickOne \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -parallel-testing-enabled NO -derivedDataPath .derivedData/Tests \
  -only-testing:PickOneUITests/PilotInsightsInteractionTests
make verify
```

- Both focused UI journeys passed, including replacement of an existing export
  and Spanish Accessibility XXXL. Result:
  `Test-PickOne-2026.09.23_09-54-41-+0200.xcresult`.
- Full gate passed: 633 unit tests in 121 suites, all 10 UI tests, formatting,
  strict lint, secret scan, static analysis, Release and bundle inspection.
  Result: `Test-PickOne-2026.09.23_09-56-37-+0200.xcresult`.
- The hosted-runner failure provides the failing evidence. Local runtime 26.5
  passes the corrected synchronization; the new hosted CI result is pending.

## Journal, legacy retry and counter integrity follow-up

The review of `ae8ad55` identified three additional persisted-data cases, each
reproduced by `PilotMeasurementIntegrityTests` before its fix:

| Requirement | Boundary | Regression evidence |
|---|---|---|
| Missing/null v3 confirmation journal is unavailable, never silently empty | Envelope v3 decoder | `missingCurrentJournalQuarantinesAndRecoversPendingWork`: exact-byte quarantine, previous-copy recovery retaining the prepared journal, no-overwrite unavailable path |
| Preserve v1/v2 compatibility and existing pending work | Known-schema migration | `legacyMissingJournalMigratesToExplicitEmptyArray`, `legacyPendingJournalSurvivesMigrationAndRelaunch` |
| Preserve unattributed undated v2 `notWatched` receipt while its decision remains | Timed retention projection | `legacyNotWatchedReceiptSurvivesSummaryMigrationRelaunchAndRetry`: first summary, v3 write, recreation, same-ID retry, byte stability, export, eventual safe pruning |
| Malformed persisted counters cannot trap summary/export | Envelope validation before publication | `overflowingPersistedCountersRecoverOrRemainUnavailable`: checked aggregate sums, exact bytes, previous recovery or unavailable for report and export |

Schema v3 now requires a non-null `confirmationOperations` array. Legacy schemas
retain their supported absent-array interpretation; existing v2 journals are
preserved on migration. No new schema version or PR4 behavior is introduced.

An unattributed legacy receipt without a timestamp may belong to any retained
terminal decision. It is conservatively kept while any sessions, decisions or
confirmation journals remain. Once none remain, the receipt can be pruned safely;
retained search receipts remain protected by search identity. Dated receipts
still use the accepted 180-day rule. This supersedes the earlier claim that
missing attribution alone allowed immediate removal.

The envelope validates refresh and postponement totals using
`addingReportingOverflow`, rejecting negative values, overflow and exhausted
integer capacity before publishing state. Invalid active bytes use the existing
quarantine/previous-copy/unavailable path before either summary or export.
A representable counter increment remains possible before the next candidate
validation; malformed persisted `Int.max` cannot reach a reducer increment.

The 2026-09-23 UI test stopped querying `Browse View (Picker)` or any other
Files-internal identifier. Export, Delete and confirmation use stable PickOne identifiers;
localized labels are separate assertions. After export, the test waits for the
PickOne Delete action to become hittable, retains the explicit hittability
assertion, and then taps. Native Save/Replace labels are used only to perform the
system export interaction, not as evidence that the app is interactive again.

Final validation on `2026-09-23`, Xcode 26.6 (17F113), iOS 26.5 Simulator,
iPhone 17 Pro:

```sh
xcodebuild test -project PickOne.xcodeproj -scheme PickOne \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -parallel-testing-enabled NO -derivedDataPath .derivedData/Tests \
  -only-testing:PickOneTests/PilotMeasurementIntegrityTests \
  -only-testing:PickOneTests/PilotMeasurementRecoveryTests \
  -only-testing:PickOneTests/PilotMeasurementPersistenceTests \
  -only-testing:PickOneTests/PilotMeasurementLifecycleTests \
  -only-testing:PickOneUITests/PilotInsightsInteractionTests
make verify
```

- Focused: 22 unit tests in 4 persistence suites and both UI journeys passed.
  Result: `Test-PickOne-2026.09.23_22-08-55-+0200.xcresult`.
- Complete gate: 638 unit tests in 122 suites, all 10 UI tests, formatting,
  strict lint, secret scan, static analysis, unsigned Release and bundle
  inspection passed (exit 0).
  Result: `Test-PickOne-2026.09.23_22-10-58-+0200.xcresult`.
- No physical-device or hosted CI result is claimed by this local validation.
  PR4 and milestone closure remain out of scope.

## UI responsibility separation (2026-09-28)

The hosted run [35915267520, job 107365038696](https://github.com/cesarg88/PickOne/actions/runs/35915267520/job/107365038696?pr=53)
on `7b25e08` passed its Spanish copy assertions and then failed waiting for the
Delete action at `PilotInsightsInteractionTests.swift:70`. Files still displayed
its in-progress overlay after Replace. Both language journeys exported the same
`PickOne-pilot-insights.json` into the shared local destination. Resetting the
PickOne fixture does not reset Files; inspection also found the existing export
in the simulator's local provider. Save disappearing did not establish that the
provider had finished or that the modal had closed. This was not a Spanish-copy
failure. The previous local green result did not exclude this shared-state path.

This follow-up changes UI tests only, with no production behavior change:

- Independent English and Spanish tests (Spanish at Accessibility XXXL) assert
  report/action copy, enabled and hittable footer controls, and an interactive localized delete
  confirmation. Neither enters Files or commits deletion.
- Exactly one export journey creates a UUID-named folder through Files under
  On My iPhone, then supplies a UUID filename. It selects the root explicitly,
  even when Files remembers an earlier folder. The helper resolves the simulator
  provider only after selecting that local location, so it does not require Files
  to have been opened previously. Existing exports are left intact; they cannot
  force the new invocation through Replace.
- Export completion requires PickOne's own Export action to become hittable and
  a complete schema-1 JSON report to exist at that exact destination. The test
  checks report keys, the fixture's session count and the single exported file,
  and attaches the JSON to its test result. Simulator provider inspection is
  read-only; all folder/file creation uses the native picker. This fixture is
  intentionally simulator-specific and does not claim physical-device coverage.
- Deletion starts with an explicitly completed not-watched decision, verifies
  confirmation, checks its report count changes from one to zero, then relaunches
  without resetting storage and checks zero again. It never enters Files.

Own controls use existing accessibility identifiers; the Settings tab is located
by its symbol identifier. Copy assertions are separate from action lookup. Native
picker IDs and its trailing Save action are encapsulated in the export helper;
Save/New Folder labels are explicit copy assertions, not completion signals.
The flow no longer branches on Save/Replace translations or waits for the
internal `Browse View (Picker)` label. No sleeps, increased timeouts, additional
search swipes or automatic retry-until-pass behavior are introduced.

Validation environment: Xcode 26.6 (17F113), iOS 26.5 Simulator, iPhone 17 Pro.
English, Spanish and deletion each ran in a separate invocation of the command
below. Export also ran alone, using the fresh-simulator command after the table:

```sh
xcodebuild test -project PickOne.xcodeproj -scheme PickOne \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -parallel-testing-enabled NO -derivedDataPath .derivedData/Tests \
  -only-testing:PickOneUITests/PilotInsightsInteractionTests/TEST
```

| `TEST` | Outcome | Result bundle |
| --- | --- | --- |
| `testExportCreatesOneFileInAnIsolatedDestination` | Passed on a fresh simulator | `Test-PickOne-2026.09.28_17-28-28-+0200.xcresult` |
| `testDeletionConfirmsAndRemovesCompletedMeasurementAfterRelaunch` | Passed | `Test-PickOne-2026.09.28_17-18-49-+0200.xcresult` |
| `testEnglishCopyAndAccessibleControls` | Passed | `Test-PickOne-2026.09.28_17-20-01-+0200.xcresult` |
| `testSpanishCopyAndAccessibleControlsAtAccessibilityXXXL` | Passed | `Test-PickOne-2026.09.28_17-20-30-+0200.xcresult` |

The export isolation check additionally uses a newly created iPhone 17 Pro:

```sh
EXPORT_SIMULATOR=$(xcrun simctl create PickOne-Export-Isolation \
  com.apple.CoreSimulator.SimDeviceType.iPhone-17-Pro \
  com.apple.CoreSimulator.SimRuntime.iOS-26-5)
xcodebuild test -project PickOne.xcodeproj -scheme PickOne \
  -destination "platform=iOS Simulator,id=$EXPORT_SIMULATOR" \
  -parallel-testing-enabled NO -derivedDataPath .derivedData/FreshExport \
  -only-testing:PickOneUITests/PilotInsightsInteractionTests/testExportCreatesOneFileInAnIsolatedDestination
```

The combined run on that simulator uses the same xcodebuild command with
`-only-testing:PickOneUITests/PilotInsightsInteractionTests`. It retains the file
from the isolated invocation. `make verify` then uses the repository's usual
simulator, which retains the earlier shared/default exports as well. The temporary
simulator was shut down and deleted after the focused checks; its JSON attachment
and result bundles remain in `.derivedData/FreshExport/Logs/Test`.

- Combined affected suite: all four tests passed, zero failures. Result:
  `Test-PickOne-2026.09.28_17-30-06-+0200.xcresult`.
- Full gate: `make verify` passed (exit 0): 638 unit tests in 122 suites, all
  12 UI tests, formatting/strict lint, secret scan, static analysis, unsigned
  Release and bundle inspection. Result:
  `Test-PickOne-2026.09.28_17-32-29-+0200.xcresult`.
- Hosted CI is not claimed green by these local results. This follow-up is handed
  off for another review without waiting for CI; PR4 remains out of scope.

## Current coverage boundary (2026-09-29)

The Product Owner explicitly directed removal of
`testExportCreatesOneFileInAnIsolatedDestination` and `PilotInsightsExportScenario`.
Both are deleted, not skipped or disabled. This supersedes the native Files UI
coverage described in the historical 2026-09-28 section above. No production
code, other UI tests, or existing unit-test assertions are removed or weakened.

On `944f1d8`, [hosted run 36445593923](https://github.com/cesarg88/PickOne/actions/runs/36445593923/job/109006965691)
passed 638 unit tests and 11 of 12 UI tests. The isolated export test failed at
`PilotInsightsExportScenario.swift:83`: after writing the new folder name and
sending a newline, `DOC.inlineRenameField` remained present beyond the five-second
nonexistence expectation. The test had not reached Save or Replace. English,
Spanish Accessibility XXXL and independent deletion passed. CI used Xcode 26.4.1 /
iOS 26.4; the earlier local green results used Xcode 26.6 / iOS 26.5. The log does
not establish whether focus, timing or platform behavior caused renaming to remain
active. There is no new workaround for Files navigation or timeout increase.

Current automated coverage remains at the application-owned boundaries:

- `PilotMeasurementPersistenceTests.exportIsReadOnlyAndContainsAllowlistedRecordsAndDerivedSummary`
  generates/parses the JSON, checks its exact top-level keys, derived summary,
  privacy exclusions, and unchanged active/previous persistence bytes. Schema
  version 1 and the fixture's session count 1 assertions move here from the
  removed native journey; the prior assertions are retained.
- Persistence/recovery/integrity tests retain unavailable/corrupt export,
  exact-byte preservation, receipt retention/relaunch/export and safe counter
  failure coverage.
- `PilotInsightsPresentationTests.unavailableIsNeverZeroAndRetryRecovers` retains
  preparation failure, error state, retry, prepared data and discard cleanup;
  the existing deletion failure/retry test remains unchanged. Discard cleanup
  tests the model boundary, not cancellation through the system picker.
- Three independent UI tests retain deletion confirmation, a completed count
  changing from one to zero and staying zero after relaunch, English/Spanish copy,
  enabled/hittable controls, and Spanish Accessibility XXXL. They use existing
  own-control identifiers and do not navigate Files.

Native saving and cancellation remain explicit manual checks below. The Product
Owner runtime result is recorded separately; automated green results do not claim
that either system-picker journey was exercised by a UI test.

Focused verification:

```sh
xcodebuild test -project PickOne.xcodeproj -scheme PickOne \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -parallel-testing-enabled NO -derivedDataPath .derivedData/Tests \
  -only-testing:PickOneTests/PilotMeasurementPersistenceTests \
  -only-testing:PickOneTests/PilotMeasurementRecoveryTests \
  -only-testing:PickOneTests/PilotMeasurementIntegrityTests \
  -only-testing:PickOneTests/PilotInsightsPresentationTests \
  -only-testing:PickOneUITests/PilotInsightsInteractionTests
make verify
```

- Focused checks passed: 20 unit tests in four suites and all three Pilot insights
  UI tests. Result: `Test-PickOne-2026.09.29_00-05-02-+0200.xcresult`.
- The first `make verify` passed 638 unit tests and 10/11 UI tests, including all
  three Pilot insights tests, then failed in the unchanged
  `ViewingConfirmationInteractionTests.testWatchedAndOptionalReactionInEnglish`
  at line 42 with an accessibility snapshot query timeout. Result:
  `Test-PickOne-2026.09.29_00-48-03-+0200.xcresult`. macOS power logs record
  Maintenance Sleep from 02:38:33 to 02:54:15 (942 seconds), coinciding with that
  test's jump from 2.93 to 942.47 seconds. Other tests also spanned system sleep.
  Analysis/Release were not reached in that invocation.
- After identifying system suspension, the unchanged confirmation test was run
  with `caffeinate -s xcodebuild test` and the same focused arguments, selecting
  `PickOneUITests/ViewingConfirmationInteractionTests/testWatchedAndOptionalReactionInEnglish`.
  The complete gate then uses `caffeinate -s make verify`. This AC-powered,
  command-scoped system-sleep assertion changes no repository tests, timeouts or
  permanent power settings. The unchanged focused confirmation test passed:
  `Test-PickOne-2026.09.29_03-21-25-+0200.xcresult`.
- Final `make verify` under the command-scoped sleep assertion passed (exit 0):
  638 unit tests in 122 suites, all 11 UI tests, formatting/strict lint, secret
  scan, static analysis, unsigned Release and bundle inspection. Result:
  `Test-PickOne-2026.09.29_03-22-07-+0200.xcresult`. The temporary sleep assertion
  ended with the command; no power assertion from this task remains.

Local environment: Xcode 26.6 (17F113), iOS 26.5 Simulator, iPhone 17 Pro. CI remains a separate merge gate;
this follow-up is handed off without waiting for CI. PR4 stays out of scope.

## Product Owner runtime validation (2026-09-29)

The Product Owner reports successful functional validation on a **clean install
on iPhone 18 Pro**, including export, languages/accessibility, confirmation and
deletion. `Already watched` preserves the other two movies. Selection-notice
layout shifts and abrupt transitions are deferred to the visual milestone.
This clarification supersedes the earlier unspecified-device account.

The Product Owner changed device and no longer has access to the previous
installation. No update over the retained final-M7 household installation was
performed. iOS version, installed SHA, precise execution date, language/text-size
settings, Files destination/provider and separate Replace/cancel outcomes were
not supplied; do not infer them from this aggregate report. The heading date is
the report record date, not verified execution metadata.

[PR4 integration](pilot-integration.md) records the controlled simulator update,
its limitations and the short remaining human checklist. Native Files UI
automation stays removed; reported export success is physical evidence, while
individual unreported picker paths remain unverified.

### Manual-check procedure retained for reference

Native Files saving and cancellation remain manual boundaries. The procedure
below describes the intended checks, not an additional per-scenario execution
record. The old installation is unavailable; use current test data and record device,
iOS, SHA, language, text size, date and outcome when adding detailed evidence.

1. Open Settings → Pilot insights in English and Spanish, with VoiceOver and the
   largest text size. Read all labels, sample counts, unavailable values and
   privacy/retention copy; reach export and deletion controls.
2. Make/replace/cancel Picks, confirm watched with and without a reaction, and
   postpone a pending Pick. Compare the report with the explicit actions.
3. Use Home Already watched once; verify a redraw does not inflate counts, and
   rating or watched from another surface does not change the Home metric.
4. **Native save:** record the completed report
   counts, open Export and save to a chosen local Files destination. Wait until
   PickOne is interactive again, open the saved JSON and compare schema, records
   and summary with the report. Confirm completed source history is unchanged.
   Repeat using an existing test export to exercise Replace; record whether the
   system picker finishes or remains in progress. Record destination/provider,
   device, iOS, SHA, language and outcome for each attempt.
5. **Native cancellation:** open Export and cancel
   in Files before saving. Confirm return to an interactive report, no new file
   at the selected destination, unchanged completed source history and no stale
   export error; reopen Export to check it can be prepared again. Record the same
   device/environment details. Model discard coverage does not replace this check.
6. Delete measurement after confirming a Pick. Verify eligible history is gone
   after relaunch while pending confirmations, current watched/reactions,
   PickOne badges, profile, Watchlist, Search History and Home recommendations
   remain intact. Active work may intentionally keep nonzero report counts.

This historical procedure is not a claim that every step was executed. PR4
[tracks the remaining checks](pilot-integration.md#remaining-human-checklist);
M8 closure was accepted by the Product Owner on `2026-10-03`.

## PR4 physical-validation follow-up (report received 2026-10-03)

The reviewing task relays César's report that the pending PR4 tests went well.
This is aggregate physical-validation evidence; it adds no verified iOS version,
installed SHA, Files provider or individual Replace/cancel/timing outcomes.
The clean-install result and controlled M7→M8 upgrade remain distinct from the
inaccessible former installation. [PR4 evidence](pilot-integration.md) records
technical approval and verified green CI for `f85804f`; PR #54's final
documentation SHA subsequently passed CI and merged. César stated “acepto el
cierre de M8” on `2026-10-03`, closing M8 with the documented evidence and
inaccessible-installation limitation. No further device metadata or individual
results are inferred.

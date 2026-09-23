# Pilot insights verification

## Scope and delivery state

The Product Owner authorized Milestone 8 PR3 on `2026-09-22`. This branch starts
from latest `develop`, PR2 #52 (`81fa448`). Authorities are the accepted
[Milestone 8](../../milestones/milestone-8-pilot-measurement.md),
[ADR-015](../../decisions/adr-015-local-decision-measurement-and-provenance.md),
and [PR2 validation record](confirmation-and-provenance.md).

This delivers only PR3: semantic Home/search evidence, derived pilot summary,
Settings presentation, local JSON export, retention and measurement-only deletion.
PR4 integration/physical validation and milestone closure are not authorized.
M8, ADR-015 implementation closure, roadmap, IMP-005 and IMP-023 remain open.

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
| English/Spanish, export, deletion, large text reachability | String Catalog and Settings screen | `PilotInsightsInteractionTests` |
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

The UI test no longer queries `Browse View (Picker)` or any other Files-internal
identifier. Export, Delete and confirmation use stable PickOne identifiers;
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

## Physical checks requested from the Product Owner

Use retained installed data, without deleting app storage. Record device, iOS,
SHA, language, text size, date and outcome.

1. Open Settings → Pilot insights in English and Spanish, with VoiceOver and the
   largest text size. Read all labels, sample counts, unavailable values and
   privacy/retention copy; reach export and deletion controls.
2. Make/replace/cancel Picks, confirm watched with and without a reaction, and
   postpone a pending Pick. Compare the report with the explicit actions.
3. Use Home Already watched once; verify a redraw does not inflate counts, and
   rating or watched from another surface does not change the Home metric.
4. Export JSON to a local Files destination, inspect the report, then cancel an
   export and verify source history is unchanged.
5. Delete measurement after confirming a Pick. Verify eligible history is gone
   after relaunch while pending confirmations, current watched/reactions,
   PickOne badges, profile, Watchlist, Search History and Home recommendations
   remain intact. Active work may intentionally keep nonzero report counts.

Final-M7 prolonged upgrade validation and closure remain PR4 work.

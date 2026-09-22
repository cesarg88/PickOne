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

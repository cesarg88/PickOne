# Pilot integration and closure evidence

## Scope and status

M8 PR4 is explicitly authorized by the Product Owner (2026-09-29, resumed
2026-09-30). The independent branch starts at `develop` `60154f4`, after PR #53.
Authorities: [M8](../../milestones/milestone-8-pilot-measurement.md),
[ADR-015](../../decisions/adr-015-local-decision-measurement-and-provenance.md),
[PRODUCT](../../../PRODUCT.md) and [ENGINEERING](../../../ENGINEERING.md).

No production behavior changes. PR4 adds one composed integration test, a
reproducible simulator upgrade verifier, and evidence/status corrections.
Existing tests supply individual failure, recovery, concurrency, presentation
and metric coverage. Native Files automation remains removed. Visual changes,
features and unrelated refactors are excluded.

**M8 is not closed.** Remaining human checks and final Product Owner acceptance
are open. Technical review and green CI on the final SHA remain merge gates;
local validation does not imply either approval.

## Physical evidence and its limits

The Product Owner reports successful functional validation on a **clean install
on iPhone 18 Pro**, including export, languages/accessibility, confirmation and
deletion. `Already watched` keeps the other two recommendations. Selection-notice
layout shifts and abrupt transitions are deferred to the visual milestone.

The Product Owner changed device and cannot access the previous household
installation. No physical upgrade over retained final-M7 data was performed.
The iOS version, installed SHA, precise execution date, individual language and
accessibility configurations, Files destination/provider and separate
Replace/cancel outcomes were not supplied. This record does not invent them.
The aggregate functional result is accepted as reported; it does not establish
all individual checklist paths or final milestone acceptance.

## Requirement traceability

| Accepted requirement / boundary | Evidence reused or added |
| --- | --- |
| Final-M7 application update, v3→v4, no inferred provenance | `Scripts/verify-pilot-upgrade.py`: builds described below; actual old/new app replacement and relaunch with synthetic persisted data. `ViewingProvenanceMigrationTests` covers exact fields and both failed migration writes. |
| Composed migration, prolonged use and conservation | New `PilotDataConservationTests.upgradedStateSurvivesRepeatedJourneysAndMeasurementLifecycle`, parameterized for pruning/deletion: real file stores, v3 profile/reaction/Watchlist fixture, persisted Decision Set and Search History, twelve evenings with repository recreation. |
| Foreground timing, old-set reuse, abandonment, related Detail, refresh, unavailable timing | `RecommendationSessionTests`, `RecommendationSessionBoundaryTests`, `ViewingDecisionPersistenceTests`; composed test asserts first/final means of 10/40 seconds, excluding background time. |
| Pick does not mutate viewer state or Home; replacement/cancellation, stale operations | `HomePickViewModelTests`, `HomePickFeedbackTests`, `QueuedPickOperationTests`, `ConfirmationPickCacheTests`; existing Home UI tests. |
| 12-hour eligibility, three 24-hour postponements, manual pending, every answer, optional reaction | `ViewingConfirmationTests`, `ViewingConfirmationPresentationTests`, `ViewingConfirmationInteractionTests`. |
| Recovery at every confirmation/satisfaction write, idempotence, no rollback of watched/provenance | `ViewingConfirmationRecoveryTests.everyJournalWriteResumesAfterRecreation` (eight boundaries, both operations), viewer-write failures, later edits/unwatched replay tests, `ConfirmationSemanticRecoveryTests`. |
| Corrupt/unsupported active/previous, quarantine, unavailable rather than empty | `ViewingDecisionSemanticRecoveryTests`, `ViewingConfirmationIntegrityTests`, `PilotMeasurementRecoveryTests`, `PilotMeasurementIntegrityTests`, existing Viewer State recovery suites. |
| Retention at 180 days, pending/journal survival, deletion isolation and no resurrection | `PilotMeasurementPersistenceTests`, `PilotMeasurementLifecycleTests`; new composed test advances to day 400, keeps an unresolved Pick and twelve durable provenances, verifies exact viewer active/previous, Home and quarantine bytes plus Search History. |
| Current reaction differs from immutable satisfaction | New composed test confirms `.likeIt`, edits current reaction to `.loveIt`, recreates repositories and checks both meanings; existing provenance/reset tests cover reset and unwatched. |
| Privacy-safe, read-only export and exact metrics | `PilotMeasurementTests`, `PilotMeasurementPersistenceTests.exportIsReadOnlyAndContainsAllowlistedRecordsAndDerivedSummary`, integrity tests; new composed export rejects private Search/movie metadata sentinels. |
| Search evidence adds no requests; measurement failure does not alter results | `PilotSearchIntegrationTests.measurementFailureCannotChangeSearchOrAddRequests`, existing coordinator cancellation tests. Source review of measurement Domain/Data finds no networking dependency or generic tracking API. |
| Home Already watched counts only successful Home feedback and preserves siblings | `HomeQuickFeedbackViewModelTests`, `ThreeForTonightViewerStateReconciliationTests`, `HomeExhaustionRecoveryIntegrationTests` (42 feedback/refresh iterations); physical sibling-preservation result reported above. |
| M7 Home recovery, Watchlist, Search History, calibration and My movies regressions | Existing M7 integration suites and `PickOneSmokeTests`, including recovery/relaunch, feedback across surfaces and recalibration. |
| English/Spanish controls, accessibility size, report/delete interaction | Existing Pick/confirmation/Pilot insights UI tests; reported physical languages/accessibility success. Native Files paths remain manual. |

The new composed test fills a cross-repository postcondition gap; it does not
repeat each reducer/recovery test. Its twelve evenings use injected timestamps,
not twelve days of physical use. Historical M7 recovery tests additionally
exercise real coordinator repair, exhaustion and preserved sibling selections.

## Reproduce the controlled update

Use final M7 commit `89b06dc` (#49), not an M6 or intermediate blocked fixture.
The old application runs the existing offline Home recovery scenario and itself
writes final-M7 schema 3. The verifier replaces that app with M8, without
uninstalling/resetting/reseeding between versions, then launches and relaunches.
It checks pre-launch byte preservation, every old envelope field, absent
provenance, exact v3 recovery copy, Search History and the selected Home fixture.
Each M8 launch must also persist new Home measurement with movie 101 observed.
CoreSimulator may relocate its data directory on installation; content equality,
not a directory UUID, establishes preservation.

This uses the existing test scenario's persistent UserDefaults viewer store and
stubbed Home. It is synthetic application-update evidence, not live provider
validation, not the unavailable household installation, and not a new physical
result. The new integration test separately exercises production file stores,
a v3 reaction/Watchlist/profile fixture and production Decision Set persistence.

From the repository root, choose unused output directories:

```sh
mkdir -p .derivedData/ControlledUpgrade/source
git archive 89b06dc | tar -x -C .derivedData/ControlledUpgrade/source
cp .derivedData/ControlledUpgrade/source/Config/Debug.xcconfig.example \
  .derivedData/ControlledUpgrade/source/Config/Debug.xcconfig
caffeinate -s xcodebuild build \
  -project .derivedData/ControlledUpgrade/source/PickOne.xcodeproj -scheme PickOne \
  -configuration Debug -sdk iphonesimulator \
  -destination 'generic/platform=iOS Simulator' \
  -derivedDataPath .derivedData/ControlledUpgrade/M7 \
  CODE_SIGNING_ALLOWED=NO TMDB_API_KEY=controlled-upgrade-offline-fixture
caffeinate -s xcodebuild build -project PickOne.xcodeproj -scheme PickOne \
  -configuration Debug -sdk iphonesimulator \
  -destination 'generic/platform=iOS Simulator' \
  -derivedDataPath .derivedData/ControlledUpgrade/M8 \
  CODE_SIGNING_ALLOWED=NO TMDB_API_KEY=controlled-upgrade-offline-fixture
caffeinate -s python3 Scripts/verify-pilot-upgrade.py \
  .derivedData/ControlledUpgrade/M7/Build/Products/Debug-iphonesimulator/PickOne.app \
  .derivedData/ControlledUpgrade/M8/Build/Products/Debug-iphonesimulator/PickOne.app \
  .derivedData/ControlledUpgrade/evidence-26-5
```

The non-secret dummy key satisfies the existing launch guard; the scenario uses
stubs. No app source is patched in the historical archive. The verifier creates
its own disposable simulator; on success it removes only that simulator and
keeps the JSON evidence. On failure it shuts it down and retains it for diagnosis.
No Files UI automation, real user data or credentials are involved.

## Automated execution record

Environment: 2026-09-30, Xcode 27.0 (27A266a). Focused integration uses iPhone 17
Pro / iOS 26.5 Simulator. The physical iPhone report is separate.

```sh
caffeinate -s xcodebuild test -project PickOne.xcodeproj -scheme PickOne \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5' \
  -parallel-testing-enabled NO -derivedDataPath .derivedData/Tests \
  -only-testing:PickOneTests/PilotDataConservationTests
caffeinate -s make verify SIMULATOR_OS=26.5
```

- Focused composed test passed in both pruning/deletion cases. Result:
  `Test-PickOne-2026.09.30_18-02-11-+0200.xcresult`.
- Controlled app update passed on iPhone 17 Pro / iOS 26.5. Evidence:
  `.derivedData/ControlledUpgrade/evidence-26-5/result.json`, M7 active/previous,
  M8 upgrade/relaunch and measurement JSON snapshots. Source schema 3 → target
  schema 4; exact previous bytes and all original fields preserved; no inferred
  provenance; fresh Home observation on both launches. The disposable simulator
  was removed after success. M8 production code is unchanged from `60154f4`.
- Complete gate passed (exit 0): `caffeinate -s make verify SIMULATOR_OS=26.5`;
  639 unit tests in 123 suites and all 11 UI tests, formatting, strict lint,
  repository/secret checks, static analysis, unsigned Release and app-bundle
  inspection. Result: `Test-PickOne-2026.09.30_18-11-10-+0200.xcresult`.
  No production code or Swift test changes followed this run. Subsequent edits
  only finalized this evidence and renamed the verifier's positional argument
  labels (`--help` checked); its invocation and behavior are unchanged.
- CI is not awaited at handoff and remains a separate final-SHA merge gate.
- Setup diagnostics: the historical archive initially lacked its ignored
  xcconfig; using the example built but its placeholder triggered the existing
  launch precondition. The final build uses the dummy key above. An initial
  verifier incorrectly required an unchanged container path; exact bytes were
  confirmed intact and the verifier now compares content. Another fresh iOS 27
  simulator failed at the initial M7 `simctl launch` with `NSPOSIXErrorDomain 3`
  (no process handle), before any update assertions; its cause was not established.
  That attempt supplies no migration evidence. Default `make verify` then stopped
  before testing (exit 70): Xcode 27 resolved `OS=latest` to a runtime without an
  iPhone 17 Pro. The complete run uses the existing `SIMULATOR_OS=26.5` Makefile
  parameter, with no gate or timeout changes. The controlled run uses iOS 26.5,
  matching the focused test runtime. A missing nested `try` in the new test was
  corrected before its successful run. No production fix was made.

## Remaining human checklist

Do not repeat the already reported clean-install functional checks solely to
recreate missing historical metadata. For new checks, record actual device,
iOS, SHA, date, configuration and result at execution time.

- [ ] On current test data, finish a prolonged real-use/relaunch checkpoint:
  before/after 12-hour confirmation, 24-hour postponement through manual pending,
  compare report to explicit actions, then verify pending work, badges and other
  repositories after measurement deletion/relaunch. Mark individual paths already
  exercised only if the Product Owner can attest to them.
- [ ] If not already exercised, test native export **Replace** and **Cancel**:
  return to an interactive report, no source-history change; cancellation creates
  no file and permits another export. Record provider and actual outcomes. General
  export success does not establish these unreported paths.
- [ ] Technical Lead reviews evidence and final-SHA green CI; Product Owner
  accepts the controlled-upgrade substitute and its inaccessible-installation
  limitation, resolves remaining checks and explicitly accepts M8 before closure.

Selection-notice motion/layout and abrupt transitions are visual-milestone work,
not functional blockers or additions to this PR. This checklist does not request
access to an installation the Product Owner no longer has.

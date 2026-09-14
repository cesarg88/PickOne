# Pick and session verification

## Scope and delivery state

This is the PR1 implementation record for
[Milestone 8](../../milestones/milestone-8-pilot-measurement.md), bounded by
[ADR-015](../../decisions/adr-015-local-decision-measurement-and-provenance.md).
The branch starts at `c31e39f`, the accepted D0 merge into `develop` (#50).
The Product Owner explicitly authorized PR1 on 2026-09-14.

PR1 delivers Pick/replace/cancel, recommendation sessions, independent local
persistence and recovery, and English/Spanish Home controls. It does not close
M8, ADR-015 implementation, IMP-005, IMP-023, or the roadmap milestone.
Confirmation, provenance, satisfaction, insights, export, retention/deletion,
Home already-watched/search metrics, and remote delivery remain deferred to
their accepted slices. Viewer Movie State stays at v3.

## Implementation boundaries

- Domain: `ViewingDecisionState` reduces semantic operations;
  `ManageViewingDecision` and `ViewingDecisionRepository` expose the boundary.
- Data: `LocalViewingDecisionRepository` serializes complete-envelope writes
  without an actor suspension between persistence and publication.
  `ViewingDecisionEnvelope` validates the initial v1 JSON schema.
- Storage: `ApplicationSupportViewingDecisionStore` uses only
  `Application Support/PickOne/ViewingDecisions`, with atomic active and previous
  copies and exact-byte quarantine. No existing repository migrates or resets.
- Presentation: `HomePickViewModel` orders captured lifecycle and explicit
  actions, maintains per-movie progress/retry, and publishes committed snapshots.
  `HomeDecisionViewModel` supplies the rendered recommendation identity, set,
  cycle, and role without regenerating the Decision Engine for a Pick.
- Timing uses [ContinuousClock](https://developer.apple.com/documentation/swift/continuousclock)
  relative to this app runtime; no device boot-time value is read or stored.
- UI/composition: Home cards expose Pick/Picked with title-specific accessibility
  labels; tapping the selected card cancels the choice, and picking another
  suggestion replaces it. There is no separate cancellation button.
  MainTabView supplies app activation and Home/related Detail visibility.

## Requirement traceability

| Accepted source clause | Implementation boundary | Automated evidence |
|---|---|---|
| Session starts only with active, usable Home | Domain reducer and HomePickViewModel | `RecommendationSessionBoundaryTests`; `HomePickViewModelTests` |
| Related Detail and refresh continue the attempt | Visible-surface snapshot and semantic refresh operation | `detailAndRefreshStayInSessionAndDeduplicateSets`; `relatedDetailRemainsVisibleThroughBackgroundAndOldSetBoundary` |
| Observed set identities deduplicate; refresh counts explicit actions | Session reducer; durable operation receipts | `detailAndRefreshStayInSessionAndDeduplicateSets`; `duplicatePickRefreshAndCancelSurviveRecreation` |
| Foreground-only timing; background pause | Injectable wall time and runtime-relative monotonic evidence | `foregroundPickReplacementAndCancellation`; `interruptedForegroundUsesUnavailableButCleanPauseRetainsTiming`; `failedBackgroundWriteNeverCountsBackgroundAsForeground` |
| Exact 30-minute boundary, abandoned/decided closure, old-set reuse | Session reducer and scheduled expiry | `inactivityBoundaryAbandonsAndReusesOldSet`; `activePickFinalizesAndSurvivesBoundary` |
| Preserve Pick when timing cannot be trusted | Explicit unavailable timing and optional session attribution | `pickWithoutActiveSurfaceHasUnavailableTiming`; `interruptedForegroundUsesUnavailableButCleanPauseRetainsTiming` |
| Recover from trustworthy visible evidence before timing fallback | Validated Presentation snapshot | `pickRecoversFromVisibleEvidenceWhenObservationWasMissing`; `mismatchedCardIsRejectedWithoutMutation` |
| First/final Pick, replacement and cancellation history | Session first timing and final-decision reference; decision chain | `foregroundPickReplacementAndCancellation`; `duplicatePickRefreshAndCancelSurviveRecreation` |
| Stable-operation idempotence, including relaunch and concurrency | Actor and persisted receipts | `duplicatePickRefreshAndCancelSurviveRecreation`; `simultaneousDuplicateOperationsCommitOnce` |
| Old work cannot replace newer selection | Ordered Presentation tasks and monotonic mutation ordering | `delayedCompletionsCannotReplaceNewerChoice`; `oldFailedRetryCannotUndoLaterPickOrCancellation`; `staleLifecycleCannotPauseNewerForegroundAndStaleCancelCannotCancelReplacement`; `cancellationRetryAfterNewerLifecycleStillCancelsTheSamePick` |
| Success notice dismisses after three seconds without cancelling or replaying on Home return/relaunch | Separate Presentation timer; persistent card state and cancellation on the selected card | `HomePickFeedbackTests`; `HomePickInteractionTests` waits for dismissal before cancellation |
| Failed Pick remains retryable with no false Picked UI | Publish only after complete durable write | `perCardFailureRetryAndReplacementPublishOnlyDurableSuccess`; `failedWriteKeepsPriorEnvelopeAndRetrySucceeds` |
| Task cancellation is not explicit Pick cancellation | Pre-commit cancellation check | `cancellationBeforeMutationWritesNothing` |
| Active/previous/quarantine/recreation; never invent empty history | Independent versioned envelope and storage recovery | `exactInvalidBytesAreQuarantinedAndPreviousRecovered`; `failedRecoveryNeverFabricatesEmptyHistory`; `storageFailureDoesNotOverwriteUnreadHistory`; `applicationSupportRoundTripStoresOnlyAllowedEvidence` |
| Only known schemas migrate | Initial v1 decoder rejects other versions | Unsupported-schema fixture in `exactInvalidBytesAreQuarantinedAndPreviousRecovered`; no predecessor schema exists for this new repository |
| Pick preserves recommendations and other authorities | Pick graph has no mutation dependency on existing repositories | `homePickDoesNotInvokeRecommendationGenerationOrMutatePublishedSet`; `HomePickInteractionTests`; full existing regression suite |
| Pick survives process termination and relaunch; storage paths with spaces or escaped characters remain readable | File-store existence checks use an unencoded filesystem path; UI fixture storage survives relaunch | `applicationSupportRoundTripStoresOnlyAllowedEvidence` (plain, Application Support, accented/percent paths); `HomePickInteractionTests` terminates and relaunches before cancellation |
| English/Spanish visible controls and title-specific accessibility | String Catalog; native buttons and scalable layouts | `HomePickInteractionTests` in English and Spanish at Accessibility XXXL |
| No metadata, raw text, provenance, SDK, or new search requests | DTO allowlist and bounded dependency graph | `applicationSupportRoundTripStoresOnlyAllowedEvidence`; source/dependency inspection |

## Validation commands

Focused suites use `xcodebuild test -project PickOne.xcodeproj -scheme PickOne
-destination 'platform=iOS Simulator,name=iPhone 17 Pro'
-parallel-testing-enabled NO -derivedDataPath .derivedData/Tests`, selecting:

- `PickOneTests/RecommendationSessionTests`
- `PickOneTests/RecommendationSessionBoundaryTests`
- `PickOneTests/ViewingDecisionPersistenceTests`
- `PickOneTests/HomePickViewModelTests`
- `PickOneUITests/HomePickInteractionTests`

The first session test failed before implementation because the new contracts
were absent. A focused behavioral test then exposed the missing-observation
recovery path and passed after the fix. Additional red tests covered a failed background checkpoint and retrying
cancellation after a newer lifecycle observation. The Spanish Accessibility
XXXL UI test exposed a SwiftUI lazy-layout loop after Pick; a main-thread
sample localized it to lazy subview placement. Home's bounded three-card list
now uses eager layout, and the same English/Spanish UI tests pass.
A regression test reproduced the permanently visible Pick notice before the
fix. The notice now dismisses after three seconds, while the card remains
Picked and tapping that card again cancels the choice. Home has no separate
cancellation button, as requested by the Product Owner. Focused tests cover durable
state after dismissal, return/relaunch, failed saves and retry, replacement
deadlines, and immediate cancellation. English/Spanish UI tests wait for the
notice to disappear, assert that no separate cancellation button remains,
and cancel by tapping the selected card again. The redundant toolbar button
was reproduced by a failing UI assertion before removal.
The relaunch regression exposed an encoded URL path used in a filesystem
existence check: `Application Support` became `Application%20Support`, so a
saved envelope was mistaken for an absent file and overwritten on startup.
The file store now checks the unencoded path. The disk round-trip test covers
spaces, accented text, and percent characters; UI tests retain an isolated
Application Support directory across process launches, reset it explicitly
between scenarios, and verify the selected card and absence of a replayed
notice before cancelling. Production storage is never reset by those fixtures.
The delivery gate is `make verify`;
final results and CI status are recorded in the PR rather than assumed here.

## Physical validation still required

The Product Owner should install over the retained final-M7 application without
clearing data and check Pick discovery without coaching, replacement,
cancellation, background/foreground and relaunch, VoiceOver, Dynamic Type, and
English/Spanish. Confirm that Pick alone preserves watched/reaction/Watchlist
and the recommendation set. Automated simulator checks do not establish
physical discoverability or VoiceOver usability. PR2+ device journeys and final
milestone closure remain outside this PR.

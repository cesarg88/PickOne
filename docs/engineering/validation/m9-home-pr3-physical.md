# M9 Home PR3 — physical validation guide

## Scope and status

- Implementation: [issue #64](https://github.com/montunolabs/PickOne/issues/64), [PR #71](https://github.com/montunolabs/PickOne/pull/71), accepted [Home contract](../../milestones/milestone-9-home-implementation.md).
- Code under test: `4a864490db9cac14f4a47785139e176d6f1cf05c` plus this documentation-only commit. If the code changes, validate the new code SHA again.
- Status: **Pending physical execution and Product Owner decision.** No result or approval is implied by this guide, simulator tests, or CI.
- Boundary: PR3 Pick controls and stable feedback transitions only. The complete Home matrix and physical iPad acceptance remain in PR4/#65.

The Product Owner chooses a retained-data device and a real recommendation set. Do not reset preferences, clear storage, erase/reinstall the app, manufacture a reaction or watched fact, or use a disposable fixture as a substitute for physical validation. Stop and mark a step **Blocked** if its prerequisites are absent. A tester may decline any durable feedback action without failing the build.

## Validation record — complete before testing

| Field | Actual value |
| --- | --- |
| Tester and date/time/time zone | Pending |
| Exact installed app build/commit SHA and distribution method | Pending — confirm it contains code SHA `4a86449`; do not infer from the PR head |
| Device model and iOS/iPadOS version | Pending |
| App language, Light/Dark, Dynamic Type, VoiceOver, Reduce Motion, Reduce Transparency | Pending — record changes per step |
| Installation state | Pending — confirm update over retained data, not reinstall/reset |
| Selected services/profile and relevant existing Watchlist, watched, reaction, Not interested facts | Pending — record only what is needed to compare; avoid private data in public evidence |
| Starting Home roles, visible titles/movie IDs if available, and current Pick | Pending — note if fewer than three cards |
| Evidence location and privacy treatment | Pending — use redacted screenshots/video and a private notes location if titles/profile reveal household choices |

Do not proceed with a mutation if the starting state cannot be established well enough to tell what changed. Pick/cancel/replace write durable decision/session history even when the current Pick is later cancelled. `Already watched`, reactions and `Not interested` change Viewer Movie State and may exclude a title or alter future recommendations. **Undoing a current state is a new action, not an erasure of history or a guarantee of the old set returning.** If the Product Owner wants a current-state change reversed, record the before/after state and use only the visible inverse control for the same movie in Detail (`Mark unwatched`, `Undo Not interested`, or `Remove rating`, as applicable). Do this only on request, verify the resulting state, and stop if the control or prior state is unclear. Never use a reset, reinstall, hidden storage edit or broad cleanup to “restore” the test.

## Physical-device steps

For every row record **Pass / Fail / Blocked**, the observed result, and evidence reference in the result log below. Follow the sequence; do not repeat a durable action solely to obtain a screenshot. **Configure the accessibility settings in P0 before Pick or feedback.** Capture screenshots/video and VoiceOver observations during P2/P4/P5, while transient notices exist; P6–P8 review those observations and require no new mutation. Saving may complete too quickly for a human to observe an intermediate frame; record **Blocked for that sub-observation**, not an invented pass or failure.

| ID | Action and precondition | Expected result |
| --- | --- | --- |
| P0 — prepare once | Record the original language, theme, text size, VoiceOver, Reduce Motion and Reduce Transparency values. Before any Pick/feedback action, set Accessibility XXXL, Reduce Motion, Reduce Transparency and VoiceOver in iOS Settings; prepare a private spoken-focus note or screen recording. Keep these settings through P5. If a setting cannot be enabled, mark only its dependent checks **Blocked**. | The original values and chosen test values are documented. No watched/reaction/Not interested/Watchlist data changes during setup. Restore the original accessibility settings in P10. |
| P1 — baseline | Open Home on the retained-data build. Record the visible movie/role identities, active Pick, scroll position, and the selected title's watched/reaction/Watchlist/Not interested state. Open a card's Detail and return. | Home and Detail show the same movie; navigation works and the starting data is unchanged. The Pick pill has visible `Pick`/`Elegir` text, no normal-state icon, a movie-specific accessibility label and a discoverable hint; the ellipsis exposes valid actions. |
| P2 — Pick commit | Choose an eligible recommendation **you genuinely want to Pick**. If another Pick is already active, obtain the Product Owner's explicit choice to replace it or mark this step **Blocked**. Tap the chosen Pick pill once. Observe saving if visible, then wait for completion. Record whether the control moves relative to the card. | During saving, the control cannot be activated again. Only after success it shows check + `Picked`/`Elegida`; the transient localized success notice names the visible movie (or truthfully omits a title when unavailable). The chosen card and its role remain in place. Pick alone does not mark watched, add a reaction or change Watchlist. |
| P3 — persistence | Leave and reopen the app normally without deleting it. Return to Home and the same movie. | The committed Pick is still selected; no stale success notice replays. The relevant watched/reaction/Watchlist facts remain as recorded. If the set legitimately changed, identify the movie through Detail/My movies and record why comparison is limited. |
| P4 — replace | If a second eligible recommendation is available **and desired**, Pick it. Observe the first selected card while the new save runs, then wait for the second to commit. Do not cancel yet; P5 follows if a genuine feedback action is available. | At most one Pick is active. The old committed Pick remains selected until replacement commits; only then does the new card show selected. Neither movie becomes watched or disliked from Pick. If only one eligible card exists or replacement is unwanted, mark this step **Blocked**. |
| P5 — one-card feedback | **Only if the Product Owner genuinely wants to record it**, use one applicable ellipsis action on a currently recommended movie: `Already watched` for an actually watched movie, `Not interested` for a genuinely unwanted one, or an honest reaction. Record its movie ID/role and the other visible cards first. If P6 focus is being checked, VoiceOver is already enabled from P0: navigate the role/title/reason/Pick/ellipsis, focus the ellipsis and take this **single** action. Do not tap Pick on the affected card during reconciliation. | A successful exclusion normally replaces that movie's role slot without briefly collapsing it; unaffected eligible/explainable movie IDs remain. A reaction may also change other cards whose evidence is invalidated. While the old card is retained during reconciliation, its Pick cannot accept an excluded choice; its Detail remains available. An idempotent no-op returns the menu instead of an endless spinner. If no genuine action is appropriate, mark this step **Blocked**. |
| P6 — VoiceOver reading and focus | Review the spoken order and actual focus observed **during P5**; do not repeat feedback. If P5 was Blocked, inspect the nonmutating card reading order now and mark only post-replacement focus **Blocked**. | Reading and action order make the movie and the six valid feedback choices understandable. Focus remains on the affected role slot/placeholder and then the replacement card, not a removed movie, the TabBar or an unrelated element. Detail can still be opened. Record the actual spoken label, focused element before/after, and whether manual refocusing was needed; needing manual refocus is a failure to report, not a pass. The automated role-target test is not proof of actual VoiceOver focus. |
| P7 — reduced effects | With Reduce Motion/Transparency **already enabled in P0**, review the controls and the P2/P4/P5 observations or recordings. Inspect the current native Glass Pick/ellipsis and status surface without making another durable action. | Progress and committed states remain distinguishable without nonessential card motion. Adapted opaque surfaces and notice text remain legible; controls are not concealed. If an ephemeral saving/notice state was missed, mark that subcheck **Blocked**, not passed by memory or by repeating feedback. |
| P8 — XXXL and notices | With Accessibility XXXL **already enabled in P0**, navigate all visible cards using normal scrolling, including Pick, ellipsis and Detail. Review notices observed during P2/P4/P5. If Pick and update notices naturally overlapped, scroll **inside their fixed status region** to read the second notice. | Controls remain reachable with usable touch targets and labels; the tapped control does not jump when a notice appears. The notices do not cover Pick, feedback or the TabBar; internal scrolling reveals all text. If simultaneous notices did not occur naturally, mark only that overlap subcheck **Blocked** on device and use fixture evidence below; do not hurry or fake a feedback action to create it. Exact 44×44 pt geometry is measured in the focused UI test, not inferred from a finger tap. |
| P9 — cancel | If an active Pick remains and the Product Owner wants to cancel it, tap its selected pill once, wait for completion and reopen the app. Do not cancel an existing household choice merely to complete this step. | Until durable cancellation succeeds, the committed Pick remains selected; afterward no card falsely shows an active Pick. Cancellation does not mark watched or disliked. If no active Pick remains or cancellation is unwanted, mark this step **Blocked**. |
| P10 — final state and settings | Reopen Home once more; compare Pick, watched, reaction, Not interested and Watchlist facts with the intentional actions recorded above. Note any requested per-movie inverse action separately. Restore the original accessibility settings recorded in P0 and note their final values. | Only the chosen durable actions remain; no unrelated data disappeared. Original OS settings are restored or an explicit reason is recorded. Preserve errors or unexpected set changes for an issue; do not reset or reinstall to conceal them. |

### Result log

| Step | Pass / Fail / Blocked | Actual result and evidence reference | Blocker or issue link |
| --- | --- | --- | --- |
| P0 settings/preconditions | Pending | Pending | — |
| P1 baseline | Pending | Pending | — |
| P2 Pick commit | Pending | Pending | — |
| P3 persistence | Pending | Pending | — |
| P4 replace | Pending | Pending | May be Blocked if no second eligible/desired Pick |
| P5 one-card feedback | Pending | Pending | Requires a genuine chosen action; otherwise Blocked |
| P6 VoiceOver focus/order | Pending | Pending | Post-replacement focus depends on P5; otherwise Blocked |
| P7 Reduce Motion/Transparency | Pending | Pending | Transient states may be Blocked if missed |
| P8 XXXL/notices/TabBar | Pending | Pending | Simultaneous overlap may be Blocked on physical device |
| P9 cancel | Pending | Pending | May be Blocked if cancellation is unwanted |
| P10 final state/settings | Pending | Pending | — |

## Fixture/simulator-only evidence and physical limits

These are **not instructions to manipulate real data**. The PR's automated tests use isolated fixtures and explicit `-ui-testing` launch arguments; they do not prove live VoiceOver focus or OS preference behavior on a physical device.

| Scenario | Existing reproducible evidence | Physical result |
| --- | --- | --- |
| Durable Pick failure/retry, cancellation failure/retry and commit gating | `HomePickViewModelTests`, `HomePickInteractionTests` | Retry can be inspected only if a failure happens naturally; do not corrupt storage or force a write failure. Otherwise **Blocked** physically. |
| Feedback committed while reconciliation is gated; excluded old card rejects Pick; no-op restores menu | `HomeDecisionPickReconciliationTests`, `HomeQuickFeedbackViewModelTests` | Gated timing and idempotent no-op are **fixture only** unless they occur naturally. Do not tap Pick on a movie genuinely marked watched/Not interested. |
| One-card role focus target, Reduce Motion/Transparency branches, simultaneous notices at XXXL, and 44-point frames | `HomePickInteractionTests` on iPhone 17 Pro/iOS 26.5 with isolated Home recovery fixture; the notice test uses `-ui-testing-hold-home-pick-notice` and `-ui-testing-home-reduced-accessibility` alongside `-ui-testing` | The test observes the restoration target, not real VoiceOver focus. System reduction settings require P6/P7 on device. The 20-second test hold is not production timing. |
| Language switch while a Pick save is gated | `HomeDisplayLocalizationViewModelTests` | Mid-save timing is **fixture only** unless it occurs naturally; never infer a translated title not visible in the chosen language. |

Evidence to attach or cite privately: build provenance/SHA, before/after redacted Home screenshots or short screen recordings, a focused VoiceOver spoken-label/focus note, settings screenshots (language/text size/reductions), chosen movie IDs or unambiguous private labels, and any error/retry message with time. For an actual failure, preserve the state and link an issue; do not erase data to obtain a clean rerun. The current test-only `.xcresult` and CI results are supplemental, not a physical OK.

## Final disposition — Product Owner

- Overall physical result: **Pending** (`Pass` / `Fail` / `Blocked`).
- Exact app build/commit SHA judged: **Pending**.
- Deviations, blocked steps and follow-up issue links: **Pending**.
- Data reversals explicitly requested and their observed result, if any: **Pending / none recorded**.
- Product Owner decision: **Pending explicit satisfactory OK** (or rejection); name/date: **Pending**.

Keep #64 In Progress and do not merge PR #71 while required physical validation is failed or blocked, the Product Owner's satisfactory OK is absent, required CI is not green on the final SHA, or technical review remains open. A relevant code change after approval requires validation again on the new build SHA.

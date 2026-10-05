# Milestone 9 — Home visual implementation contract

## Status and authority

**Accepted — Home Engineering Ready after PR #60 merged.** Product has approved the Home v2 controls,
the direction of the continuous scrim, and the [Design handoff in issue
#57](https://github.com/cesarg88/PickOne/issues/57#issuecomment-5992956491)
for implementation. PR #60 was reviewed and merged before implementation began.
This does not make the whole of
Milestone 9 Product Ready or Engineering Ready, certify contrast/accessibility
in the app, or close issue #57. Do not begin production implementation before
that merge.

[`PRODUCT.md`](../../PRODUCT.md) governs behavior; [`ENGINEERING.md`](../../ENGINEERING.md)
governs architecture. Preserve the accepted Decision Engine, bounded recall,
eligibility/availability, Viewer Movie State, Pick/session/provenance, and
measurement contracts in [ADR-011](../decisions/adr-011-deterministic-decision-engine-v1.md),
[ADR-014](../decisions/adr-014-bounded-recommendation-suppression-and-recovery.md),
and [ADR-015](../decisions/adr-015-local-decision-measurement-and-provenance.md).
[ADR-016](../decisions/adr-016-ios-26-platform-baseline.md) supplies the
iOS/iPadOS 26 baseline. The visual work must not change those Domain rules to
make a mockup fit.

The accepted Home direction is independent of a future Detail redesign. A
small metadata change in Detail is in scope solely to make the same movie title
coherent when navigating from Home. Whole-app localization, Detail's new
layout, a coach mark, trailers, backend work, and new recommendation signals
remain outside this Home contract.

## Design evidence and interpretation

Use the [Design handoff](https://github.com/cesarg88/PickOne/issues/57#issuecomment-5992956491)
as the complete state/copy/accessibility reference, not a machine-local file.
Stable Figma evidence:

| Surface | Reference | Interpretation |
| --- | --- | --- |
| iPhone portrait, ES Dark v2 | [214:8982](https://www.figma.com/design/t6JdpqD0ToMkLF0fulhUvZ?node-id=214-8982) | Approved hierarchy and controls; dimensions are illustrative |
| iPhone ES/EN | [214:8667](https://www.figma.com/design/t6JdpqD0ToMkLF0fulhUvZ?node-id=214-8667), [214:8827](https://www.figma.com/design/t6JdpqD0ToMkLF0fulhUvZ?node-id=214-8827) | Language/theme samples, not fixed-height screens |
| Pick states | [214:9142](https://www.figma.com/design/t6JdpqD0ToMkLF0fulhUvZ?node-id=214-9142), [214:9313](https://www.figma.com/design/t6JdpqD0ToMkLF0fulhUvZ?node-id=214-9313) | Progress and selected are examples; durable state remains authoritative |
| iPad portrait | [104:2211](https://www.figma.com/design/t6JdpqD0ToMkLF0fulhUvZ?node-id=104-2211), [104:2233](https://www.figma.com/design/t6JdpqD0ToMkLF0fulhUvZ?node-id=104-2233) | Geometry only; old controls/scrim are superseded by v2 |
| iPad landscape v2 | [214:9552](https://www.figma.com/design/t6JdpqD0ToMkLF0fulhUvZ?node-id=214-9552), [104:2257](https://www.figma.com/design/t6JdpqD0ToMkLF0fulhUvZ?node-id=104-2257) | Two-column direction and physical viewport reference |
| Controls and feedback | [212:6458](https://www.figma.com/design/t6JdpqD0ToMkLF0fulhUvZ?node-id=212-6458), [212:6474](https://www.figma.com/design/t6JdpqD0ToMkLF0fulhUvZ?node-id=212-6474), [202:5822](https://www.figma.com/design/t6JdpqD0ToMkLF0fulhUvZ?node-id=202-5822) | Native Glass Pick, ellipsis, and the existing six-action menu |
| Contrast and fallback | [214:9707](https://www.figma.com/design/t6JdpqD0ToMkLF0fulhUvZ?node-id=214-9707), [215:6951](https://www.figma.com/design/t6JdpqD0ToMkLF0fulhUvZ?node-id=215-6951), [50:911](https://www.figma.com/design/t6JdpqD0ToMkLF0fulhUvZ?node-id=50-911) | Bright-photo failure is evidence to fix, not an accepted result |

Approved: dominant Safe card with two ordered alternatives; a native Liquid
Glass **text** pill `Pick` / `Elegir` without a normal-state icon; a check and
`Picked` / `Elegida` only after durable success; a native Glass ellipsis menu;
one continuous black scrim over the visible image under text and controls.
The 10/40/80% top/mid/bottom stops are adjustable starting values, never
certified contrast targets. Do not recreate the obsolete icon-only Pick,
coach mark, separate text plates, or opaque bottom band. Lora/Inter and exact
sizes are scoped design references, not global typography tokens.

## Existing boundaries and required contracts

| Layer | Existing component and change bound |
| --- | --- |
| Domain | `ThreeForTonightUseCase`, `PersistedDecisionSet`, `DecisionCycle`, `RecommendationEvidence`, and `ManageViewingDecision` retain their identities and rules. Add only a language-neutral presentation metadata request/value contract if needed. Do not add locale to cycle identity, scoring, eligibility, or shown-history suppression. |
| Data | `TMDBDecisionCandidateClient` currently requests `es-ES`; `TMDBMovieCatalogClient` defaults to `en-US`; `DefaultMovieRepository` keys detail cache by movie ID only. Preserve the candidate request and deterministic selection for this Home slice. Introduce explicit display metadata locale (`en-US` / `es-ES`) on display reads and locale-scoped cache/in-flight keys. Keep Spain (`ES`) for availability, independent of language. |
| Presentation | `HomeDecisionPresentationMapper` currently consumes persisted title, anchor title, and genre names; `HomeDecisionView` renders three equal poster cards and inserts a Pick notice before the set. Add a localized **display projection** keyed by TMDB movie ID and genre ID, responsive Home composition, and stable local action state. `MovieDetailViewModel` uses the same resolved content locale on navigation, without adopting the Home layout. |
| Composition | Resolve the effective supported UI language once per load/navigation from the app's effective language (English or Spanish; unsupported language falls back to English), inject it into metadata reads and presentation, and key async publication by both locale and active set identity. No AWS SDK, account, or new backend. |

### Metadata, recovered sets, and fallback

The persisted v3 Decision Set is the *decision record*, not a locale-specific
rendering cache. It stores `localizedTitle`, anchor `movieTitle`, and optional
genre names but **does not store their source locale**. Consequently those
strings cannot prove that a restored set is in the current UI language. The
Home display projection must resolve titles for each visible movie and each
referenced anchor, plus genre names by stable IDs, from TMDB metadata requested
in the effective language. `MovieDetail` must request the same language for
the same movie. A locale change or relaunch reprojects the *same* valid set;
it does not generate another set, alter roles/scores/history, repeat session
impressions, reset Pick, or apply feedback again.

For new and restored sets, use a nonempty localized TMDB title when provided;
otherwise use its nonempty `original_title`. Never invent a translation or
print a genre ID. Missing genre labels omit that named signal and use the next
truthful explanation allowed by the accepted evidence priority. If no
explanation can be rendered truthfully, the card is not published as a
recommendation; the existing safe/partial/error behavior applies. When
offline, use a matching-locale cached metadata value if available. An existing
v3 set with no such cache may show its persisted, known title as a **legacy
recognition fallback** while metadata is unavailable, but must not represent
that title as a verified translation; reasons must omit anchor/genre labels
whose locale cannot be verified and use a truthful generic supported reason.
This is an explicit compatibility concession: no migration can reconstruct an
offline original title from v3 bytes that never stored it. A subsequent
successful hydration replaces the display labels without replacing the set.

Keep the v3 envelope unchanged in this slice. Do not rewrite the Decision Set
solely because a language changed, and do not quarantine valid older sets for
their missing locale metadata. If implementation reveals a need for durable
localized display caching, propose a separately reviewed migration preserving
exact decision IDs, Pick/session links, full shown history, quarantine bytes,
and feedback. A locale-specific cache must never contaminate another locale.
The original-title fallback and legacy exception are documentary acceptance
points in this PR; do not silently choose a different behavior in code.

Use explicit locale in formatted strings, dates, runtime, plurals, and
explanation templates. Stable movie/genre IDs remain the only cross-language
join keys. A pending `es-ES` hydration completing after a switch to `en-US`,
or a response for a superseded set, must be discarded for the visible
projection. Cancellation and bounded parallelism must not change card order.
Network metadata failure must not be misclassified as availability failure or
trigger a new recommendation cycle. Tests must cover the fallback and the
Home-to-Detail title for the same ID.

## Home layout and state behavior

- Compose by **available width and content fit**, not device name or fixed
  Figma frame height. iPhone portrait and narrow iPad use one vertical
  sequence: hero, alternatives heading, two alternatives. Wide iPad landscape
  uses hero left and stacked alternatives right. Reflow to one column before
  essential text/actions truncate. iPhone landscape preserves a readable
  scrollable experience but is not a new M9 approval gate. Support Split View,
  safe areas, keyboard/pointer, and the real tab-bar inset.
- One vertical scroll owns the content. A title, reason, provider, or action
  can grow in Dynamic Type; none may be elided to force an arbitrary card
  height. Keep the movie/role association stable when a replacement changes
  one slot. Restore focus and scroll on Detail return.
- Use backdrop where available, then a complete poster thumbnail, then a
  semantic text surface. Provider logo failure falls back to its name. The
  existing `DecisionDisplaySnapshot.backdropPath` can support the image
  hierarchy without an envelope change. A continuous scrim covers each
  visible photograph to its visible bottom edge; its opacity may be adjusted
  to meet contrast on light and dark photographs in both themes. System
  Reduce Transparency/Increase Contrast overrides decoration.
- Preserve accepted H0/H3/H1/HR/HP/HE/HF/HO/HQ/HW/HK behavior in the
  [handoff](https://github.com/cesarg88/PickOne/issues/57#issuecomment-5992956491).
  An exhausted set means **no eligible and credible recommendations after
  the accepted search**, not that the selected services contain no movies.
  Use `No picks available right now` / an approved equivalent, with the
  24-hour expiry and only actions that can change inputs. Do not expose an
  immediate deterministic no-op refresh. Retry is for a failed operation,
  never a disguised reset.
- Feedback on one movie normally replaces only its card; a reaction may
  change other cards only when their evidence is no longer valid. Keep the
  other eligible/explainable cards. Active Pick, Watchlist, watched, Not
  interested, and reactions remain identified by **movie ID**, not array
  position. Reset card-local loading/error state when that ID changes.
  During one-card replacement retain the role slot/placeholder and focus;
  publish the new card before collapsing it. A three-card refresh remains a
  separate explicit operation.
- The Pick button follows the accepted durable sequence: normal → saving
  (progress/disabled) → selected only after commit. On cancel/replace, the
  previous committed Pick stays selected until the new transaction succeeds;
  failure leaves it selected and offers contextual retry. A cancelled Swift
  task is not a user cancellation. Preserve the existing one-active-Pick
  serialization and session measurement.
- Keep success feedback in a reserved/non-blocking region **below or over**
  the set, not inserted above the cards. State transitions may animate within
  their reserved layout; Reduce Motion removes nonessential motion without
  losing state/progress. Neither Pick nor feedback should move the tapped
  control away before the interaction commits. The native ellipsis retains
  the existing four reactions plus `Already watched` and `Not interested` in
  separate groups and offers only valid actions.

## Verification and acceptance gates

Automated tests must cover: locale mapping/cache isolation; ES↔EN switch
during in-flight load and after relaunch of a persisted v3 set; offline
matching-locale cache and legacy title fallback; original title fallback;
Home→Detail title consistency; localized anchor/genre labels and no raw IDs;
unchanged set/cycle/history/Pick/session when only locale changes; one-card
replacement retaining other eligible cards; card-local state reset by movie
ID; Pick durable success/failure/cancel/replace; 24-hour exhausted expiry;
and copy in both languages by stable localization keys/semantics rather than
brittle full-sentence snapshots. Follow the normal `make verify` and CI
policy; focused simulator/UI checks complement unit tests.

Human validation before accepting Home: iPhone portrait and iPad portrait +
landscape, ES/EN × Light/Dark, 0/1/2/3 real cards, bright/dark/fallback art,
long titles/reasons/providers, maximum Dynamic Type, VoiceOver reading/action
order and focus, Reduce Motion, Reduce Transparency, Increase Contrast,
keyboard/pointer on iPad, offline/retry/exhaustion/refresh/one-card replacement,
and Pick/feedback persistence failures. Measure worst text/icon contrast
against the actual runtime image/material, including the bright iPad example;
reference thresholds are 4.5:1 normal text and 3:1 large text/essential
visual controls. Record device, OS, build SHA, settings, evidence, and limits.
Figma screenshots alone do not satisfy this gate. Physical acceptance and
issue #57 closure remain separate after implementation.

## Ordered implementation PRs after this D0 merges

| PR | Boundary | Review and merge gate |
| --- | --- | --- |
| 1 — localized display metadata | Effective ES/EN content locale, locale-scoped TMDB/detail cache, Home display projection for persisted/new sets, original/legacy fallbacks, Detail title coherence. No visual redesign. | Deterministic repository/mapper/relaunch/locale-race/offline tests. No scoring, Decision Set schema, region, or session change. |
| 2 — responsive visual composition | Hero/alternatives, available-width reflow, image hierarchy, continuous scrim, scoped semantic styles. No Pick or feedback semantics change. | iPhone portrait and iPad both orientations in focused simulator tests; bright-image contrast evidence; long text and Dynamic Type; all actionable content reachable. |
| 3 — controls and stable transitions | Native Glass Pick/ellipsis, durable saving/selected/error/retry presentation, per-card feedback state, one-card/refresh animations and no layout-shifting notice. | Pick/cancel/replace failure fixtures, movie-ID slot identity, VoiceOver focus, Reduce Motion/Transparency; no Domain behavior changes. |
| 4 — Home integration and closure | Reconcile partial/exhausted/offline/error and language/theme edges, regressions, documentation closure **for Home only**. | Full verification, accepted matrix on iPhone and physical iPad, PO/Design/Technical Lead evidence and issue #57 update. Do not claim whole M9 complete. |

Each PR starts from merged `develop`, preserves the required PR template, and
is ready for review without waiting for CI. CI must be green before merge.
Do not combine Home PRs with the separate Detail redesign. Any newly observed
Domain change or persistence migration must be proposed for review instead of
being hidden in a visual PR.

# ADR-016 — iOS and iPadOS 26 Platform Baseline

## Status

Accepted — Product Owner and Technical Lead, 2026-10-04

## Context

PickOne supports iPhone and iPad in the household pilot. Its previous minimum
deployment target was iOS/iPadOS 18.0. The Product Owner has accepted ending
support for that OS generation so the next build has a clear platform baseline
before Milestone 9 design work. A minimum deployment target is a distribution
compatibility decision, not a request to change the current UI.

## Decision

- Set `IPHONEOS_DEPLOYMENT_TARGET` to `26.0` in all project, app, unit-test, and
  UI-test Debug and Release build configurations.
- Continue to support iPhone and iPad. New builds require iOS/iPadOS 26 or
  later; iOS/iPadOS 18 devices cannot install or update to these builds unless
  they first update their OS to a supported version.
- Do not add Liquid Glass-specific APIs, new system UI components, visual
  redesign, or other product behavior in this platform-baseline change.
- Keep historical documents describing earlier iOS 18 releases unchanged.
  The current baseline is defined here, in `PRODUCT.md`, and in
  `ENGINEERING.md`.

## Alternatives Considered

Keeping the iOS/iPadOS 18 minimum and using availability checks would preserve
older-device compatibility, but would maintain two runtime support paths for
the upcoming design work. The Product Owner accepted the narrower compatibility
range for the household pilot. This ADR does not prescribe M9's design.

## Consequences and Validation

- Build with the repository's selected Xcode SDK, but test on an iOS 26
  simulator rather than assuming the SDK version proves runtime compatibility.
- Run the required unit, static-analysis, Release-build, and bundle checks.
  Inspect the resulting app bundle for `MinimumOSVersion = 26.0`.
- Exercise the focused navigation journeys on iPhone and iPad iOS 26
  simulators. These checks complement, rather than replace, physical-device
  validation.
- Before approving rollout, install the new build over an existing PickOne
  installation on a device updated to iOS/iPadOS 26 or later, without deleting
  the app. Confirm that the Viewer Profile, Watchlist, Search History, My movies,
  and Home state remain available. Raising the deployment target alone does
  not migrate or intentionally reset local data; an in-place update still
  needs evidence. If the former household installation is unavailable, record
  that limitation and use a controlled upgrade fixture rather than claiming
  physical upgrade coverage.
- Milestone 9 remains deferred until its separate product and design
  specification is accepted.

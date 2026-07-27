# Milestone 3.3 — Repository & Pilot Release Health

## Status

Complete — Basic Two-Device Pilot Passed

## Goal

Make the repository reproducible and the app reliable enough for a private
two-person pilot installed directly from Xcode.

## Delivered Scope

- iOS 18.0 deployment baseline across app and test targets
- Swift 5 language-mode baseline documented without claiming Swift 6 readiness
- shared optimized `PickOne Pilot` scheme and version `0.1.0 (1)`
- configuration validation that does not print credentials
- GitHub Actions gates for secret scanning, tests, analysis, Release build, and
  app-bundle inspection
- executable UI smoke-test target covering all four tabs
- Search request identity and stale pagination protection
- persistence mutation errors that preserve corrupted watchlist bytes
- memory-only image caching with HTTP and MIME validation
- temporary codename icon, privacy manifest, About screen, and TMDB attribution
- removal of internal tooling resources from the app bundle
- aligned setup, pilot, and validation documentation

## Exit Criteria

- complete unit and UI suite passes
- Debug and Release builds succeed
- static analysis succeeds without project warnings
- Release bundle inspection passes
- both pilot iPhones pass the checklist in `docs/pilot/pilot-checklist.md`

## Out of Scope

- TestFlight and App Store submission
- real recommendation backend or provider
- Decision Engine v1
- Ask becoming Home
- analytics
- full Swift 6 strict-concurrency migration
- final naming and visual identity

## Known Limitation

Ask remains backed by a deterministic local stub. This pilot can reveal
stability and usability problems, but it cannot validate recommendation quality
or product-market fit.

## Pilot Outcome

The build was installed and exercised successfully on both target iPhones.
This closes the basic physical-device validation required by this milestone.

Exhaustive device, accessibility, localization, performance, and long-duration
testing remains intentionally deferred until the product surface is closer to
external beta scope.

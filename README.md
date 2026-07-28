# PickOne

PickOne is an iOS app focused on helping people decide what movie to watch, faster.

The name is currently a product codename. The app is in a private two-person
pilot and remains under active development.

The canonical product definition, target experience, accepted decisions, and
open product questions live in [`PRODUCT.md`](PRODUCT.md).

---

## Requirements

- macOS with Xcode 26.4.1+
- iOS 18.0+
- TMDB API key (API Read Access Token)

---

## Setup

See [SETUP.md](SETUP.md) for local configuration, tests, and pilot installation.

---

## Notes

- Debug and Release credentials are injected through ignored xcconfig files.
- Pull requests run secret scanning, tests, static analysis, a Release build,
  and app-bundle inspection.
- `PickOne Pilot` installs an optimized Release build from Xcode.
- Ask still uses a local recommendation stub; the pilot validates product
  stability, not recommendation quality.
- This project is being developed incrementally and may change significantly over time.

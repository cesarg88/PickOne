# PickOne — Setup and Pilot Installation

## Requirements

- macOS with Xcode 26.4.1 or newer
- An iOS 18.0 or newer simulator or physical iPhone
- A TMDB API Read Access Token

## Configure TMDB

Create both ignored local configuration files:

```bash
cp Config/Debug.xcconfig.example Config/Debug.xcconfig
cp Config/Release.xcconfig.example Config/Release.xcconfig
```

Replace `YOUR_TMDB_API_KEY_HERE` in each file with the TMDB API Read Access
Token. Do not commit either generated file.

The app target validates this setting before compilation and fails without
printing the credential when it is missing or still contains the placeholder.

## Run locally

1. Open `PickOne.xcodeproj`.
2. Select the `PickOne` scheme.
3. Select an iOS 18.0 or newer simulator.
4. Build and run with `Command-R`.

A `401 Unauthorized` response normally means that the configured value is not
an API Read Access Token.

## Run the complete test suite

Select the `PickOne` scheme and use `Command-U`, or run:

```bash
xcodebuild test \
  -project PickOne.xcodeproj \
  -scheme PickOne \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=latest' \
  -parallel-testing-enabled NO
```

The main scheme includes unit tests and the UI smoke test. `PickOneTests`
alone is not the release gate.

## Install a pilot build on an iPhone

1. Connect and trust the iPhone, then enable Developer Mode if Xcode requests it.
2. Confirm the signing team for the `PickOne` target.
3. Select the shared `PickOne Pilot` scheme.
4. Select the physical iPhone and run the app.
5. Repeat for the second pilot device.

`PickOne Pilot` uses the optimized Release configuration and version `0.1.0`.
Increment `CURRENT_PROJECT_VERSION` for each replacement build.

After installation, verify discovery, search, details, Ask, watchlist
persistence after force-quit, offline degradation, About, and installation of a
new build over the existing one.

## Security boundary

`Scripts/check-secrets.sh` checks tracked source before commits and in CI.
The local xcconfig files remain ignored.

Build-time injection keeps the credential out of Git, but it does not make a
credential embedded in an iOS client secret. TMDB access must move behind the
future backend before external distribution.

# Repository Verification

## Status

Accepted

## Purpose

Provide reproducible checks for developers, implementation agents, and CI.
`make verify` mirrors the required code-PR gate. UI journeys run separately so
they remain available without delaying every pull request.

## Setup

Run once per clone:

```bash
make setup
```

This installs `pre-commit`, creates the Git hook, and prepares the pinned
SwiftFormat and SwiftLint environments declared in `.pre-commit-config.yaml`.

## Commands

- `make format` formats every Swift file with SwiftFormat.
- `make lint` lints every Swift file with SwiftLint in strict mode.
- `make quality` runs all configured pre-commit checks.
- `make test-unit` runs the full `PickOneTests` target on iPhone.
- `make test-ui` runs all `PickOneUITests` journeys on iPhone.
- `make test-ipad-ui` runs the focused iPad navigation journey.
- `make test` runs both test targets on iPhone when a full local run is useful.
- `make analyze` runs Xcode static analysis.
- `make build-release` builds and inspects the unsigned Release application.
- `make verify` runs format, all repository pre-commit checks, secret scanning,
  unit tests, static analysis, and a Release build with bundle inspection.

The required `iOS` workflow runs on every PR and push to `develop`. It always
checks secrets, formatting, and lint. For code, project, resource, workflow,
script, or other non-Markdown changes, it also runs unit tests, static analysis,
and the Release bundle check. Only changes whose entire diff consists of `.md`
files skip those app build and test steps. Unknown diffs run the full gate.

The separate `iOS UI journeys` workflow runs on `develop` on weekdays and is
available through GitHub Actions → **iOS UI journeys** → **Run workflow** for a
selected branch. Its iPhone and iPad jobs run in parallel. iPhone runs the
complete UI-test target; iPad runs only the focused portrait/landscape journey.
Run it on a PR branch before merge when the change affects a critical
end-to-end journey, onboarding, or supported-device navigation. The PR quality
check remains the required automated merge gate; the scheduled UI result is a
separate regression signal and any failure must be investigated.

Both workflows initialize CoreSimulator with
`Scripts/prepare-ci-simulator.sh`, resolve the iOS runtime matching the active
Xcode SDK, and target the booted device by identifier. This avoids depending
on an intermittently missing hosted-runner device registration.

The equivalent focused local iPad check is:

```sh
make test-ipad-ui
```

This is a functional navigation baseline, not approval of every iPad layout or
accessibility state. Milestone 9 must define and validate those separately.

PickOne deliberately applies formatting and lint to the complete repository
rather than only changed Swift files. The codebase is small enough to avoid
different local, branch, and CI scopes for those checks. The PR gate likewise
runs all unit tests rather than selecting test targets by a dependency graph.

## Commit gate

The pre-commit hook runs SwiftFormat before SwiftLint. If formatting changes a
staged file, the commit stops so the resulting diff can be reviewed and staged
again. Do not use `--no-verify` to bypass the hook.

CI repeats all pre-commit checks and remains the final authority if a local hook
was missing or bypassed.

## Lint exceptions

Fix the underlying violation whenever practical. If an exception is genuinely
necessary, disable the narrowest possible scope and include a reason on the
same line:

```swift
// swiftlint:disable:next rule_name - explain why the rule is incorrect here
```

Do not exclude a source directory or disable a rule globally to hide an
isolated violation.

## Tool version changes

Tool upgrades belong in focused pull requests. Update the pinned revision in
`.pre-commit-config.yaml`, run `make verify`, and describe any resulting source
format changes separately from behavioral work.

# Repository Verification

## Status

Accepted

## Purpose

Provide one reproducible quality contract for developers, implementation
agents, and CI. A green local verification should mean the same thing as a
green pull request check.

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
- `make test` runs the complete `PickOne` scheme, including the UI smoke test.
- `make analyze` runs Xcode static analysis.
- `make build-release` builds and inspects the unsigned Release application.
- `make verify` runs the complete local delivery gate.

GitHub Actions initializes CoreSimulator with
`Scripts/prepare-ci-simulator.sh`, resolves the iOS runtime matching the active
Xcode SDK, and targets the resulting booted device by identifier. This avoids
depending on an intermittently missing hosted-runner device registration.

PickOne deliberately checks the complete repository rather than only changed
Swift files. The codebase is small enough that full checks are fast and avoid
different local, branch, and CI scopes.

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

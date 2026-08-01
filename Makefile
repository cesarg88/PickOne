SHELL := /bin/bash

PROJECT := PickOne.xcodeproj
SCHEME := PickOne
SIMULATOR_NAME ?= iPhone 17 Pro
SIMULATOR_OS ?= latest
TEST_DESTINATION := platform=iOS Simulator,name=$(SIMULATOR_NAME),OS=$(SIMULATOR_OS)
DERIVED_DATA ?= $(CURDIR)/.derivedData

.PHONY: help setup format lint quality check-secrets test analyze build-release verify simulators devices clean

help:
	@echo "Available commands:"
	@echo "  make setup          Install and configure the local pre-commit hooks"
	@echo "  make format         Format all Swift files with the pinned SwiftFormat version"
	@echo "  make lint           Lint all Swift files with the pinned SwiftLint version"
	@echo "  make quality        Run every repository pre-commit check"
	@echo "  make test           Run unit tests and the UI smoke test"
	@echo "  make analyze        Run Xcode static analysis"
	@echo "  make build-release  Build the unsigned Release app"
	@echo "  make verify         Run the complete local delivery gate"
	@echo "  make simulators     List available iOS simulator runtimes and devices"
	@echo "  make devices        List connected physical devices"

setup:
	@command -v brew >/dev/null 2>&1 || { echo "Homebrew is required: https://brew.sh"; exit 1; }
	brew list pre-commit >/dev/null 2>&1 || brew install pre-commit
	pre-commit install --install-hooks

# SwiftFormat changes files and pre-commit reports that first pass as a
# failure. Run it a second time to prove the formatted result is stable.
format:
	pre-commit run swiftformat --all-files || pre-commit run swiftformat --all-files

lint:
	pre-commit run swiftlint --all-files

quality:
	pre-commit run --all-files --show-diff-on-failure

check-secrets:
	Scripts/check-secrets.sh

test:
	xcodebuild test \
		-project $(PROJECT) \
		-scheme $(SCHEME) \
		-destination '$(TEST_DESTINATION)' \
		-parallel-testing-enabled NO \
		-derivedDataPath '$(DERIVED_DATA)/Tests'

analyze:
	xcodebuild analyze \
		-project $(PROJECT) \
		-scheme $(SCHEME) \
		-destination 'generic/platform=iOS Simulator' \
		-derivedDataPath '$(DERIVED_DATA)/Analyze' \
		CODE_SIGNING_ALLOWED=NO

build-release:
	xcodebuild build \
		-project $(PROJECT) \
		-scheme $(SCHEME) \
		-configuration Release \
		-destination 'generic/platform=iOS' \
		-derivedDataPath '$(DERIVED_DATA)/Release' \
		CODE_SIGNING_ALLOWED=NO
	Scripts/inspect-app-bundle.sh '$(DERIVED_DATA)/Release/Build/Products/Release-iphoneos/PickOne.app'

verify: format quality check-secrets test analyze build-release

simulators:
	@xcrun simctl list runtimes available
	@xcrun simctl list devices available iOS

devices:
	@xcrun devicectl list devices

clean:
	xcodebuild clean -project $(PROJECT) -scheme $(SCHEME)

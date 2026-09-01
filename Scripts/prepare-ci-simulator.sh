#!/bin/bash

set -euo pipefail

readonly preferred_device_name="${1:-iPhone 17 Pro}"

if ! command -v jq >/dev/null 2>&1; then
    echo "jq is required to prepare the CI simulator." >&2
    exit 1
fi

# Initializing CoreSimulator explicitly avoids hosted-runner instances where
# Xcode starts before the preinstalled simulator inventory has been registered.
xcrun simctl list >/dev/null

sdk_version="$(xcrun --sdk iphonesimulator --show-sdk-version)"
readonly sdk_version
readonly runtime_name="iOS ${sdk_version}"
runtimes_json="$(xcrun simctl list runtimes available --json)"
readonly runtimes_json
runtime_identifier="$(
    jq -r \
        --arg runtime_name "$runtime_name" \
        '.runtimes[] | select(.name == $runtime_name and .isAvailable == true) | .identifier' \
        <<< "$runtimes_json" \
        | head -n 1
)"
readonly runtime_identifier

if [[ -z "$runtime_identifier" ]]; then
    echo "No available ${runtime_name} simulator runtime matches the active Xcode." >&2
    echo "Available simulator runtimes:" >&2
    jq -r '.runtimes[] | select(.isAvailable == true) | "- \(.name) (\(.identifier))"' \
        <<< "$runtimes_json" >&2
    exit 1
fi

device_types_json="$(xcrun simctl list devicetypes --json)"
readonly device_types_json
device_type_identifier="$(
    jq -r \
        --arg device_name "$preferred_device_name" \
        '.devicetypes[] | select(.name == $device_name) | .identifier' \
        <<< "$device_types_json" \
        | head -n 1
)"
readonly device_type_identifier

if [[ -z "$device_type_identifier" ]]; then
    echo "Simulator device type '${preferred_device_name}' is unavailable." >&2
    exit 1
fi

devices_json="$(xcrun simctl list devices available --json)"
simulator_udid="$(
    jq -r \
        --arg runtime_identifier "$runtime_identifier" \
        --arg device_name "$preferred_device_name" \
        '.devices[$runtime_identifier][]? | select(.name == $device_name and .isAvailable == true) | .udid' \
        <<< "$devices_json" \
        | head -n 1
)"

if [[ -z "$simulator_udid" ]]; then
    echo "Creating ${preferred_device_name} for ${runtime_name}." >&2
    simulator_udid="$(
        xcrun simctl create \
            "PickOne CI ${preferred_device_name}" \
            "$device_type_identifier" \
            "$runtime_identifier"
    )"
fi

echo "Waiting for ${preferred_device_name} (${simulator_udid}) to finish booting." >&2
xcrun simctl bootstatus "$simulator_udid" -b >&2
printf '%s\n' "$simulator_udid"

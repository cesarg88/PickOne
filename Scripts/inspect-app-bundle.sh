#!/bin/sh

set -eu

app_path="${1:-}"

if [ -z "$app_path" ] || [ ! -d "$app_path" ]; then
    echo "usage: $0 /path/to/PickOne.app"
    exit 2
fi

forbidden_paths="$(find "$app_path" \( \
    -name '.cursor' -o \
    -name '.DS_Store' -o \
    -name '*.md' -o \
    -name '*.mdc' -o \
    -name '*.xcconfig' \
\) -print)"

if [ -n "$forbidden_paths" ]; then
    echo "error: internal files found in app bundle:"
    echo "$forbidden_paths"
    exit 1
fi

if [ ! -f "$app_path/PrivacyInfo.xcprivacy" ]; then
    echo "error: PrivacyInfo.xcprivacy is missing from the app bundle."
    exit 1
fi

if [ ! -f "$app_path/Assets.car" ]; then
    echo "error: compiled asset catalog is missing from the app bundle."
    exit 1
fi

echo "App bundle inspection passed."

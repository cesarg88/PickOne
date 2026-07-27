#!/bin/sh

set -eu

if [ "${PICKONE_ALLOW_PLACEHOLDER_KEY:-NO}" = "YES" ]; then
    if [ -n "${SCRIPT_OUTPUT_FILE_0:-}" ]; then
        touch "$SCRIPT_OUTPUT_FILE_0"
    fi
    exit 0
fi

key="${TMDB_API_KEY:-}"

if [ -z "$key" ] || [ "$key" = "YOUR_TMDB_API_KEY_HERE" ]; then
    echo "error: TMDB_API_KEY is missing. Configure Config/Debug.xcconfig and Config/Release.xcconfig."
    exit 1
fi

case "$key" in
    *[[:space:]]*)
        echo "error: TMDB_API_KEY contains whitespace. Check the local xcconfig file."
        exit 1
        ;;
esac

if [ -n "${SCRIPT_OUTPUT_FILE_0:-}" ]; then
    touch "$SCRIPT_OUTPUT_FILE_0"
fi

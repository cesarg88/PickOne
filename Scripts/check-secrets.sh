#!/bin/sh

set -eu

pattern='eyJ[A-Za-z0-9_-]{20,}\.[A-Za-z0-9_-]{20,}\.[A-Za-z0-9_-]{20,}|sk-[A-Za-z0-9_-]{20,}|AIza[A-Za-z0-9_-]{20,}|-----BEGIN (RSA |EC |OPENSSH )?PRIVATE KEY-----|TMDB_API_KEY[[:space:]]*=[[:space:]]*[A-Fa-f0-9]{32}'

matches="$(
    git grep -IlE "$pattern" -- \
        . \
        ':(exclude)Scripts/check-secrets.sh' \
        ':(exclude)*.example' \
        || true
)"

if [ -n "$matches" ]; then
    echo "Potential secrets found in tracked files:"
    echo "$matches"
    exit 1
fi

echo "No potential secrets found in tracked files."

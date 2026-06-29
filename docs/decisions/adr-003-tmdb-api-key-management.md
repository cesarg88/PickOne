# ADR-003 — TMDB API Key Management
## Status
Accepted
## Context
The app needs TMDB access during local and CI builds without committing secrets.
## Decision
Inject TMDB credentials through ignored xcconfig files and CI secrets.
## Consequences
Secrets must not be committed to the repository, shared schemes, or source files.

# GitHub App Authentication Policy

## Status

Accepted and mandatory for all repository write operations.

## Required Identity

All automated GitHub activity for PickOne must be attributed to:

```text
Cesar-IA-Agent
cesar-ia-agent[bot]
```

Personal or work identities must never be used as a fallback.

## Local Configuration

Non-secret App metadata and the local PEM path are stored in this repository's
local Git configuration. They are deliberately not committed.

Required keys:

```text
pickone.githubApp.appId
pickone.githubApp.clientId
pickone.githubApp.installationId
pickone.githubApp.pemPath
pickone.githubApp.actor
pickone.githubApp.actorEmail
pickone.githubApp.repository
```

An agent must read these values with `git config --local --get`. It must not
hardcode machine-specific values into source files, documentation, commands
that will be committed, or PR content.

If any key is missing, stop and ask for the local App configuration to be
restored.

## Mandatory Preflight

Before a commit or GitHub write:

1. Confirm the expected actor from `pickone.githubApp.actor`.
2. Confirm local `user.name` and `user.email` match the configured App actor.
3. Confirm `origin` uses the neutral HTTPS repository URL.
4. Confirm local `credential.helper` is empty.
5. Resolve the PEM path from local Git configuration.
6. Confirm the PEM exists and has no group or other permissions (`0600`).
7. Confirm the current branch and intended remote target.

Do not print the PEM, JWT, installation token, HTTP authorization header, or
credential-helper output.

## Authentication Flow

Use App-installation authentication rather than user-to-server authentication:

1. Generate a short-lived RS256 JWT from the configured App Client ID and PEM.
   - set `iat` approximately 60 seconds in the past
   - set `exp` no more than 10 minutes in the future
2. Resolve or verify the installation for the configured repository.
3. Request an installation access token scoped only to `PickOne`.
4. Verify the token permissions required by the operation.
5. Keep the token only in process memory.
6. Allow the token to expire; do not cache or persist it.

Typical required repository permissions:

- `metadata: read`
- `contents: write` for Git pushes and content changes
- `pull_requests: write` for PR creation or updates
- `workflows: write` when changing `.github/workflows`

If a permission is missing, stop and report the exact missing permission. Never
retry with a user credential.

## Git Operations

For HTTP Git authentication:

- use `x-access-token` as the username
- use the installation token as the password
- prefer a transient HTTP Basic authorization header
- keep the committed remote URL free of embedded credentials

The installation token must not appear in:

- `.git/config`
- shell history
- command output
- environment files
- temporary files
- tracked files
- issue, PR, or review text

After pushing, verify that the remote branch points to the intended commit.

## Pull Requests and Reviews

Create or modify PRs using the installation token and GitHub API.

After a write, verify the returned actor is:

```text
cesar-ia-agent[bot]
```

If the actor differs, treat the operation as an identity failure and stop
further writes.

## Explicitly Forbidden

Do not use the following for PickOne write operations:

- `gh auth login`
- the globally active `gh` token or account
- `git@github.com` or personal SSH host aliases
- macOS Keychain or stored personal Git credentials
- the `cesar-fever` work account
- the `cesarg88` user identity
- a personal access token

Read-only access to public GitHub API endpoints is acceptable when App
permissions do not expose Actions details. It must not mutate GitHub state.

## Failure Policy

Authentication failure is a hard blocker, not a reason to change identity.

When blocked:

1. preserve local commits and working-tree state
2. report the failed operation
3. report the missing permission or configuration
4. wait for the App configuration to be corrected
5. generate a new installation token and retry only as the App

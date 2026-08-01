# smart-commit

Create a commit from the changes the user has intentionally staged.

1. Read `docs/process/github-app-authentication.md` and complete its mandatory
   preflight. Stop if the configured identity is not `Cesar-IA-Agent`.
2. Inspect `git status --short`, `git diff --cached --stat`, and the complete
   staged diff. Ignore unstaged changes.
3. Stop if nothing is staged or if the staged diff contains unrelated work.
4. Generate a precise Conventional Commit message from the staged diff.
5. Commit without `--no-verify` so the formatting and linting hook runs. If a
   hook modifies a file, stop and ask for the resulting diff to be reviewed and
   staged intentionally before retrying.
6. Report the resulting commit hash. `make verify` remains mandatory before
   handoff or pull-request creation.

## Commit Guidelines

**IMPORTANT**: This command MUST follow the commit guidelines defined in `.cursor/rules/commit-guidelines.mdc`. Please read and apply all guidelines from that file when generating commit messages.

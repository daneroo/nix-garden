# Workspace

## Quality Gate

`just check` is the required repository quality gate after edits and before
commits.

Grow this one command as formatting, linting, and tests are adopted. Automated
CI should run the same gate rather than maintain a separate definition.

## System Changes

- `just plan` checks, builds, and diffs against the running system, without
  touching locked inputs or switching anything -- safe to run non-interactively
  (agents, CI).
- `just update` bumps locked inputs, then runs `plan`.
- `just apply` runs `plan`, asks for confirmation, and then switches the target
  host to the resulting configuration.

Agents may run the non-destructive gates (`check`, `plan`) as verification.
Switching the live system, or updating locked inputs, requires an explicit user
request.

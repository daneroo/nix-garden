# Workspace

## Quality Gate

`just pre-commit` is the required repository quality gate after edits and before
commits. `scripts/pre-commit.sh` is the source of truth for its current checks.

Grow this one command as formatting, linting, and tests are adopted. Automated
CI should run the same gate rather than maintain a separate definition.

## System Changes

- `just pre-flight` checks, previews, and builds without switching the running
  system.
- `just apply` runs the pre-flight gate, asks for confirmation, and then
  switches `hardy` to the resulting configuration.

Agents may run the non-destructive gates as verification. Switching the live
system requires an explicit user request.

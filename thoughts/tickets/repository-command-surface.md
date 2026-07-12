# Repository command surface

Goal: make system changes on `hardy` legible and safe without exposing Nix's
internal command taxonomy.

## Contract

- `just plan` checks Git and flake state, optionally updates locked inputs, then
  calls `just check` before building and comparing desired with running.
- `just apply` replans without updates, confirms, switches, and verifies.
- Bare `just` documents only `plan`, `apply`, and `check`; private helpers keep
  commands visible and report concise failures with an obvious next step.
- Move `hardy` to locked `nixos-unstable` and remove repetitive sudo
  authentication while retaining explicit activation confirmation.

## Acceptance

- Exercise `plan` without and with an input update.
- Apply on `hardy`; verify the generation, core services, and updated Codex.
- Document the workflow and straightforward recovery path.

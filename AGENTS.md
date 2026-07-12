# AGENTS.md

Canonical repository instructions for agents and humans.

`nix-hardy` is the reproducible NixOS configuration for `hardy`, an ASUS
Chromebook Flip C436F / Google Helios with MrChromebox firmware.

## Quality

- `just pre-commit` — the required quality gate after edits and before commits.
- `just pre-flight` — check, preview, and build before changing the running
  system.

## Execution

- When planning, shape coding tasks so model class and effort can be selected
  per task. State the relevant context, boundaries, dependencies, risk,
  acceptance criteria, and verification.
- For coding tasks, use judgment to select an appropriate lower-power subagent
  model and effort level. Reassess the plan's recommendation when execution
  reveals additional complexity or risk.
- Keep integration, architectural judgment, and final verification with the
  coordinating agent.

## Layout

- `docs/` — durable reference, indexed by [docs/README.md](docs/README.md).
- `thoughts/` — backlog and transient working material; see
  [docs/workflow.md](docs/workflow.md).
- `scripts/` — reviewed bootstrap, operational, and quality-check helpers.

Do not run `just apply` unless the user asks to switch the running system; it
performs the pre-flight checks and then requests confirmation.

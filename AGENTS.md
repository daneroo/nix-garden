# AGENTS.md

Canonical repository instructions for agents and humans.

`nix-garden` is the reproducible configuration and operational control plane for
Daniel's homelab. `hardy`, an ASUS Chromebook Flip C436F / Google Helios, is the
first managed host.

## Quality

- `just pre-commit` — required after edits and before commits; see
  [docs/workspace.md](docs/workspace.md).
- `just pre-flight` — check, preview, and build before changing the running
  system.

## Execution

- Follow the planning and delegation rules in
  [docs/workflow.md](docs/workflow.md#plans).

## Layout

- `docs/` — durable reference, indexed by [docs/README.md](docs/README.md).
- `thoughts/` — backlog and transient working material; see
  [docs/workflow.md](docs/workflow.md).
- `scripts/` — reviewed bootstrap, operational, and quality-check helpers.

Do not run `just apply` unless the user asks to switch the running system; it
performs the pre-flight checks and then requests confirmation.

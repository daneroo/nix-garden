# AGENTS.md

Canonical repository instructions for agents and humans.

`nix-garden` is the reproducible configuration and operational control plane for
Daniel's homelab. `hardy`, an ASUS Chromebook Flip C436F / Google Helios, is the
first managed host.

## Quality

- `just check` — required after edits and before commits; see
  [docs/workspace.md](docs/workspace.md).
- `just plan` — check, build, and diff before changing the running system; never
  touches locked inputs, safe to run non-interactively.

## Execution

- Follow the planning and delegation rules in
  [docs/workflow.md](docs/workflow.md#plans).

## Layout

- `docs/` — durable reference, indexed by [docs/README.md](docs/README.md).
- `thoughts/` — backlog and transient working material; see
  [docs/workflow.md](docs/workflow.md).
- `scripts/` — reviewed bootstrap, operational, and quality-check helpers.

Do not run `just apply` unless the user asks to switch the running system; it
runs `just plan` and then requests confirmation.

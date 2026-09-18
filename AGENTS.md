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
- `scripts/` — reviewed bootstrap, operational, and quality-check helpers. A
  script earns a file when it is run outside `just`, or is long enough that
  reading it inline obscures the recipe; otherwise it stays in the `Justfile`.
- `hosts/` — `hosts/default.nix` is the machine inventory; every other entry is
  one machine, keyed by hostname, holding its hardware file, its aspect
  selection, and its exceptions.
- `modules/` — auto-imported by import-tree: one feature per file, grouped by
  the aspect directory it registers into (`base`, `desktop`, `gnome`; `e2e` is
  the harness). A file here is live the moment it exists; see
  [docs/module-architecture.md](docs/module-architecture.md).
- `tests/` — VM checks run by `just e2e-vm`, never by `just check`.

Do not run `just apply` unless the user asks to switch the running system; it
runs `just plan` and then requests confirmation.

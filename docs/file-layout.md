# File Layout

```text
flake.nix
hosts/
  default.nix
  hardy/
    default.nix
    hardware-configuration.nix
modules/
  base/
  desktop/
  gnome/
  e2e/
tests/

docs/
  README.md
  bootstrap.md
  coding-style.md
  file-layout.md
  gauss-hardware.md
  hardy-firmware-history.md
  keybindings.md
  markdown.md
  performance.md
  reconciliation.md
  throttling.md
  workflow.md
  workspace.md

scripts/
  audit-host.sh
  bootstrap-apply.sh

thoughts/
  BACKLOG.md
  design/
    feature.md
  plans/
    feature.md
    archive/
      done-feature-to-preserve.md
  research/
  reviews/
  tickets/
    feature.md
```

- `hosts/`: the machine inventory and one directory per host; `modules/`:
  auto-imported features grouped by aspect; `tests/`: the VM suite body. See
  [module-architecture.md](module-architecture.md).
- `docs/`: durable reference, indexed by [README.md](README.md).
- `scripts/`: reviewed helper scripts for bootstrap, operations, and local
  checks.
- `thoughts/`: backlog plus transient plans, designs, tickets, research, and
  reviews; see [workflow.md](workflow.md).

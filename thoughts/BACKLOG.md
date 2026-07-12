# Backlog

Unscheduled work, grouped by theme. Keep entries brief; move growing detail to
`tickets/` as described in [docs/workflow.md](../docs/workflow.md). Working
direction: [homelab-platform](design/homelab-platform.md).

## Now

- [ ] legacy-harvest — turn useful legacy findings into focused backlog items,
      then delete `legacy/` from the working tree; Git retains the history.
- [ ] nix-formatting — choose and integrate the repository's Nix formatter and
      formatting check; high priority; ticket:
      [nix-formatting](tickets/nix-formatting.md)
- [ ] shared-repo-workflow — test and extract the reusable docs/thoughts
      workflow, then share the settled convention with Prosodio; ticket:
      [shared-repo-workflow](tickets/shared-repo-workflow.md)

## Fleet and Recovery

- [ ] host-inventory — inventory homelab machines, hardware, architecture,
      roles, criticality, and current state; ticket:
      [host-inventory](tickets/host-inventory.md)
- [ ] recovery-contract — define and exercise the minimum-fuss wipe, rebuild,
      restore, and verify path while `hardy` is non-load-bearing.
- [ ] multi-host-layout — evolve from one host to reusable roles and features
      only when the inventory provides a concrete second consumer.

## Stateful Operations

- [ ] state-boundary — inventory state not owned by Nix: disks, secrets,
      backups, workload data, migrations, and remote resources.
- [ ] backup-reconciliation — define backup desired state, observation,
      convergence, restore testing, and failure reporting.
- [ ] safe-host-updates — design preview, drain, update, health verification,
      rollback, and recovery for machines with running workloads.
- [ ] storage-lifecycle — revisit Disko and filesystem choices with destructive
      testing, recovery, and data-lifecycle requirements defined first.

## Desktop

- [ ] desktop-baseline — build a daily-usable Linux desktop on `hardy` before
      optimizing or generalizing it.
- [ ] compositor-selection — evaluate Niri and Hyprland against real desktop
      workflows, hardware behavior, and testability.
- [ ] keybinding-model — design macOS-consistent bindings across the compositor,
      terminal, editor, browser, launcher, and selected applications.
- [ ] desktop-test-harness — explore VM or container-backed graphical testing
      and agent computer-use validation for bindings and window behavior.

## Virtualization

- [ ] incus-host — evaluate Incus as the homelab VM and system-container layer,
      including storage, networking, backup, and upgrades.
- [ ] nixos-guests — decide how NixOS VM/container guests share the flake,
      inventory, roles, and reconciliation model with physical hosts.
- [ ] virtualization-test-lab — use Incus and the two available Proxmox hosts to
      accelerate rebuild, upgrade, recovery, and destructive workflow testing.

## Networking

- [ ] network-inventory — inventory subnets, VLANs, DNS, DHCP, routing, UniFi,
      Tailscale, and ownership boundaries.
- [ ] tailscale-reconciliation — define desired membership, identity, routes,
      ACLs, keys, health, and recovery.
- [ ] unifi-reconciliation — determine which router, DHCP, and network state can
      be safely observed, planned, applied, and verified.

## Nix Platform

- [ ] Decide whether to add Home Manager later.
- [ ] If adding `thermald`, first revisit `docs/throttling.md`.
- [ ] Decide whether to track NixOS release branches or `nixos-unstable`.
- [ ] nixpkgs-unstable — evaluate moving to `nixos-unstable` or mixing unstable
      packages for fresher developer tools, especially Codex.
- [ ] module-architecture — evaluate flake-parts, import-tree, and wrapped
      program modules after real host/feature boundaries emerge.
- [ ] development-environments — harvest useful nixvana lessons into development
      shells exercised by real projects, CI, and agent workflows.
- [ ] reconciliation-pattern — turn [reconciliation](../docs/reconciliation.md)
      into concrete conventions and reusable checks as dynamic systems appear.
- [ ] clan-reference — study Clan's solutions for fleet management, secrets,
      backups, networking, and installation before designing equivalents.
- [ ] nh-iteration — evaluate `nh` for planned diffs, activation, rollback, and
      generation management in the normal host workflow.
- [ ] related-reconcilers — inventory reusable lessons and boundaries from the
      `dotfiles` Go reconcilers and `qcic` operations experiments.

## Self-Hosting Development

- [ ] hardy-current-state — verify whether the committed configuration is
      currently applied and record the running generation and drift.
- [ ] hardy-dev-loop — make `hardy` the primary editor and executor of this
      repo: clone, authenticate, edit, check, preview, apply, verify, commit,
      and push.
- [ ] remote-access — configure and verify SSH access suitable for development
      and recovery without weakening host security.
- [ ] herdr-workflow — package and validate Herdr on `hardy`, including
      persistence, remote attach, clipboard behavior, and agent integrations.

## Repository Workflow

- [ ] concise-agent-docs — make agent-facing instructions in nix-garden and
      Prosodio substantially shorter and easier to scan; ticket:
      [concise-agent-docs](tickets/concise-agent-docs.md)
- [ ] shared-workflow-skill — explore packaging the settled repository workflow
      as a personal, harness-neutral Agent Skill shared through Git; ticket:
      [shared-workflow-skill](tickets/shared-workflow-skill.md)
- [ ] repository-command-surface — rationalize, justify, and refine the roles of
      `Justfile`, `scripts/`, package-managed commands, and a possible Nix
      `devShell`; ticket:
      [repository-command-surface](tickets/repository-command-surface.md)

## Documentation

- [ ] hardy-hardware-notes — decide whether to keep or consolidate the inherited
      performance and throttling notes for `hardy`; ticket:
      [hardy-hardware-notes](tickets/hardy-hardware-notes.md)

## Closed (newest first)

One line per closed item — this section doubles as the ticket archive index.
Prune old lines freely; Git keeps everything.

- 2026-07-12 migrate-to-nix-garden — consolidated both repository histories and
  made nix-garden the verified live fleet repository; plan:
  [migrate-to-nix-garden](plans/archive/migrate-to-nix-garden.md)

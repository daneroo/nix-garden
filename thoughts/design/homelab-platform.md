# Homelab Platform

Working vision for `nix-garden`, the configuration and operational control plane
for Daniel's homelab. `hardy` is the first managed host.

## Goals

- Declarative, repeatable, idempotent configuration for all homelab machines.
- A machine inventory with explicit roles, hardware, architecture, and state.
- Low-friction recovery: while a host is non-load-bearing, wiping and rebuilding
  it should be practical and routinely testable.
- Operational handling for state Nix does not solve: disks, backups, secrets,
  workload data, migrations, and updates of running systems.
- A usable Linux desktop alternative to macOS, initially exploring Niri or
  Hyprland with deliberate cross-platform keybinding design.
- Incus as the leading hypervisor/container candidate, with NixOS guests
  configured from the same flake where that remains coherent.
- Network configuration and reconciliation, including Tailscale and selected
  UniFi router/DHCP state.
- Effective Nix development and testing, including VM/container experiments and
  agent-assisted validation of desktop behavior and keybindings.
- Modern Nix patterns without novelty for its own sake. Understand abstractions,
  reuse proven modules, and move quickly once reproducibility and recovery are
  real.
- Desired-versus-actual reconciliation as the operational model beyond Nix's
  declarative configuration boundary.
- A self-hosting development loop on `hardy`: edit, review, build, apply,
  verify, recover, and push primarily from the machine being configured.
- Physical hosts may combine desktop and server roles. `hardy` can deploy server
  workloads as well as drive desktop development.
- `gauss`, a Beelink SER8 onboarded as NixOS's second managed host (2026-07-23,
  see [gauss-hardware](../../docs/gauss-hardware.md)), and a Bluefin iMac with a
  spare drive provide low-risk physical test targets.

## Two Physical-Host Objectives

`hardy` and `gauss` are not redundant; they anchor the two concrete objectives
this platform exists to serve, and each host earns broader responsibility only
as it proves itself.

- **A desktop worth using daily.** This is chiefly a keybindings and ergonomics
  problem: consistency with macOS across the compositor, terminal, editor,
  browser, and launcher. `hardy` surfaced a confound rather than an answer — its
  Chromebook keyboard has no Cmd/Super key, so keybinding decisions made there
  are contaminated by that non-standard layout. Keybinding tuning should move to
  `gauss`, which has a standard keyboard layout, and settled bindings should
  then be backported to `hardy` and verified there.
- **A virtualization platform.** `gauss` has the strongest hardware in the fleet
  (8 cores/16 threads, 27 GiB RAM) for driving Incus-based VM/container
  workflows, explicitly as a blueprint for, and possible eventual replacement
  of, the existing Proxmox hosts.

Sequencing: `gauss` starts as a clone of `hardy`'s configuration — proving the
desktop setup is portable to a second machine, not just hardy-specific — before
its virtualization role grows on top, consistent with not generalizing from one
host prematurely.

## Lessons From Earlier Attempts

- The earlier `nix-garden` explored custom installer ISOs, minimal x86/ARM and
  installer configurations, Disko, Proxmox provisioning, Clan, Incus, and
  non-NixOS management. These were informative rabbit holes; most are
  superseded, reproducible, or lower priority than a useful host and fast loop.
- `nixvana` proved flakes, direnv, devcontainers, Home Manager experiments, and
  repeatable development shells, but was not validated against sustained real
  work.
- This attempt starts with a useful real host. Expand bootstrap automation and
  abstractions only as they support exercised workloads and recovery goals.
- The `dotfiles` repository contains working Go reconciliation loops for tools
  such as Homebrew, Stow, and global packages. `qcic` explores monitoring,
  alerting, and self-healing. They are related systems and sources of patterns,
  not automatic merge targets.

## Candidate Architecture

- Thin flake entry point.
- Host inventory and host-specific hardware/configuration modules.
- Reusable feature or role modules.
- Separate desired configuration from stateful operational reconcilers.
- Flake outputs for hosts, development environments, formatters, checks, and
  test artifacts where useful.
- Consider flake-parts, import-tree, and wrapped program modules after module
  boundaries are demonstrated by more than one host or feature.
- Treat Clan as a reference architecture for fleet management, installation,
  secrets, networking, services, and backups; evaluate adoption only after the
  local iteration loop is safe.
- Evaluate `nh` for readable build trees, activation diffs, confirmation,
  generation management, and rollback ergonomics.
- Use SSH and Herdr to make persistent agent sessions on `hardy` accessible from
  other machines while keeping work on the target host.

## Guardrails

- Do not automate destructive storage work before preview, recovery, and test
  paths exist.
- Do not declare a service reproducible while its data, backup, restore, and
  migration paths are undefined.
- Do not generalize from one host prematurely.
- Prefer small reversible steps and evidence from real use.
- Once the iteration, preview, rollback, and recovery loop is proven, permit
  larger architectural steps with proportionate verification.
- Keep current facts in docs, open decisions here or in tickets, and executable
  work in plans.

## References

- [Vimjoyer: flake-parts and wrapped modules](https://www.vimjoyer.com/vid79-parts-wrapped)
- [Clan](https://clan.lol/)
- [`nh`](https://github.com/nix-community/nh)
- [Herdr](https://herdr.dev/)
- [Community Herdr flake](https://github.com/ogulcancelik/herdr)

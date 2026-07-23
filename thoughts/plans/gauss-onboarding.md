# Gauss Onboarding

Status: planned

Goal: install NixOS on `gauss` (Beelink SER8) as a verified clone of `hardy`,
generalizing the flake/`Justfile`/bootstrap script to multi-host in the process,
per [homelab-platform](../design/homelab-platform.md)'s two-objective framing.

Folds in the `multi-host-layout` backlog item — it has no independent scope
outside this work.

## Context

- `gauss`'s internal NVMe currently runs Omarchy; it may be fully wiped.
- Pre-install hardware/storage baseline:
  [gauss-hardware](../../docs/gauss-hardware.md).
- Decisions behind this plan (resolved by interview, not re-litigated here):
  install via USB NixOS ISO; partition layout mirrors `hardy` exactly (single
  btrfs partition, `root`/`home`/`nix` subvolumes, vfat `/boot`, ~16GiB fixed
  swap, no hibernation); host selection by `hostname` auto-detect; shared SSH
  key (`daniel@galois`); temporary passwordless wheel, matching `hardy`; DHCP
  via NetworkManager; `stateVersion = "26.05"`; `bootstrapPackages` promoted to
  a list shared by both hosts, adding `claude-code` alongside the existing
  `codex`.
- Done means: `gauss` boots, is SSH-reachable with the shared key, and
  `just check` / `just plan` run clean when executed on `gauss` itself.
- Execution handoff: once Claude Code is installed and authenticated on `gauss`,
  work moves onto `gauss` itself via a Herdr session reattached from `galois` —
  matching the self-hosting development loop already proven on `hardy`. Steps
  after that point are driven from the `gauss`-side session, not orchestrated
  remotely.

## Steps

- [x] Generalize `flake.nix` to multi-host: promote `bootstrapPackages` to a
      list shared by both hosts (add `claude-code` alongside `codex`), and
      produce `nixosConfigurations.hardy` and `.gauss` from a small host
      list/map instead of one hardcoded output. Update the flake `description`.
      `[tier: med]`
- [x] Generalize `Justfile`'s `flake := ".#hardy"` to derive the target from
      `hostname` at run time; keep the existing `/run/current-system` guard. Add
      a small "blessed hosts" check (`hardy`, `gauss`) that fails clearly on an
      unrecognized hostname — low priority, but requested. `[tier: low]`
- [x] Generalize `scripts/bootstrap-apply.sh` the same way (hostname-derived
      flake target instead of hardcoded `.#hardy`). This script has never been
      exercised end-to-end; treat the `gauss` install as its first real proof.
      `[tier: med]`
- [x] Create `hosts/gauss/default.nix` as a clone of `hosts/hardy/default.nix`
      with only `networking.hostName = "gauss"` changed (everything else — GNOME
      desktop, NetworkManager, timezone, locale, SSH key, passwordless wheel
      with its caveat comment, `stateVersion "26.05"` — stays identical).
      `hosts/gauss/hardware-configuration.nix` cannot be written yet; it comes
      from step below. `[tier: low]`
- [x] Run `just check` and `nix flake check` against the new multi-host flake
      (buildable even before `gauss`'s hardware-configuration.nix exists is not
      possible — confirm the flake at least evaluates cleanly for `hardy` and
      that `gauss`'s output is structurally wired correctly). `[tier: low]`
- [x] Commit the plan to `main`, branch `gauss-onboarding`, and commit the
      multi-host flake groundwork and `hosts/gauss/default.nix` (without
      hardware-configuration.nix yet) on that branch. `[tier: low]`
- [ ] **Manual runbook — physical install (Daniel, hands-on at the machine):**
      `[tier: high]`
  - [ ] Write the official NixOS ISO to a USB stick.
  - [ ] Boot `gauss` from the USB stick.
  - [ ] Wipe the Omarchy install; partition the internal NVMe: ~512MiB vfat EFI
        `/boot`, ~16GiB swap partition, remaining space as one btrfs partition
        with `root`/`home`/`nix` subvolumes (mirrors `hardy`).
  - [ ] Run `nixos-generate-config` to produce
        `hosts/gauss/hardware-configuration.nix`.
  - [ ] Complete a minimal `nixos-install` sufficient to boot and reach the
        network (bridge to the flake-managed config happens next, via
        `bootstrap-apply.sh`, not in this minimal install).
  - [ ] Reboot into the minimal install, clone `nix-garden`, check out the
        `gauss-onboarding` branch, and copy the generated
        `hardware-configuration.nix` into `hosts/gauss/`.
- [ ] Run the generalized `scripts/bootstrap-apply.sh` on `gauss` (flake check,
      build, confirm, then `switch` to `.#gauss`) — first real end-to-end proof
      of the documented bootstrap path. `[tier: med]`
- [ ] Log in to Claude Code on `gauss` (and Codex, matching the pattern recorded
      for `hardy`'s bootstrap). `[tier: low]`
- [ ] **Execution handoff:** open a Herdr session on `gauss` and reattach it
      from `galois`; confirm native agent detection surfaces Claude Code (and
      Codex) in the session, same as verified for `hardy`. All remaining steps
      below run from this `gauss`-side session, not orchestrated remotely.
      `[tier: med]`
- [ ] Verify (from the `gauss`-side session; confirm reachability by SSH from
      `galois`): `just check` and `just plan` run clean on `gauss` itself.
      `[tier: low]`
- [ ] Commit `hosts/gauss/hardware-configuration.nix` and any install-time
      fixes; push the branch. `[tier: low]`
- [ ] Harvest durable facts back into `docs/` and `thoughts/`: `[tier: low]`
  - [ ] Update [gauss-hardware](../../docs/gauss-hardware.md) or add a
        post-install note distinguishing pre-install baseline from the installed
        system.
  - [ ] Fill in `gauss`'s real fields in
        [host-inventory](../tickets/host-inventory.md).
  - [ ] Update `thoughts/BACKLOG.md`: remove/fold the now-redundant
        `multi-host-layout` line and move this item to `## Closed` with the
        outcome and a link to this plan.
- [ ] Merge `gauss-onboarding` into `main` locally (no PR, matching current repo
      convention); Daniel decides whether to delete or archive this plan file
      afterward. `[tier: low]`

## Explicitly Deferred (not this plan)

- Storage/subvolume layout changes for future VM/container workloads (Incus).
- Static IP / DHCP reservation for `gauss`.
- Keybinding/desktop tuning work itself (this plan only gets `gauss` to a GNOME
  baseline identical to `hardy`'s).
- Dropping passwordless sudo (revisit before either host carries real
  workloads).

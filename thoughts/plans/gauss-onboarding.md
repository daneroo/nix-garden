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
- [x] **Manual runbook — physical install (Daniel, hands-on at the machine):**
      `[tier: high]` — actual install used the graphical/Calamares installer
      (erase disk, btrfs, plain swap/no hibernate) rather than manual `parted`;
      layout still mirrors hardy's shape and `nixos-generate-config` captured it
      faithfully.
  - [x] Write the official NixOS ISO to a USB stick.
  - [x] Boot `gauss` from the USB stick.
  - [x] Wipe the Omarchy install; partition the internal NVMe: vfat EFI `/boot`,
        swap partition, remaining space as one btrfs partition with `home`/`nix`
        subvolumes and `/` on the top-level subvolume (mirrors `hardy`'s actual
        layout).
  - [x] Run `nixos-generate-config` to produce
        `hosts/gauss/hardware-configuration.nix`.
  - [x] Complete a minimal install sufficient to boot and reach the network.
  - [x] Remove the USB stick and reboot; confirmed NVME/Linux Boot Manager as
        the boot entry.
  - [x] Log into the minimal install, clone `nix-garden`, check out the
        `gauss-onboarding` branch, and copy the generated
        `hardware-configuration.nix` into `hosts/gauss/`.
- [x] Run the generalized `scripts/bootstrap-apply.sh` on `gauss` (flake check,
      build, confirm, then `switch` to `.#gauss`) — first real end-to-end proof
      of the documented bootstrap path. `[tier: med]`
- [x] Log in to Claude Code on `gauss` (Codex login deferred; not blocking).
      `[tier: low]`
- [x] **Execution handoff:** `herdr --remote gauss` from `galois` confirms
      Claude Code v2.1.214 running in `~/nix-garden` on `gauss`, with native
      agent detection surfacing it under agents → nix-garden → claude, same
      pattern verified for `hardy`. Remaining steps below run from that
      `gauss`-side session. `[tier: med]`
- [x] Verify (SSH reachability from `galois`, confirmed with the shared key
      after starting `sshd` and applying the firewall's `openFirewall` rule):
      `just check` and `just plan` run clean on `gauss` itself. `[tier: low]`
- [x] Commit `hosts/gauss/hardware-configuration.nix` and any install-time
      fixes; push the branch. `[tier: low]`
- [x] Harvest durable facts back into `docs/` and `thoughts/`: `[tier: low]`
  - [x] Documented the bootstrap sshd/firewall gotcha in `docs/bootstrap.md` as
        a known first-switch check for future hosts.
  - [x] Updated [gauss-hardware](../../docs/gauss-hardware.md): confirmed
        physical facts still hold under NixOS, demoted the Fedora-era storage
        numbers to a labeled reference subsection, recorded the install method,
        layout, networking, and a link to the bootstrap gotcha.
  - [x] Filled in `gauss`'s real fields in
        [host-inventory](../tickets/host-inventory.md).
  - [x] Updated `thoughts/BACKLOG.md`: removed the now-redundant
        `multi-host-layout` line and moved this item to `## Closed`.
  - [x] Bonus finding: re-benchmarked `gauss`'s internal NVMe post-install and
        found a storage-throughput regression (3820 → ~1750 MB/sec) not
        explained by CPU governor. Recorded in
        [performance.md](../../docs/performance.md#gauss-unresolved) and opened
        `gauss-power-profile` in the backlog rather than silently footnoting it.
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

# host-inventory — Establish the Fleet Inventory

Record enough current state to choose safe targets and avoid premature host
roles.

## Known Hosts

- `hardy`: ASUS Chromebook Flip C436F / Google Helios; first NixOS target and
  self-hosting development machine; may run desktop and server workloads;
  currently non-load-bearing. Tailscale is enabled declaratively and enrolled
  with runtime state outside Nix. Its current tailnet IPv4 address is
  `100.70.165.86`; SSH is verified through both MagicDNS (`hardy`) and the
  manually mapped `hardy.ts.imetrical.com` record, including automatic identity
  restoration after reboot. Confirm whether the committed generation is applied.
- `gauss`: Beelink SER8; second NixOS host, installed 2026-07-23 on its internal
  NVMe (previously Omarchy, now wiped). AMD Ryzen 7 8845HS, 27 GiB RAM;
  hardware/storage baseline and install notes in
  [gauss-hardware.md](../../docs/gauss-hardware.md). Desktop (GNOME, clone of
  `hardy`) and future virtualization-host roles, per
  [homelab-platform](../design/homelab-platform.md#two-physical-host-objectives);
  currently non-load-bearing. Stable LAN IP via DHCP reservation
  (`gauss.imetrical.com`); Tailscale up with a manually mapped
  `gauss.ts.imetrical.com` DNS record (not MagicDNS). SSH via the shared
  `daniel@galois` key; temporary passwordless wheel sudo, matching `hardy`.
  Open: `gauss-power-profile` storage-throughput regression (see
  [performance.md](../../docs/performance.md#gauss-unresolved)).
- Bluefin iMac: physical iMac with a spare drive available for early testing.
  Confirm hostname, model, architecture, current primary system, and acceptable
  use of the spare drive.
- `galois`: Mac Mini M2 currently used as the convenient control/development
  machine; not the first NixOS migration target.
- Two Proxmox hosts: available for VM-based provisioning and recovery tests.
  Record names, hardware, storage, networking, and workload criticality.

## Inventory Fields

- Stable name, hardware, architecture, firmware, disks, and network identity.
- Current OS/configuration and whether it may be wiped.
- Current and candidate roles; allow mixed desktop/server roles.
- Data and workloads, criticality, backup state, and recovery constraints.
- Remote access, secrets, and bootstrap prerequisites.
- Best use as a real host, destructive test target, or virtualization host.

## Done

- Every candidate machine has verified facts and an explicit risk boundary.
- The first two NixOS targets are selected from evidence rather than assumed
  roles.

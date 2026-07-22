# host-inventory — Establish the Fleet Inventory

Record enough current state to choose safe targets and avoid premature host
roles.

## Known Hosts

- `hardy`: ASUS Chromebook Flip C436F / Google Helios; NixOS target and first
  self-hosting development machine; may run desktop and server workloads;
  currently non-load-bearing. Confirm whether the committed generation is
  applied.
- `gauss`: Beelink SER8; planned second NixOS host on its internal NVMe. Its
  pre-NixOS hardware and storage baseline is in
  [gauss-hardware.md](../../docs/gauss-hardware.md).
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

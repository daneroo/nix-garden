# Incus as the Hypervisor Orchestration Layer

Research note, 2026-07-12, supporting `incus-host`, `nixos-guests`, and
`virtualization-test-lab`. Also extends
[desktop-test-harness-fidelity](desktop-test-harness-fidelity.md) with the Incus
screen-virtualization story.

## Why Incus Is a Sound Bet

Incus is the community fork of LXD under linuxcontainers.org, led by Stéphane
Graber and most of the original LXD team after Canonical pulled LXD in-house
(2023). Governance is the point: it is the continuation of the project by its
authors, with monthly feature releases plus LTS branches, and `lxd-to-incus` for
migrations. The bet is on the team, not the brand.

What makes it more than "LXC with extras" as an orchestration layer:

- **One API for system containers and VMs.** Same CLI, profiles, images,
  snapshots, and networking whether the instance is an LXC container or a
  QEMU/KVM VM. That collapses the Proxmox/Docker mental split.
- **Profiles and projects** are the reusable-role mechanism: a `profile` is a
  declarative bundle of devices and config applied to instances — conceptually
  parallel to NixOS modules, one layer down.
- **Remotes.** The REST API means `incus` on any machine (client exists for
  macOS) can drive the daemon on `hardy` — the fleet-control shape this repo
  wants, before any clustering.
- **Clustering, live migration, `cluster evacuate`** exist when there are 3+
  hosts — directly relevant to the `safe-host-updates` backlog item someday.
- **`incus copy --refresh`** replicates an instance to another Incus host
  incrementally using optimized btrfs/zfs send — poor-man's DR that fits the
  reconciliation model (desired: replica exists and is fresh; observe; copy).
- **IaC surface.** A maintained Terraform/OpenTofu provider, cloud-init support
  in images, and the team's `incus-deploy` reference playbooks. And on NixOS,
  `virtualisation.incus.enable` plus `preseed` declares storage pools, networks,
  and profiles in the flake — the host side stays declarative.

Everything is CLI/REST with JSON output, which also makes it one of the most
agent-drivable hypervisors available.

## Screen Virtualization

The console story, best to worst for fidelity:

- **`incus console --type=vga`** attaches a SPICE client (remote-viewer / spicy)
  to the VM's virtio-gpu display. SPICE transmits raw scancodes rather than
  VNC's keysyms and supports clipboard sharing and USB redirection — a
  materially better input path than the Proxmox noVNC experience. Run locally on
  the Incus host, this sits at the L1 rung of the fidelity ladder; over the
  network it degrades toward the VNC caveats.
- **GPU passthrough** (`incus config device add <vm> gpu gpu`, plus `sriov`,
  `mdev`, and `mig` variants) gives a VM the physical GPU. With a monitor on the
  passed-through GPU and USB input passthrough, a VM approaches metal — the
  classic path when a physical test box is not free. Given `gauss` and the
  spare-drive iMac exist, specialisations on metal remain simpler for UX
  judgment; passthrough is the fallback, not the plan.
- **GUI apps in system containers** by proxying the host's Wayland socket and
  sharing the GPU device — near-zero-overhead graphics for per-app isolation,
  though the compositor under test is still the host's.

The community image server carries prebuilt **desktop VM images** (search for
"desktop" variants) — a fast way to compare a stock GNOME/KDE VM experience
against the same DE through other channels before trusting any virtual channel
for judgment.

## NixOS Guests

- Container guests: the images server carries NixOS container images, and
  `nixos-generators` can emit LXC/Incus images straight from this flake.
  NixOS-in-LXC has known frictions (nested systemd, id maps) — workable, but VMs
  are the smoother path for full-NixOS guests.
- VM guests: boot the standard NixOS ISO in an Incus VM, or better, point
  `nixos-anywhere` at any freshly booted Incus VM — which makes Incus the local,
  faster stand-in for the Proxmox drill VMs in the recovery plan.
- Decide per guest whether it is inventory (a host in this flake, with a
  `hosts/<name>` entry) or livestock (image-built, disposable). Incus is happy
  with both; the flake should not absorb livestock.

## Suggested First Exercise

On `hardy` (or `gauss` once reinstalled): enable `virtualisation.incus` with a
small preseed (one btrfs-backed pool, one bridged network, default profile),
launch one container and one VM, snapshot and restore both, then
`nixos-anywhere` into the VM. That single afternoon exercises the pool, network,
guest, snapshot, and recovery paths and produces the facts the `incus-host`
ticket needs.

## Sources

- [Incus documentation: console access](https://linuxcontainers.org/incus/docs/main/howto/instances_console/)
- [Incus documentation: GPU devices](https://linuxcontainers.org/incus/docs/main/reference/devices_gpu/)
- [Incus documentation: storage drivers](https://linuxcontainers.org/incus/docs/main/reference/storage_drivers/)
- [Simos Xenitellis: Windows VMs on Incus](https://blog.simos.info/how-to-run-a-windows-virtual-machine-on-incus-on-linux/)
  — the reference walkthrough style for VGA-console VMs.
